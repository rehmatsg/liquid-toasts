import 'dart:async';

import 'package:flutter/foundation.dart';

import 'liquid_toasts_platform_interface.dart';
import 'src/ids.dart';
import 'src/liquid_toasts_config.dart';
import 'src/loading_toast.dart';
import 'src/toast.dart';
import 'src/toast_action.dart';
import 'src/toast_event.dart';
import 'src/toast_handle.dart';
import 'src/toast_position.dart';
import 'src/toast_style.dart';

export 'src/liquid_toasts_config.dart';
export 'src/loading_toast.dart';
export 'src/toast.dart';
export 'src/toast_action.dart';
export 'src/toast_event.dart';
export 'src/toast_handle.dart' show ToastHandle;
export 'src/toast_position.dart';
export 'src/toast_style.dart';
export 'src/overlay/overlay_liquid_toasts.dart' show OverlayLiquidToasts;

/// One live toast's Dart-side bookkeeping.
class _Registration {
  _Registration({
    required this.completer,
    this.action,
    this.activeActionId,
    this.onTap,
  });

  final Completer<ToastDismissReason> completer;
  ToastAction? action;
  String? activeActionId;
  VoidCallback? onTap;
}

/// The public, context-free entry point for showing native iOS toasts.
///
/// Everything is static — there is no [BuildContext] anywhere — so toasts can be
/// shown from services, blocs, interceptors, or anywhere else:
///
/// ```dart
/// LiquidToasts.success('Saved');
/// final user = await LiquidToasts.showLoading(api.signIn(), config: ...);
/// ```
class LiquidToasts {
  LiquidToasts._();

  static LiquidToastsPlatform get _platform => LiquidToastsPlatform.instance;

  static final Map<String, _Registration> _registry = {};
  static StreamSubscription<ToastEvent>? _eventSub;
  static bool _handshaken = false;
  static LiquidToastsConfig _config = const LiquidToastsConfig();

  /// Optional global hook mapping a thrown error to a user-safe message, used by
  /// [showLoading] when no per-call `onError` builder is supplied. Keeps
  /// `error.toString()` from leaking internals into a user-facing toast.
  static String Function(Object error)? errorMessageResolver;

  /// Number of toasts currently tracked (visible + queued).
  static int get activeCount => _registry.length;

  /// Ids of toasts currently tracked.
  static List<String> get activeIds => _registry.keys.toList(growable: false);

  /// Sets app-wide defaults (used by the convenience constructors) and pushes
  /// stack/queue configuration to native.
  static Future<void> setDefaults(LiquidToastsConfig config) async {
    _config = config;
    await _ensureInit();
    await _platform.configure(config);
  }

  // ---------------------------------------------------------------------------
  // Core
  // ---------------------------------------------------------------------------

  /// Shows [toast]. Resolves to a [ToastHandle] for later update/dismiss and to
  /// `await` its dismissal.
  static Future<ToastHandle> show(Toast toast) => _show(toast);

  /// Convenience: a success toast.
  static Future<ToastHandle> success(
    String message, {
    String? title,
    String? icon,
    ToastPosition? position,
    Duration? duration,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    ToastStyleOverride? style,
    String? groupKey,
    ToastHaptic? haptic,
    bool useDynamicIslandOrigin = true,
  }) =>
      _show(Toast.success(
        message: message,
        title: title,
        icon: icon,
        position: position ?? _config.defaultPosition,
        duration: duration ?? _config.defaultDuration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        style: style,
        groupKey: groupKey,
        haptic: haptic,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      ));

  /// Convenience: an error toast.
  static Future<ToastHandle> error(
    String message, {
    String? title,
    String? icon,
    ToastPosition? position,
    Duration? duration,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    ToastStyleOverride? style,
    String? groupKey,
    ToastHaptic? haptic,
    bool useDynamicIslandOrigin = true,
  }) =>
      _show(Toast.error(
        message: message,
        title: title,
        icon: icon,
        position: position ?? _config.defaultPosition,
        duration: duration ?? _config.defaultDuration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        style: style,
        groupKey: groupKey,
        haptic: haptic,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      ));

  /// Convenience: a warning toast.
  static Future<ToastHandle> warning(
    String message, {
    String? title,
    String? icon,
    ToastPosition? position,
    Duration? duration,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    ToastStyleOverride? style,
    String? groupKey,
    ToastHaptic? haptic,
    bool useDynamicIslandOrigin = true,
  }) =>
      _show(Toast.warning(
        message: message,
        title: title,
        icon: icon,
        position: position ?? _config.defaultPosition,
        duration: duration ?? _config.defaultDuration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        style: style,
        groupKey: groupKey,
        haptic: haptic,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      ));

  /// Convenience: an info toast.
  static Future<ToastHandle> info(
    String message, {
    String? title,
    String? icon,
    ToastPosition? position,
    Duration? duration,
    ToastAction? action,
    VoidCallback? onTap,
    bool tapToDismiss = true,
    ToastStyleOverride? style,
    String? groupKey,
    ToastHaptic? haptic,
    bool useDynamicIslandOrigin = true,
  }) =>
      _show(Toast.info(
        message: message,
        title: title,
        icon: icon,
        position: position ?? _config.defaultPosition,
        duration: duration ?? _config.defaultDuration,
        action: action,
        onTap: onTap,
        tapToDismiss: tapToDismiss,
        style: style,
        groupKey: groupKey,
        haptic: haptic,
        useDynamicIslandOrigin: useDynamicIslandOrigin,
      ));

