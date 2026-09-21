import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:yu/app/login/login_api.dart';
import 'package:yu/components/overlay/top_toast.dart';
import 'package:yu/network/api_client.dart';

import '../routes.dart';
import '../../utils/token_storage.dart';

/// 登录页：磨砂背景，用户名/密码区域从下方滑入
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loggingIn = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    final curveSlide = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ); // 滑入动画
    final curveFade = CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.6, 1, curve: Curves.easeOut),
    ); // 淡入动画
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(curveSlide); // 滑入动画
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(curveFade); // 淡入动画
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      // 显示 toast 提示
      TopToast.show(context, '请输入用户名和密码');
      return;
    }

    setState(() => _loggingIn = true);

    dynamic response;
    // TODO: 替换为真实登录接口
    try {
      response = await LoginApi.login(username, password);
      TopToast.show(context, '登录成功');
    } catch (e) {
      TopToast.show(context, '登录失败');
      return;
    }
    await TokenStorage.clearToken();
    final String token = response['access-token'];
    await TokenStorage.saveToken(token);

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.y);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildFrostedBackground(),
          // 顶部欢迎语
          const Positioned(
            top: 110,
            left: 0,
            right: 0,
            child: Text(
              '欢迎回来',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
          ),
          // 从下方滑入的登录表单
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildLoginCard(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 40),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '登录',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 28),
              _buildUsernameField(),
              const SizedBox(height: 18),
              _buildPasswordField(),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                  ),
                  child: const Text(
                    '忘记密码？',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildLoginButton(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '还没有账号？',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.register),
                    child: const Text(
                      '立即注册',
                      style: TextStyle(
                        color: Color(0xFFB983FF),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsernameField() {
    return TextField(
      controller: _usernameController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: '用户名',
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.12),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: '密码',
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.white70,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.12),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      onSubmitted: (_) => _login(),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _loggingIn ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB983FF),
          disabledBackgroundColor: const Color(
            0xFFB983FF,
          ).withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _loggingIn
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Text(
                '登 录',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 8,
                ),
              ),
      ),
    );
  }

  /// 与启动页一致的磨砂玻璃背景
  Widget _buildFrostedBackground() {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Color(0xFF0E1018))),
        Positioned(
          top: -60,
          right: -70,
          child: _Blob(color: const Color(0xFF7B5CFF), size: 260),
        ),
        Positioned(
          bottom: -80,
          left: -60,
          child: _Blob(color: const Color(0xFFFF5C8A), size: 300),
        ),
        Positioned(
          top: 140,
          left: -50,
          child: _Blob(color: const Color(0xFF36D1DC), size: 200),
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
