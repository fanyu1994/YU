import "package:flutter/material.dart";

import '../routes.dart';
import '../../utils/token_storage.dart';

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
                  child: _buildYUOneList(), // 可滚动的内容
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _buildYUOneList extends StatefulWidget {
  const _buildYUOneList({super.key});

  @override
  State<_buildYUOneList> createState() => _buildYUOneListState();
}



class _buildYUOneListState extends State<_buildYUOneList> {

  final List<String> _items = [];

  @override
  Future<void> initState() async {
    super.initState();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _items.addAll(List.generate(10, (index) => 'YU One $index'));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('YU One ! ! !'),
        Text('YU One ! ! !'),
        Text('YU One ! ! !'),
        Text('YU One ! ! !'),
        Text('YU One ! ! !'),
        Text('YU One ! ! !'),
        Text('YU One ! ! !'),
        Text('YU One ! ! !'),
        Text('YU One ! ! !'),
        Text('YU One ! ! !'),
        Text('YU One ! ! !'),
        Text('YU One ! ! !'),
      ],
    );
  }
}
