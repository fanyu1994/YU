import "package:flutter/material.dart";
import '../routes.dart';
import '../../config/env.dart';
import '../../utils/token_storage.dart';
import './y_api.dart';
import 'h5_page.dart';

class YPage extends StatefulWidget {
  const YPage({super.key});

  @override
  State<YPage> createState() => _YPageState();
}

class _YPageState extends State<YPage> {
  Future<void> _logout() async {
    await TokenStorage.clearToken();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        color: Colors.transparent,
        alignment: Alignment.topCenter,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 220,
              child: Container(
                color: Colors.lightBlue,
                padding: const EdgeInsets.all(16.0),
                height: 220,
                width: double.infinity,
                alignment: Alignment.topLeft,
                child: Text('YU One'),
              ),
            ),

            Positioned(
              top: 120, // 屏幕高度 - 200
              left: 10,
              right: 10,
              height: MediaQuery.of(context).size.height - 120, // 屏幕高度 - 200
              child: Container(
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: const Color.fromARGB(255, 199, 5, 5),
                    width: 1.0,
                  ),
                ),
                child: SingleChildScrollView(
                  child: const _BuildYUOneList(), // 可滚动的内容
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildYUOneList extends StatefulWidget {
  const _BuildYUOneList();

  @override
  State<_BuildYUOneList> createState() => _BuildYUOneListState();
}

class _BuildYUOneListState extends State<_BuildYUOneList> {
  late List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    try {
      final items = await YApi.getApplications();
      if (!mounted) return;
      setState(() {
        _items = items.isNotEmpty ? items : [];
      });
    } catch (e) {
      debugPrint('加载项目列表失败: $e');
    }
  }

  /// 打开应用（resourceType "3" = H5 应用）
  void openApplication(Map<String, dynamic> app) {
    final resourceType = app['resourceType']?.toString() ?? '';
    final linkUrl = app['linkUrl']?.toString() ?? '';
    if (linkUrl.isEmpty) return;

    if (resourceType == '3') {
      // H5 应用：拼接完整 URL 后用 WebView 打开
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => H5Page(url: linkUrl)),
      );
    } else {
      debugPrint('未知应用类型: $resourceType, linkUrl: $linkUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _items.map((group) {
        final groupName = group['groupName'] ?? '';
        final apps = group['applicationList'] as List? ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                groupName as String,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...apps.map((app) {
              final map = Map<String, dynamic>.from(app as Map);
              return ListTile(
                leading: const Icon(Icons.apps, color: Color(0xFFB983FF)),
                title: Text(map['appName']?.toString() ?? ''),
                subtitle: Text(map['linkUrl']?.toString() ?? ''),
                onTap: () => openApplication(map),
              );
            }),
          ],
        );
      }).toList(),
    );
  }
}
