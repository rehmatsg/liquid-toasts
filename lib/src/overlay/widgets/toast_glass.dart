import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../toast_style.dart';

/// The toast's frosted background — the cross-platform stand-in for iOS Liquid
/// Glass. Because the overlay renders inside Flutter's own compositor, the
/// [BackdropFilter] blurs the *live app content* behind the toast (a real
/// backdrop blur), then a translucent fill + hairline border + soft shadow give
/// the frosted look. `glass: solid`/`none` renders an opaque surface instead.
class GlassBackground extends StatelessWidget {
  const GlassBackground({
    super.key,
    required this.child,
    required this.brightness,
    this.cornerRadius,
    this.glass,
  });

  final Widget child;
  final Brightness brightness;
  final double? cornerRadius;
  final ToastGlass? glass;

  @override
  Widget build(BuildContext context) {
    final dark = brightness == Brightness.dark;
    // A very large radius clamps to a capsule for typical toast heights, matching
    // the iOS default; an explicit cornerRadius switches to a rounded rectangle.
    final radius = BorderRadius.circular(cornerRadius ?? 999);
    final opaque = glass == ToastGlass.solid || glass == ToastGlass.none;

    final fill = opaque
        ? (dark ? const Color(0xFF2C2C2E) : Colors.white)
        : (dark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.60));
    final borderColor = dark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.65);

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: child,
    );

    if (!opaque) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: surface,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: radius, child: surface),
    );
  }
}
