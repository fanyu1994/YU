import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:yu/utils/h5server.dart';
import 'package:yu/utils/token_storage.dart';
import 'package:yu/config/env.dart';

class H5Page extends StatefulWidget {
  final String url;
  const H5Page({super.key, required this.url});

  @override
  State<H5Page> createState() => _H5PageState();
}

class _H5PageState extends State<H5Page> {
  WebViewController? _webViewController;
  H5Server? _server;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 读取本地 token（必须在本地服务启动前拿到，服务需要在响应 index.html 时注入）
    final token = await TokenStorage.getToken();

    // 本地服务同时做反向代理：/hussarApi/* → 远程后端
    // H5 包的接口地址已改为同源相对路径，全量走这里，避免浏览器 CORS 限制
    _server = H5Server(
      remoteBaseUrl: Env.baseUrl,
      webStorage: {
        if (token != null && token.isNotEmpty) ...{
          // uni.getStorageSync 读的就是 localStorage，key 与 H5 端读取保持一致
          'HussarToken': token,
          'hussar-unify-token': token,
        },
      },
    );
    final baseUrl = await _server!.start(assetPath: 'assets/h5/safety');

    // 用 hash 路由：加载根路径 index.html，应用路径放在 # 后面
    final route = widget.url.startsWith('/') ? widget.url : '/${widget.url}';
    final fullUrl = '$baseUrl/#$route';
    debugPrint(
      'xxxxxxxxxxx fullUrl: $fullUrl, token: ${token != null ? '有' : '无'}',
    );

    final controller = WebViewController();
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _injectToken(controller, token),
        ),
      )
      ..loadRequest(Uri.parse(fullUrl));

    if (mounted) {
      setState(() {
        _webViewController = controller;
        _loading = false;
      });
    }
  }

  /// 页面加载完成后补一次 token 写入。
  ///
  /// 主链路是 H5Server 在 index.html 里注入引导脚本（先于业务 JS 执行）；
  /// 这里只是兜底，覆盖 H5 内部清空 localStorage 或页面刷新时序异常的情况。
  Future<void> _injectToken(WebViewController controller, String? token) async {
    if (token == null || token.isEmpty) return;

    final js = '''
      localStorage.setItem('HussarToken', ${jsonEncode(token)});
      localStorage.setItem('hussar-unify-token', ${jsonEncode(token)});
    ''';

    await controller.runJavaScript(js);
    debugPrint('已注入 token 到 H5 localStorage');
  }

  @override
  void dispose() {
    _server?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('H5 页面')),
      body: _loading || _webViewController == null
          ? const Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: _webViewController!),
    );
  }
}
