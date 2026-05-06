import 'package:flutter/material.dart';

/// Лаконичная анимация нажатия: мягкий "прожим" без резких эффектов.
class LaconicTap extends StatefulWidget {
  const LaconicTap({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<LaconicTap> createState() => _LaconicTapState();
}

class _LaconicTapState extends State<LaconicTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        scale: _pressed ? widget.scale : 1.0,
        child: widget.child,
      ),
    );
  }
}
