import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../toast_action.dart';

/// The toast's trailing action button: a role-colored capsule that shrinks on
/// press (matching the iOS `PressableButtonStyle`). It does **not** invoke the
/// action callback directly — [onPressed] routes a `actionTapped` event through
/// the controller so the facade owns callback dispatch and stale-tap dropping.
class ToastActionButton extends StatefulWidget {
  const ToastActionButton({
    super.key,
    required this.action,
    required this.brightness,
    required this.onPressed,
  });

  final ToastAction action;
  final Brightness brightness;
  final VoidCallback onPressed;

  @override
  State<ToastActionButton> createState() => _ToastActionButtonState();
}

class _ToastActionButtonState extends State<ToastActionButton> {
  bool _pressed = false;

  Color _roleColor() {
    final dark = widget.brightness == Brightness.dark;
    final override = widget.action.color;
    if (override != null) return dark ? override.dark : override.light;
    switch (widget.action.role) {
      case ToastActionRole.primary:
        return dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
      case ToastActionRole.secondary:
        return dark ? Colors.white70 : Colors.black54;
      case ToastActionRole.destructive:
        return dark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30);
      case ToastActionRole.success:
        return dark ? const Color(0xFF30D158) : const Color(0xFF34C759);
      case ToastActionRole.warning:
        return dark ? const Color(0xFFFF9F0A) : const Color(0xFFFF9500);
      case ToastActionRole.neutral:
        return (dark ? Colors.white : Colors.black).withValues(alpha: 0.7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _roleColor();
    final dark = widget.brightness == Brightness.dark;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onPressed();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: dark ? 0.24 : 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            widget.action.label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
