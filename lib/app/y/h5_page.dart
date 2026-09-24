import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:yu/utils/h5server.dart';

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
    _server = H5Server();
    final baseUrl = await _server!.start(assetPath: 'assets/h5/safety');

    // 用 hash 路由：加载根路径 index.html，应用路径放在 # 后面
    // 这样 index.html 里的相对路径（./static/js/...）能正确解析到根目录
    final route = widget.url.startsWith('/') ? widget.url : '/${widget.url}';
    final fullUrl = '$baseUrl/#$route';
    debugPrint('xxxxxxxxxxx fullUrl: $fullUrl');
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(fullUrl));

    if (mounted) {
      setState(() {
        _webViewController = controller;
        _loading = false;
      });
    }
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
