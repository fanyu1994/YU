import 'package:flutter/material.dart';

class TopToast {
  static OverlayEntry? _entry; // 当前的entry

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    // 先移除旧的
    _entry?.remove();
    _entry = null;

    final entry = OverlayEntry(
      builder: (context) {
        return _TopToastWidget(
          message: message,
          duration: duration,
          onClose: () {
            _entry?.remove();
            _entry = null;
          },
        );
      },
    ); // 创建新的entry

    // 插入到overlay中
    Overlay.of(context).insert(entry);

    _entry = entry; // 记录当前的entry
    Overlay.of(context).insert(entry); // 插入到overlay中
  }
}

class _TopToastWidget extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback onClose;

  const _TopToastWidget({
    super.key,
    required this.message,
    required this.duration,
    required this.onClose,
  }); // 构造函数 ，接收message、duration、onClose参数

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState(); // 创建新的state
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller; // 动画控制器
  late final Animation<Offset> _slideAnimation; // 滑动动画

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration, // 动画持续时间
      vsync: this, // 注册动画控制器，防止内存泄漏
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOut,
          ), // 动画曲线，从下往上移动
        );
    _show(); // 显示toast
  }

  Future<void> _show() async {
    await _controller.forward(); // 播放动画
    await Future.delayed(widget.duration); // 等待指定时间

    if (!mounted) return;
    await _controller.reverse(); // 播放动画
    widget.onClose(); // 关闭toast
  }

  @override
  void dispose() {
    _controller.dispose(); // 释放动画控制器
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation, // 滑动动画
        child: Material(
          color: Colors.transparent, // 背景颜色透明
          child: Container(
            // toast内容
            padding: const EdgeInsets.symmetric(
              horizontal: 16, // 水平方向内边距 16px
              vertical: 12, // 垂直方向内边距 12px
            ), // 内边距
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}
