import 'dart:typed_data' show Uint8List;
import 'dart:ui' show VoidCallback;

import 'package:flutter/painting.dart' show ImageProvider;
import 'package:meta/meta.dart';

import 'toast_action.dart';
import 'toast_position.dart';
import 'toast_style.dart';

/// An immutable description of a toast.
///
/// A pure value type — no [BuildContext], no platform handles — so it is safe to
/// construct anywhere (services, blocs, isolated business logic). Use the named
/// constructors ([Toast.success], [Toast.error], [Toast.warning], [Toast.info],
/// [Toast.loading]) for ergonomics, or the default constructor for full control.
@immutable
class Toast {
  const Toast({
    required this.message,
    this.title,
    this.icon,
    this.leadingImage,
    this.semantic = ToastSemantic.none,
    this.style,
    this.position = ToastPosition.topCenter,
    this.duration = const Duration(seconds: 3),
    this.action,
    this.useDynamicIslandOrigin = true,
    this.onTap,
    this.tapToDismiss = true,
    this.groupKey,
    this.progress,
    this.progressStyle = ToastProgressStyle.linear,
    this.haptic,
    this.semanticsLabel,
    this.maxLines = 1,
  }) : loading = false;

  const Toast._loading({
    required this.message,
    this.title,
    this.icon,
    this.style,
    this.position = ToastPosition.topCenter,
    this.useDynamicIslandOrigin = true,
    this.groupKey,
    this.progress,
    this.progressStyle = ToastProgressStyle.linear,
    this.semanticsLabel,
    this.maxLines = 1,
  })  : semantic = ToastSemantic.none,
        leadingImage = null,
        duration = null,
        action = null,
        onTap = null,
        tapToDismiss = false,
        haptic = null,
        loading = true;

  /// A persistent spinner toast. Typically created for you by
  /// [LiquidToasts.showLoading], but also usable directly for a manual
  /// loading state you later [ToastHandle.update] or [ToastHandle.dismiss].
  factory Toast.loading({
    required String message,
    String? title,
    String? icon,
    ToastStyleOverride? style,
    ToastPosition position = ToastPosition.topCenter,
    bool useDynamicIslandOrigin = true,
    String? groupKey,
    double? progress,
    ToastProgressStyle progressStyle = ToastProgressStyle.linear,
    String? semanticsLabel,
    int maxLines = 1,
  }) =>
      Toast._loading(
        message: message,
        title: title,
        icon: icon,
        style: style,
        position: position,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
        groupKey: groupKey,
        progress: progress,
        progressStyle: progressStyle,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
      );

  factory Toast.success({
    required String message,
    String? title,
    String? icon,
    ToastStyleOverride? style,
    ToastPosition position = ToastPosition.topCenter,
    Duration? duration = const Duration(seconds: 3),
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    bool useDynamicIslandOrigin = true,
    String? groupKey,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int maxLines = 1,
  }) =>
      Toast(
        message: message,
        title: title,
        icon: icon,
        semantic: ToastSemantic.success,
        style: style,
        position: position,
        duration: duration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
        groupKey: groupKey,
        haptic: haptic,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
      );

  factory Toast.error({
    required String message,
    String? title,
    String? icon,
    ToastStyleOverride? style,
    ToastPosition position = ToastPosition.topCenter,
    Duration? duration = const Duration(seconds: 4),
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    bool useDynamicIslandOrigin = true,
    String? groupKey,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int maxLines = 2,
  }) =>
      Toast(
        message: message,
        title: title,
        icon: icon,
        semantic: ToastSemantic.error,
        style: style,
        position: position,
        duration: duration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
        groupKey: groupKey,
        haptic: haptic,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
      );

  factory Toast.warning({
    required String message,
    String? title,
    String? icon,
    ToastStyleOverride? style,
    ToastPosition position = ToastPosition.topCenter,
    Duration? duration = const Duration(seconds: 3),
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    bool useDynamicIslandOrigin = true,
    String? groupKey,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int maxLines = 2,
  }) =>
      Toast(
        message: message,
        title: title,
        icon: icon,
        semantic: ToastSemantic.warning,
        style: style,
        position: position,
        duration: duration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
        groupKey: groupKey,
        haptic: haptic,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
      );

