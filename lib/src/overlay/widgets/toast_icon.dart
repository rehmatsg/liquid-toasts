import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../toast.dart';
import '../../toast_style.dart';
import '../sf_symbol_icons.dart';

/// The toast's leading icon well: a spinner while loading, otherwise the
/// resolved Material icon with an optional (best-effort) symbol effect. Morphs
/// between the two with a scale + fade — the cross-platform analog of iOS's
/// spinner→icon transition.
class ToastIconView extends StatelessWidget {
  const ToastIconView({
    super.key,
    required this.toast,
    required this.brightness,
    this.size = 22,
  });

  final Toast toast;
  final Brightness brightness;
  final double size;

  Color _resolveColor() {
    final dark = brightness == Brightness.dark;
    Color? pick(ToastColor? c) => c == null ? null : (dark ? c.dark : c.light);
    final style = toast.style;
    final color = pick(style?.iconColor) ??
        pick(style?.tint) ??
        SfSymbolIcons.semanticTint(toast.semantic, brightness);
    return color ?? (dark ? Colors.white : Colors.black.withValues(alpha: 0.85));
  }

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor();
    final Widget child;
    if (toast.loading) {
      child = _Spinner(key: const ValueKey('spinner'), color: color, size: size);
    } else {
      final icon = SfSymbolIcons.resolve(toast);
      if (icon == null) return const SizedBox.shrink();
      child = _EffectIcon(
        key: ValueKey('icon_${icon.codePoint}'),
        icon: icon,
        color: color,
        size: size,
        effect: toast.style?.symbolEffect ?? ToastSymbolEffect.none,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
        child: child,
      ),
    );
  }
}

/// A trimmed, spinning arc matching the iOS spinner (0.72 sweep, 0.85s/turn).
class _Spinner extends StatefulWidget {
  const _Spinner({super.key, required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Transform.rotate(
        angle: _c.value * 2 * math.pi,
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _ArcPainter(widget.color),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = color;
    final rect = (Offset.zero & size).deflate(1.25);
    canvas.drawArc(rect, -math.pi / 2, 0.72 * 2 * math.pi, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => oldDelegate.color != color;
}

/// A Material icon with a best-effort port of the SF Symbol effect. Effects with
/// no clean Flutter equivalent fall back to a one-shot bounce.
class _EffectIcon extends StatefulWidget {
  const _EffectIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.size,
    required this.effect,
  });

  final IconData icon;
  final Color color;
  final double size;
  final ToastSymbolEffect effect;

  @override
  State<_EffectIcon> createState() => _EffectIconState();
}

class _EffectIconState extends State<_EffectIcon> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    switch (widget.effect) {
      case ToastSymbolEffect.none:
        break;
      case ToastSymbolEffect.bounce:
      case ToastSymbolEffect.wiggle:
      case ToastSymbolEffect.breathe:
      case ToastSymbolEffect.drawOn:
        _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
          ..forward();
      case ToastSymbolEffect.pulse:
      case ToastSymbolEffect.variableColor:
      case ToastSymbolEffect.rotate:
        _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
          ..repeat(reverse: widget.effect != ToastSymbolEffect.rotate);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(widget.icon, size: widget.size, color: widget.color);
    final c = _c;
    if (c == null) return icon;
    return AnimatedBuilder(
      animation: c,
      child: icon,
      builder: (context, child) {
        switch (widget.effect) {
          case ToastSymbolEffect.rotate:
            return Transform.rotate(angle: c.value * 2 * math.pi, child: child);
          case ToastSymbolEffect.variableColor:
            return Opacity(opacity: 0.45 + 0.55 * c.value, child: child);
          case ToastSymbolEffect.pulse:
            return Transform.scale(scale: 1 + 0.12 * c.value, child: child);
          case ToastSymbolEffect.bounce:
          case ToastSymbolEffect.wiggle:
          case ToastSymbolEffect.breathe:
          case ToastSymbolEffect.drawOn:
            final s = Curves.elasticOut.transform(c.value.clamp(0.0, 1.0));
            return Transform.scale(scale: 0.6 + 0.4 * s, child: child);
          case ToastSymbolEffect.none:
            return child!;
        }
      },
    );
  }
}
