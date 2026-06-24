import 'dart:ui' show VoidCallback;

import 'package:meta/meta.dart';

import 'toast_style.dart';

/// Semantic role of a toast's action button. The actual color is derived from
/// the role **on the native side** (so it adapts to dark mode and the toast's
/// glass treatment), unless [ToastAction.color] overrides it. This exact set is
/// mirrored 1:1 on the platform side.
enum ToastActionRole { primary, secondary, destructive, success, warning, neutral }

/// The single (at most one) action button on a toast. "At most one" is enforced
/// structurally by [Toast.action] being a single field rather than a list.
///
/// The button is always rendered as a fully-rounded capsule natively. Its color
/// comes from [role] unless [color] is supplied. [onPressed] never crosses the
/// platform channel — it stays in Dart, keyed by toast id, and is invoked when
/// native reports the tap.
@immutable
class ToastAction {
  const ToastAction({
    required this.label,
    required this.onPressed,
    this.role = ToastActionRole.primary,
    this.color,
    this.dismissOnPress = true,
  });

  final String label;

  /// Invoked on the Dart isolate when native reports the tap. Wrapped in a
  /// guard by the facade so a throwing callback can't poison the event stream.
  final VoidCallback onPressed;

  final ToastActionRole role;

  /// Hard color override; bypasses [role]-to-color derivation.
  final ToastColor? color;

  /// If true, the toast dismisses itself after the tap is delivered.
  final bool dismissOnPress;

  /// Wire format. [actionId] correlates a native `actionTapped` event back to
  /// [onPressed]; it is minted by the facade and validated to drop stale taps.
  Map<String, Object?> toMap(String actionId) => {
        'actionId': actionId,
        'label': label,
        'role': role.name,
        if (color != null) 'color': color!.toMap(),
        'dismissOnPress': dismissOnPress,
      };
}
