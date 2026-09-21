import 'dart:ui';

import 'package:flutter/material.dart';

import '../routes.dart';
import '../../utils/token_storage.dart';

/// 启动页：磨砂背景 + 彩色"你好!"书写动画 + token 判断跳转
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  static const String _text = '你好!';

  late final AnimationController _writeController;
  late final Animation<double> _writeAnimation;

  @override
  void initState() {
    super.initState();
    _writeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _writeAnimation = CurvedAnimation(
      parent: _writeController,
      curve: Curves.easeInOutCubic,
    );
    _startSequence();
  }

  /// 书写完成 → 等待 2 秒 → 读取本地 token → 跳转对应页面
  Future<void> _startSequence() async {
    String? token;
    try {
      await _writeController.forward();
      await Future<void>.delayed(const Duration(seconds: 2));
      await TokenStorage.clearToken(); // 测试用，实际项目中注释掉这行
      token = await TokenStorage.getToken();
    } catch (e) {
      debugPrint('启动流程异常: $e');
    }

    if (!mounted) return;
    final hasToken = token != null && token.isNotEmpty;
    debugPrint('token 判断结果: hasToken=$hasToken，准备跳转');
    Navigator.of(context).pushReplacementNamed(
      hasToken ? AppRoutes.y : AppRoutes.login,
    );
  }

  @override
  void dispose() {
    _writeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 磨砂玻璃背景
          _buildFrostedBackground(),
          // 书写动画文字
          Center(
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.2, end: 1).animate(
                CurvedAnimation(
                  parent: _writeController,
                  curve: const Interval(0, 0.15),
                ),
              ),
              child: _buildWritingText(),
            ),
          ),
        ],
      ),
    );
  }

  /// 深色底 + 彩色光斑 + 高斯模糊，形成磨砂玻璃效果
  Widget _buildFrostedBackground() {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFF0E1018))),
        Positioned(
          top: -80,
          left: -60,
          child: _Blob(color: const Color(0xFF7B5CFF), size: 280),
        ),
        Positioned(
          bottom: -100,
          right: -50,
          child: _Blob(color: const Color(0xFFFF5C8A), size: 320),
        ),
        Positioned(
          bottom: 60,
          left: -90,
          child: _Blob(color: const Color(0xFF36D1DC), size: 240),
        ),
        Positioned(
          top: 120,
          right: -40,
          child: _Blob(color: const Color(0xFFFFD93D), size: 180),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
            child: const ColoredBox(color: Color(0x14000000)),
          ),
        ),
      ],
    );
  }

  /// 从左到右逐步显现的彩色文字
  Widget _buildWritingText() {
    const textStyle = TextStyle(
      fontSize: 72,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      letterSpacing: 6,
      height: 1.1,
    );

    return AnimatedBuilder(
      animation: _writeAnimation,
      builder: (context, child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: _writeAnimation.value.clamp(0.0001, 1.0),
            child: child,
          ),
        );
      },
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Color(0xFFFF6B6B),
            Color(0xFFFFD93D),
            Color(0xFF6BCB77),
            Color(0xFF4D96FF),
            Color(0xFFB983FF),
          ],
        ).createShader(bounds),
        child: const Text(_text, style: textStyle),
      ),
    );
  }
}

/// 背景彩色光斑
class _Blob extends StatelessWidget {
  final Color color;
  final double size;

  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
