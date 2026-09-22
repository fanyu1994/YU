import 'package:flutter/material.dart';

class TopToast {
  static OverlayEntry? _entry;

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    // 先移除旧 Toast
    _remove();

    final overlay = Overlay.of(context);

    final entry = OverlayEntry(
      builder: (context) {
        return _TopToastWidget(
          message: message,
          duration: duration,
          onClose: () {
            _remove();
          },
        );
      },
    );

    _entry = entry;

    overlay.insert(entry);
  }

  static void _remove() {
    final entry = _entry;

    if (entry == null) {
      return;
    }

    entry.remove();
    _entry = null;
  }
}

class _TopToastWidget extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback onClose;

  const _TopToastWidget({
    required this.message,
    required this.duration,
    required this.onClose,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _show();
  }

  Future<void> _show() async {
    await _controller.forward();

    await Future.delayed(widget.duration);

    if (!mounted) return;

    await _controller.reverse();

    if (!mounted) return;

    widget.onClose();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 10,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}