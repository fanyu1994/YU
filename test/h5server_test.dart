import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yu/utils/h5server.dart';

/// 测试环境下 rootBundle 拿不到 assets，直接从工程目录读
Future<ByteData> _fileAssetLoader(String key) async {
  final file = File(key);
  final bytes = await file.readAsBytes();
  return ByteData.view(Uint8List.fromList(bytes).buffer);
}

/// 验证 H5Server 的反向代理与引导脚本注入：
/// 1. `/hussarApi/**` 的 GET/POST 被转发到上游后端
/// 2. OPTIONS 预检在本地直接返回带 CORS 头的 204
/// 3. index.html 会在业务 JS 之前注入 token 到 localStorage 的脚本
void main() {
  late HttpServer upstream;
  late H5Server server;
  late List<HttpHeaders> received;
  late String upstreamBase;

  setUpAll(() async {
    received = <HttpHeaders>[];
    upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    upstreamBase = 'http://127.0.0.1:${upstream.port}/hussarApi';
    upstream.listen((request) async {
      received.add(request.headers);
      final body = await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'path': request.uri.path,
        'query': request.uri.query,
        'method': request.method,
        'body': body,
      }));
      await request.response.close();
    });
  });

  tearDownAll(() async => upstream.close(force: true));

  setUp(() async {
    received.clear();
    server = H5Server(
      remoteBaseUrl: upstreamBase,
      webStorage: {'HussarToken': 'token-123'},
      port: 0,
      assetLoader: _fileAssetLoader,
    );
    await server.start(assetPath: 'assets/h5/safety');
  });

  tearDown(() => server.stop());

  test('GET /hussarApi/** 被代理到上游，且剥离 Origin', () async {
    final client = HttpClient();
    final request = await client.getUrl(
      Uri.parse(
        '${server.origin}/hussarApi/hussar-safety/safetyManagement/dangerSourceControl/'
        'hussarQuerydangerSourceControlCondition_1dangerSourceControlSort_1Page?page=1',
      ),
    );
    request.headers.set('origin', 'http://127.0.0.1:${server.listeningPort}');
    request.headers.set('Authorization', 'Bearer token-123');
    final response = await request.close();
    final body = jsonDecode(await utf8.decoder.bind(response).join()) as Map;

    expect(response.statusCode, 200);
    expect(
      body['path'],
      // base 里本来就带着 /hussarApi，H5 请求路径里的 /hussarApi 已被剥掉，
      // 拼出的上游地址与 H5 直连时完全一致
      '/hussarApi/hussar-safety/safetyManagement/dangerSourceControl/'
      'hussarQuerydangerSourceControlCondition_1dangerSourceControlSort_1Page',
    );
    expect(body['query'], 'page=1');

    // 上游看到的是服务端发起的请求，不应带浏览器页面来源
    expect(received.single.value('origin'), isNull);
    expect(received.single.value('authorization'), 'Bearer token-123');
    client.close();
  });

  test('POST body 被完整转发', () async {
    final client = HttpClient();
    final request = await client.postUrl(
      Uri.parse('${server.origin}/hussarApi/oauth2/token?grant_type=password'),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode({'username': 'admin'}));
    final response = await request.close();
    final body = jsonDecode(await utf8.decoder.bind(response).join()) as Map;

    expect(body['method'], 'POST');
    expect(body['body'], jsonEncode({'username': 'admin'}));
    client.close();
  });

  test('OPTIONS 预检本地响应并带 CORS 头（不打扰上游）', () async {
    final client = HttpClient();
    final request = await client.openUrl(
      'OPTIONS',
      Uri.parse('${server.origin}/hussarApi/oauth2/token'),
    );
    request.headers.set('origin', 'http://127.0.0.1:${server.listeningPort}');
    request.headers.set('access-control-request-method', 'POST');
    request.headers.set(
      'access-control-request-headers',
      'authorization,uniqueid,checkcode',
    );
    final response = await request.close();
    await response.drain<void>();

    expect(response.statusCode, 204);
    expect(
      response.headers.value('access-control-allow-origin'),
      'http://127.0.0.1:${server.listeningPort}',
    );
    expect(
      response.headers.value('access-control-allow-headers'),
      'authorization,uniqueid,checkcode',
    );
    expect(response.headers.value('access-control-allow-credentials'), 'true');
    expect(received, isEmpty);
    client.close();
  });

  test('index.html 注入 localStorage 引导脚本', () async {
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(server.origin));
    final response = await request.close();
    final html = await utf8.decoder.bind(response).join();

    expect(response.statusCode, 200);
    expect(html, contains('window.__H5_BOOTSTRAP__=1'));
    expect(html, contains('localStorage.setItem("HussarToken","token-123")'));
    expect(html, contains('window.__H5_API_BASE__=base'));
    // 注入脚本必须在业务 JS 之前
    expect(
      html.indexOf('window.__H5_BOOTSTRAP__'),
      lessThan(html.indexOf('static/js/index.')),
    );
    client.close();
  });

  test('静态 JS 资源可正常返回，且不会做 HTML 注入', () async {
    final client = HttpClient();
    final request = await client.getUrl(
      Uri.parse('${server.origin}/static/js/index.be76bb32.js'),
    );
    final response = await request.close();
    final js = await utf8.decoder.bind(response).join();

    expect(response.statusCode, 200);
    expect(js, contains('__H5_API_BASE__'));
    expect(js, isNot(contains('__H5_BOOTSTRAP__')));
    client.close();
  });
}