  /// Ties [future] to a loading toast: a spinner while it runs, then a success
  /// or error toast.
  ///
  /// **Returns the future's value** (or rethrows its error) so the caller owns
  /// the outcome — dismissing the toast never swallows the result. The visual is
  /// best-effort: if the toast was dismissed mid-flight, the update is skipped
  /// but the value/error is still delivered.
  ///
  /// ```dart
  /// final user = await LiquidToasts.showLoading(
  ///   api.signIn(email, password),
  ///   config: const LoadingToast(
  ///     loadingMessage: 'Signing in…',
  ///     successMessage: 'Welcome back!',
  ///   ),
  ///   onSuccess: (u) => Toast.success(message: 'Hi ${u.name}!'),
  /// );
  /// ```
  static Future<T> showLoading<T>(
    Future<T> future, {
    required LoadingToast config,
    Toast Function(T value)? onSuccess,
    Toast Function(Object error, StackTrace stack)? onError,
  }) async {
    final handle = await _show(config.buildLoading());
    try {
      final value = await future;
      final toast = onSuccess?.call(value) ?? config.buildSuccess();
      if (handle.isShowing) await handle.update(toast);
      return value;
    } catch (error, stack) {
      final resolved = errorMessageResolver?.call(error);
      final toast = onError?.call(error, stack) ??
          config.buildError(error, resolvedMessage: resolved);
      if (handle.isShowing) await handle.update(toast);
      rethrow;
    }
  }

  /// Dismisses toast [id]. Prefer [ToastHandle.dismiss] when you hold a handle.
  static Future<void> dismiss(String id) => _dismiss(id);

  /// Dismisses every toast.
  static Future<void> dismissAll() async {
    final dismissedIds = await _platform.dismissAll();
    for (final id in dismissedIds) {
      _complete(id, ToastDismissReason.dismissAll);
    }
    // Belt and suspenders: complete anything native didn't report.
    for (final id in _registry.keys.toList()) {
      _complete(id, ToastDismissReason.dismissAll);
    }
  }

  /// Advisory device geometry / capability snapshot.
  static Future<Map<String, dynamic>> queryGeometry() {
    return _platform.queryGeometry();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  static Future<ToastHandle> _show(Toast toast) async {
    await _ensureInit();
    final id = nextToastId();
    final actionId = toast.action != null ? nextActionId() : null;
    final completer = Completer<ToastDismissReason>();
    _registry[id] = _Registration(
      completer: completer,
      action: toast.action,
      activeActionId: actionId,
      onTap: toast.onTap,
    );
    final handle = ToastHandle.internal(id, completer, _update, _dismiss);
    final accepted = await _platform.show(id, toast, actionId: actionId);
    if (!accepted) {
      _complete(id, ToastDismissReason.channelLost);
    }
    return handle;
  }

  static Future<bool> _update(String id, Toast toast) async {
    final reg = _registry[id];
    if (reg == null) return false;
    final actionId = toast.action != null ? nextActionId() : null;
    reg.action = toast.action;
    reg.activeActionId = actionId;
    reg.onTap = toast.onTap;
    return _platform.update(id, toast, actionId: actionId);
  }

  static Future<void> _dismiss(String id) async {
    final ok = await _platform.dismiss(id);
    // If native had already dropped it, no `dismissed` event will arrive —
    // complete the handle locally so `onDismissed` never hangs.
    if (!ok) _complete(id, ToastDismissReason.manual);
  }

  static Future<void> _ensureInit() async {
    if (!_handshaken) {
      _handshaken = true;
      try {
        await _platform.handshake(sessionPrefix);
      } catch (e, st) {
        _handshaken = false;
        _logError(e, st);
        rethrow;
      }
    }
    _eventSub ??= _platform.events.listen(
      _onEvent,
      onError: (Object e, StackTrace st) => _logError(e, st),
      onDone: () => _failAll(ToastDismissReason.channelLost),
      cancelOnError: false,
    );
  }

  static void _onEvent(ToastEvent e) {
    final reg = _registry[e.id];
    if (reg == null) return; // stale / unknown id
    switch (e.kind) {
      case ToastEventKind.action:
        // Drop a stale tap that arrived after an update swapped the action.
        if (e.actionId != null && e.actionId != reg.activeActionId) return;
        _guarded(reg.action?.onPressed);
      case ToastEventKind.tap:
        _guarded(reg.onTap);
      case ToastEventKind.dismissed:
        _complete(e.id, e.reason);
      case ToastEventKind.shown:
      case ToastEventKind.unknown:
        break;
    }
  }

  static void _guarded(VoidCallback? cb) {
    if (cb == null) return;
    try {
      cb();
    } catch (e, st) {
      _logError(e, st);
    }
  }

  static void _complete(String id, ToastDismissReason reason) {
    final reg = _registry.remove(id);
    if (reg == null) return;
    if (!reg.completer.isCompleted) reg.completer.complete(reason);
  }

  static void _failAll(ToastDismissReason reason) {
    final regs = _registry.values.toList();
    _registry.clear();
    for (final r in regs) {
      if (!r.completer.isCompleted) r.completer.complete(reason);
    }
    _eventSub = null; // allow re-subscription on the next show
  }

  static void _logError(Object e, StackTrace st) {
    if (kDebugMode) {
      debugPrint('[liquid_toasts] $e\n$st');
    }
  }

  /// Resets all static state. Test-only — lets each test start clean.
  @visibleForTesting
  static Future<void> debugReset() async {
    await _eventSub?.cancel();
    _eventSub = null;
    _registry.clear();
    _handshaken = false;
    _config = const LiquidToastsConfig();
    errorMessageResolver = null;
  }

  /// Emits a native event into the facade's router. Test-only.
  @visibleForTesting
  static void debugEmit(ToastEvent event) => _onEvent(event);
}
