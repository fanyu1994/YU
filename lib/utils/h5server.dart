import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';

class H5Server {
  HttpServer? _server;
  final int _port = 8848;

  Future<String> start({required String assetPath}) async {
    _server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      _port,
    ); // 监听本地回环地址
    _server!.listen((request) async {
      await _handleRequest(request, assetPath);
    }); // 监听请求

    return 'http://127.0.0.1:${_server!.port}';
  }

  Future<void> _handleRequest(HttpRequest request, String assetPath) async {
    var path = request.uri.path;
    if (path == '/') {
      path = '/index.html';
    }
    final asset = '$assetPath$path';
    try {
      final data = await rootBundle.load(asset); // 加载静态资源

      request.response.headers.contentType = _getContentType(path);
      request.response.add(data.buffer.asUint8List());
      await request.response.close();
    } catch (e) {
      // SPA fallback：仅对无扩展名的路由路径返回 index.html
      // 静态资源（.js/.css/.png 等）找不到时返回 404，避免 MIME 类型错误
      final hasExtension = path.contains('.') && !path.endsWith('/');
      if (hasExtension) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      } else {
        try {
          final fallbackAsset = '$assetPath/index.html';
          final data = await rootBundle.load(fallbackAsset);
          request.response.headers.contentType = ContentType.html;
          request.response.add(data.buffer.asUint8List());
          await request.response.close();
        } catch (_) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      }
    }
  }

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

    if (path.endsWith('.svg')) {
      return ContentType('image', 'svg+xml');
    }

    if (path.endsWith('.woff2')) {
      return ContentType('font', 'woff2');
    }

    return ContentType.binary;
  }

  Future<void> stop() async {
    _server?.close();
  }
}
