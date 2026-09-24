import "package:flutter/material.dart";
import '../routes.dart';
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
                    color: const Color.fromARGB(255, 255, 255, 255),
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
      // 关键：让每个分组都撑满整行宽度，否则只有 1~2 个子应用时
      // （Wrap 宽度小于可用宽度）整组会被 Column 默认的 center 居中，
      // 看起来就不靠左了
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
            // 应用横向排列，宽度不够时自动换行（左右内边距与标题保持 16 对齐）
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Wrap(
                alignment: WrapAlignment.start,
                spacing: 4,
                runSpacing: 12,
                children: apps.map((app) {
                  final map = Map<String, dynamic>.from(app as Map);
                  return _AppTile(
                    name: map['appName']?.toString() ?? '',
                    linkUrl: map['linkUrl']?.toString() ?? '',
                    onTap: () => openApplication(map),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

/// 单个应用入口：图标 + 名称的网格单元
class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.name,
    required this.linkUrl,
    required this.onTap,
  });

  final String name;
  final String linkUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: linkUrl.isEmpty ? name : '$name\n$linkUrl',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: MediaQuery.of(context).size.width / 4 - 24,
          child: Padding(
            // 水平方向不留内边距，让图标左边缘与标题左边缘对齐到同一条 16 的竖线
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min, // 保持最小高度，避免换行
              // 图标与名称都从左侧开始对齐
              crossAxisAlignment: CrossAxisAlignment.center, // 图标与名称都从左侧开始对齐
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB983FF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.apps,
                    color: Color(0xFFB983FF),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name.isEmpty ? '未命名' : name,
                  maxLines: 2,
                  textAlign: TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, height: 1.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
