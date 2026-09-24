import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 资源加载器，默认为 [rootBundle.load]；测试时可注入文件系统实现
typedef AssetLoader = Future<ByteData> Function(String key);

/// 本地静态资源服务 + 反向代理
///
/// H5 包（assets/h5/safety）通过 `http://127.0.0.1:<port>` 提供给 WebView，
/// 同时把 `/hussarApi/**` 的请求反向代理到 [remoteBaseUrl]。
///
/// 这样 H5 里所有接口请求都变成**同源请求**，不再依赖目标服务端返回
/// `Access-Control-Allow-Origin`，从根上避免：
///
///   Response to preflight request doesn't pass access control check:
///   No 'Access-Control-Allow-Origin' header is present on the requested resource.
///
/// 另外会在 index.html 里注入一段引导脚本，把 token 等运行时数据在 H5 业务代码
/// 执行之前写入 localStorage（uni-app 的 `uni.getStorageSync` 读的就是 localStorage）。
///
/// 局限：代理不会重写上游的 `Set-Cookie`（Domain 指向真实后端域名，浏览器会丢弃）。
/// 当前 H5 走的是 token 请求头鉴权，不受影响；若以后改成 Cookie 会话需要在这里补重写。
class H5Server {
  /// 需要代理到远端的路径前缀
  static const String proxyPrefix = '/hussarApi';

  /// 允许多次写入的引导脚本标记，避免重复注入
  static const String _bootstrapMarker = 'window.__H5_BOOTSTRAP__';

  /// 转发给上游时需要丢弃的请求头（hop-by-hop + 会造成误判的浏览器头）
  static const Set<String> _skipRequestHeaders = {
    'host',
    'content-length',
    'connection',
    'keep-alive',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
    // 带着浏览器页面来源（http://127.0.0.1:port）转发给上游，某些网关/后端会
    // 按 Origin 做校验或返回 CORS 头，代理场景下没有意义，直接剥离。
    'origin',
    'referer',
  };

  /// 不能直接透传的响应头，由 Dart 的 HttpResponse 自行管理
  static const Set<String> _skipResponseHeaders = {
    'connection',
    'keep-alive',
    'proxy-authenticate',
    'proxy-authorization',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
    'content-length',
    // CORS 头统一由本服务按访客 Origin 重新下发，避免与上游重复/冲突
    'access-control-allow-origin',
    'access-control-allow-methods',
    'access-control-allow-headers',
    'access-control-allow-credentials',
    'access-control-expose-headers',
    'access-control-max-age',
    'vary',
  };

  final int port;
  final String remoteBaseUrl;
  final Map<String, String> webStorage;
  final AssetLoader _loadAssetBytes;

  HttpServer? _server;

  H5Server({
    this.remoteBaseUrl = '', // 远程后端 URL，包含代理前缀
    this.webStorage = const {}, // 预注入的 localStorage 数据
    this.port = 8848, // 本地服务端口
    AssetLoader? assetLoader, // 资源加载器，默认为 [rootBundle.load]
  }) : _loadAssetBytes = assetLoader ?? rootBundle.load; // 初始化源加载器

  /// 实际监听的端口（传入 0 时为系统分配的随机端口）
  int get listeningPort => _server?.port ?? port; // 获取实际监听端口

  String get origin => 'http://127.0.0.1:$listeningPort'; // 生成 H5 服务端 URL