  factory Toast.info({
    required String message,
    String? title,
    String? icon,
    ToastStyleOverride? style,
    ToastPosition position = ToastPosition.topCenter,
    Duration? duration = const Duration(seconds: 3),
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    bool useDynamicIslandOrigin = true,
    String? groupKey,
    ToastHaptic? haptic,
    String? semanticsLabel,
    int maxLines = 1,
  }) =>
      Toast(
        message: message,
        title: title,
        icon: icon,
        semantic: ToastSemantic.info,
        style: style,
        position: position,
        duration: duration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
        groupKey: groupKey,
        haptic: haptic,
        semanticsLabel: semanticsLabel,
        maxLines: maxLines,
      );

  /// Primary line. Truncated to [maxLines] natively.
  final String message;

  /// Optional bold line above [message].
  final String? title;

  /// SF Symbol name (e.g. `'checkmark.circle.fill'`). When null, the symbol is
  /// derived from [semantic] natively. An explicit value wins.
  final String? icon;

  /// A raster image shown in the leading slot (a circular avatar / thumbnail),
  /// in place of the SF Symbol. Any Flutter [ImageProvider] works
  /// (`AssetImage`, `NetworkImage`, `MemoryImage`, …); it's resolved to bytes on
  /// the Dart side and handed to the native renderer, so the usual Flutter image
  /// pipeline (and its caching) applies. Wins over [icon] when set.
  final ImageProvider? leadingImage;

  final ToastSemantic semantic;
  final ToastStyleOverride? style;
  final ToastPosition position;

  /// `null` or [Duration.zero] ⇒ persistent (requires explicit dismissal).
  final Duration? duration;

  /// At most one action button.
  final ToastAction? action;

  /// Honored only for [ToastPosition.topCenter] on Dynamic Island devices.
  /// Set false to keep top-center placement but use a plain slide-in.
  final bool useDynamicIslandOrigin;

  /// Tapping the toast body invokes this (in addition to any [tapToDismiss]).
  final VoidCallback? onTap;

  /// Whether tapping the toast body dismisses it.
  final bool tapToDismiss;

  /// De-dup / replace key. Showing a toast whose [groupKey] matches a live one
  /// replaces it in place (morph) instead of stacking a duplicate.
  final String? groupKey;

  /// Determinate progress 0.0–1.0 for upload-style toasts. Null ⇒ no bar.
  final double? progress;

  /// How [progress] renders — a linear bar under the text or a circular ring in
  /// the leading slot. Ignored when [progress] is null.
  final ToastProgressStyle progressStyle;

  /// Haptic fired on appear. Null ⇒ derived from [semantic].
  final ToastHaptic? haptic;

  /// VoiceOver label. Falls back to `title` + `message` natively.
  final String? semanticsLabel;

  /// Max text lines before truncation.
  final int maxLines;

  /// True for a persistent spinner toast.
  final bool loading;

  bool get isPersistent =>
      loading || duration == null || duration == Duration.zero;

  ToastHaptic get _effectiveHaptic {
    if (haptic != null) return haptic!;
    if (loading) return ToastHaptic.none;
    switch (semantic) {
      case ToastSemantic.success:
        return ToastHaptic.success;
      case ToastSemantic.error:
        return ToastHaptic.error;
      case ToastSemantic.warning:
        return ToastHaptic.warning;
      case ToastSemantic.info:
      case ToastSemantic.none:
        return ToastHaptic.none;
    }
  }

  /// Wire format. [actionId] is the id minted for [action] (omit when there is
  /// no action). Colors serialize as `{light,dark}` maps; durations as ms.
  Map<String, Object?> toMap({String? actionId, Uint8List? imageBytes}) => {
        'message': message,
        if (title != null) 'title': title,
        if (icon != null) 'icon': icon,
        'image': ?imageBytes,
        'semantic': semantic.name,
        if (style != null) 'style': style!.toMap(),
        'position': position.name,
        'state': loading ? 'loading' : 'static',
        'persistent': isPersistent,
        if (!isPersistent) 'durationMs': duration!.inMilliseconds,
        'useDynamicIslandOrigin': useDynamicIslandOrigin,
        if (progress != null) 'progress': progress,
        if (progress != null) 'progressStyle': progressStyle.name,
        if (groupKey != null) 'groupKey': groupKey,
        'haptic': _effectiveHaptic.name,
        if (semanticsLabel != null) 'semanticsLabel': semanticsLabel,
        'maxLines': maxLines,
        'tapToDismiss': tapToDismiss,
        'hasTap': onTap != null,
        if (action != null) 'action': action!.toMap(actionId ?? 'a0'),
      };
}
