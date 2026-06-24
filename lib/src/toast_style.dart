import 'dart:ui' show Color;

import 'package:meta/meta.dart';

/// Built-in semantic intent. Drives the default icon and color on the native
/// side. Every default is overridable via [ToastStyleOverride].
enum ToastSemantic { success, error, warning, info, none }

/// Glass rendering intent. The actual decision (native Liquid Glass on iOS 26+
/// vs. a frosted-material fallback below) is made **at render time on-device**;
/// Dart only expresses intent. [adaptive] is the right default everywhere.
enum ToastGlass { adaptive, liquid, frosted, solid, none }

/// Haptic feedback fired when a toast appears. Defaults are derived from the
/// toast's [ToastSemantic] when left unset.
enum ToastHaptic { none, success, warning, error, selection }

/// An animated SF Symbol effect applied to the toast's icon.
///
/// - [bounce] fires once when the icon appears.
/// - [pulse], [variableColor] loop while visible (iOS 17+).
/// - [wiggle], [rotate], [breathe] loop while visible (iOS 18+; fall back to
///   [pulse] on iOS 17).
/// - [drawOn] traces the symbol on as it appears (SF Symbols 7 / iOS 26+; falls
///   back to [bounce] below). Best on stroke-based symbols.
enum ToastSymbolEffect {
  none,
  bounce,
  pulse,
  wiggle,
  rotate,
  breathe,
  variableColor,
  drawOn,
}

/// A color that adapts to light/dark appearance without a [BuildContext].
///
/// Pass one [Color] for a frozen (non-adaptive) value, or supply [dark] to get
/// a value that resolves natively against the trait collection — the
/// context-free equivalent of a dynamic system color. Prefer semantic roles
/// (which are fully adaptive) over frozen overrides where possible.
@immutable
class ToastColor {
  const ToastColor(this.light, {Color? dark}) : dark = dark ?? light;

  final Color light;
  final Color dark;

  /// Wire format: `{light: ARGB, dark: ARGB}`.
  Map<String, int> toMap() => {
        'light': light.toARGB32(),
        'dark': dark.toARGB32(),
      };

  @override
  bool operator ==(Object other) =>
      other is ToastColor && other.light == light && other.dark == dark;

  @override
  int get hashCode => Object.hash(light, dark);
}

/// Per-toast visual override. Every field is null-means-inherit: anything left
/// null falls back to the semantic-derived value computed natively (which is
/// where the adaptive Liquid Glass / dark-mode defaults live).
@immutable
class ToastStyleOverride {
  const ToastStyleOverride({
    this.tint,
    this.foreground,
    this.iconColor,
    this.glass,
    this.cornerRadius,
    this.symbolEffect = ToastSymbolEffect.none,
  });

  /// Accent / surface tint. The toast's glass surface stays neutral for the
  /// premium refraction look; the tint mainly colors the icon well.
  final ToastColor? tint;

  /// Title + message color.
  final ToastColor? foreground;

  /// Icon color (defaults to [foreground] or [tint] natively).
  final ToastColor? iconColor;

  /// Glass treatment. Null inherits the app-wide default ([ToastGlass.adaptive]).
  final ToastGlass? glass;

  /// Corner radius. Null lets native choose (capsule for compact, rounded rect
  /// for multi-line).
  final double? cornerRadius;

  /// Animated effect applied to the icon's SF Symbol.
  final ToastSymbolEffect symbolEffect;

  Map<String, Object?> toMap() => {
        if (tint != null) 'tint': tint!.toMap(),
        if (foreground != null) 'foreground': foreground!.toMap(),
        if (iconColor != null) 'iconColor': iconColor!.toMap(),
        if (glass != null) 'glass': glass!.name,
        if (cornerRadius != null) 'cornerRadius': cornerRadius,
        if (symbolEffect != ToastSymbolEffect.none)
          'symbolEffect': symbolEffect.name,
      };
}