  Future<String> start({required String assetPath}) async {
    _server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
    ); // 绑定本地服务端口
    _server!.listen((request) {
      _handleRequest(request, assetPath).catchError((Object error) {
        debugPrint('H5Server 处理请求失败 ${request.uri}: $error');
      }); // 处理请求失败
    }); // 监听请求
    return origin; // 返回 H5 服务端 URL
  }

  Future<void> _handleRequest(HttpRequest request, String assetPath) async {
    final path = request.uri.path;

    // 反向代理：/hussarApi/** → 远程后端
    if (remoteBaseUrl.isNotEmpty && path.startsWith(proxyPrefix)) {
      await _proxyRequest(request);
      return;
    }

    await _serveAsset(request, assetPath);
  }

  // ---------------------------------------------------------------------------
  // 反向代理
  // ---------------------------------------------------------------------------

  Future<void> _proxyRequest(HttpRequest request) async {
    final response = request.response;

    // 预检请求本地直接响应，不必打扰上游
    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      _applyCorsHeaders(request, response);
      await response.close();
      return;
    }

    final client = HttpClient()
      // 保持上游压缩内容原样透传（默认 true 会自动解压但仍可能带上
      // content-encoding 头，浏览器会解析失败）
      ..autoUncompress = false;

    var responseStarted = false;
    try {
      // remoteBaseUrl 形如 http://172.23.2.87/hussarApi，本身已经包含代理前缀，
      // 所以要把请求路径里的 /hussarApi 去掉再拼接，否则会重复成
      // http://172.23.2.87/hussarApi/hussarApi/**
      final upstreamPath = _upstreamPath(request.uri.path);
      final target = Uri.parse(
        '$_baseWithoutTrailingSlash$upstreamPath'
        '${request.uri.hasQuery ? '?${request.uri.query}' : ''}',
      );

      final remoteRequest = await client.openUrl(request.method, target);
      // 保持 302 等跳转语义，交给浏览器/H5 自己处理
      remoteRequest.followRedirects = false;

      request.headers.forEach((name, values) {
        if (_skipRequestHeaders.contains(name.toLowerCase())) return;
        remoteRequest.headers.set(name, values);
      });

      if (request.contentLength >= 0) {
        remoteRequest.contentLength = request.contentLength;
      }

      // 流式转发请求体，避免大文件上传时整包驻留内存
      await request.forEach(remoteRequest.add);

      final remoteResponse = await remoteRequest.close();

      response.statusCode = remoteResponse.statusCode;
      response.reasonPhrase = remoteResponse.reasonPhrase;
      remoteResponse.headers.forEach((name, values) {
        if (_skipResponseHeaders.contains(name.toLowerCase())) return;
        response.headers.set(name, values);
      });
      _applyCorsHeaders(request, response);

      responseStarted = true;
      await remoteResponse.pipe(response);
    } catch (error, stackTrace) {
      debugPrint('代理请求失败 ${request.uri}: $error\n$stackTrace');
      if (!responseStarted) {
        response.statusCode = HttpStatus.badGateway;
        response.headers.contentType = ContentType.json;
        response.write(
          jsonEncode({'error': 'proxy_failed', 'message': '$error'}),
        );
      }
      await response.close();
    } finally {
      client.close();
    }
  }

  /// 去掉代理前缀后的上游路径
  String _upstreamPath(String path) {
    final stripped = path.substring(
      path.startsWith(proxyPrefix) ? proxyPrefix.length : 0,
    );
    return stripped.isEmpty ? '/' : stripped;
  }

  String get _baseWithoutTrailingSlash => remoteBaseUrl.endsWith('/')
      ? remoteBaseUrl.substring(0, remoteBaseUrl.length - 1)
      : remoteBaseUrl;

  /// 统一补充 CORS 响应头。
  ///
  /// 正常场景（H5 → 同源代理）用不到，但保留它可以覆盖：页面被外部浏览器以
  /// 其它 Origin 打开、或 H5 里写死了 `http://127.0.0.1:端口` 绝对地址等情况。
  void _applyCorsHeaders(HttpRequest request, HttpResponse response) {
    final origin = request.headers.value('origin');
    final allowHeaders = request.headers.value(
      'access-control-request-headers',
    );
    final allowMethod = request.headers.value('access-control-request-method');

    final hasOrigin = origin != null && origin.isNotEmpty;
    response.headers.set(
      'access-control-allow-origin',
      hasOrigin ? origin : '*',
    );
    response.headers.set(
      'access-control-allow-methods',
      allowMethod ?? 'GET,POST,PUT,DELETE,PATCH,HEAD,OPTIONS',
    );
    // 请求头里的自定义头（Authorization / uniqueId / checkCode 等）全部回显
    response.headers.set('access-control-allow-headers', allowHeaders ?? '*');
    response.headers.set('access-control-expose-headers', '*');
    response.headers.set('access-control-max-age', '86400');
    if (hasOrigin) {
      // 带凭证时不允许 allow-origin 为 *，且必须声明 Vary
      response.headers.set('access-control-allow-credentials', 'true');
      response.headers.set('vary', 'Origin');
    }
  }

  // ---------------------------------------------------------------------------
  // 静态资源
  // ---------------------------------------------------------------------------

  Future<void> _serveAsset(HttpRequest request, String assetPath) async {
    var path = request.uri.path;
    if (path == '/' || path.isEmpty) {
      path = '/index.html';
    }

    final bytes = await _loadAsset('$assetPath$path');

    if (bytes != null) {
      await _send(
        request,
        path,
        // 只有入口 HTML 需要注入引导脚本
        _isHtml(path)
            ? _injectBootstrap(utf8.decode(bytes, allowMalformed: true))
            : bytes,
      );
      return;
    }

    // SPA fallback：仅对无扩展名的路由路径返回 index.html
    final hasExtension = path.contains('.') && !path.endsWith('/');
    if (!hasExtension) {
      final index = await _loadAsset('$assetPath/index.html');
      if (index != null) {
        await _send(
          request,
          '/index.html',
          _injectBootstrap(utf8.decode(index, allowMalformed: true)),
        );
        return;
      }
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  Future<Uint8List?> _loadAsset(String asset) async {
    try {
      final data = await _loadAssetBytes(asset);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  Future<void> _send(HttpRequest request, String path, Object body) async {
    final response = request.response;
    response.headers.contentType = _getContentType(path);
    if (_isHtml(path)) {
      // HTML 里有注入的 token，禁止缓存
      response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    }
    if (body is String) {
      response.add(utf8.encode(body));
    } else {
      response.add(body as List<int>);
    }
    await response.close();
  }

  /// 在 index.html 的 `<head>` 后插入引导脚本：
  /// - 解析接口 base（默认同源 `/hussarApi`）
  /// - 把 token 等运行时数据写入 localStorage
  ///
  /// 必须保证在打包出来的业务 JS 之前执行，否则 H5 首屏请求会拿不到 token。
  String _injectBootstrap(String html) {
    if (html.contains(_bootstrapMarker)) {
      return html;
    }

    final statements = <String>[
      // 允许通过 localStorage 覆盖接口地址（换环境时无需重新打包）
      'var base=localStorage.getItem("__H5_API_BASE__")||"/hussarApi";',
      'window.__H5_API_BASE__=base;',
      for (final entry in webStorage.entries)
        if (entry.value.isNotEmpty)
          'localStorage.setItem(${jsonEncode(entry.key)},${jsonEncode(entry.value)});',
    ];

    final script =
        '<script>$_bootstrapMarker=1;(function(){try{${statements.join()}}'
        'catch(e){console.warn("h5 bootstrap failed",e)}})()</script>';

    final headIndex = html.toLowerCase().indexOf('<head>');
    if (headIndex == -1) {
      return '$script$html';
    }
    final insertAt = headIndex + '<head>'.length;
    return '${html.substring(0, insertAt)}$script${html.substring(insertAt)}';
  }

  bool _isHtml(String path) => path.endsWith('.html') || path.isEmpty;

  ContentType _getContentType(String path) {
    if (path.endsWith('.html')) {
      return ContentType.html;
    }

    if (path.endsWith('.js')) {
      return ContentType('application', 'javascript');
    }

    if (path.endsWith('.css')) {
      return ContentType('text', 'css');
    }

    if (path.endsWith('.json')) {
      return ContentType.json;
    }

    if (path.endsWith('.png')) {
      return ContentType('image', 'png');
    }

    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
      return ContentType('image', 'jpeg');
    }

    if (path.endsWith('.gif')) {
      return ContentType('image', 'gif');
    }

    if (path.endsWith('.svg')) {
      return ContentType('image', 'svg+xml');
    }

    if (path.endsWith('.ico')) {
      return ContentType('image', 'x-icon');
    }

    if (path.endsWith('.ttf')) {
      return ContentType('font', 'ttf');
    }

    if (path.endsWith('.woff')) {
      return ContentType('font', 'woff');
    }

    if (path.endsWith('.woff2')) {
      return ContentType('font', 'woff2');
    }

    if (path.endsWith('.mp4')) {
      return ContentType('video', 'mp4');
    }

    if (path.endsWith('.pdf')) {
      return ContentType('application', 'pdf');
    }

    return ContentType.binary;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
