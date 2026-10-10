import 'package:flutter/material.dart';

/// Efek animasi sentuhan halus permanen.
///
/// Skala 1.0 → 0.96 saat onTapDown, kembali 1.0 saat onTapUp / onTapCancel.
/// Durasi 120ms dengan kurva Curves.easeOut.
class TouchEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final HitTestBehavior behavior;

  const TouchEffect({
    super.key,
    required this.child,
    this.onTap,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<TouchEffect> createState() => _TouchEffectState();
}

class _TouchEffectState extends State<TouchEffect> {
  bool _pressed = false;

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    setState(() => _pressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    if (_pressed) {
      setState(() => _pressed = false);
    }
  }

  void _onTapCancel() {
    if (_pressed) {
      setState(() => _pressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
