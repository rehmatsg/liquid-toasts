import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../liquid_toasts_config.dart';
import '../toast.dart';
import '../toast_event.dart';
import '../toast_position.dart';
import '../toast_style.dart';

/// Lifecycle phase of a live toast on the overlay.
enum ToastPhase { entering, visible, exiting }

/// A toast that is currently tracked by the overlay, with its mutable runtime
/// state. The widget layer keys cards by the [LiveToast] instance (not [id]) so
/// a `groupKey` replace can swap [id]/[toast] in place without re-triggering the
/// entrance animation — mirroring the iOS "morph in place" behavior.
class LiveToast {
  LiveToast({required this.id, required this.toast, this.actionId});

  /// Mutable: a `groupKey` replace reassigns the slot to a new toast id.
  String id;
  Toast toast;
  String? actionId;

  /// Wall-clock expiry. Null for persistent/loading toasts. Stored so timers can
  /// be re-derived after the app returns from the background.
  DateTime? deadline;

  ToastPhase phase = ToastPhase.entering;

  /// Set when the toast begins leaving; lets the card pick its exit motion.
  ToastDismissReason? exitReason;
}

/// The headless source of truth for the Flutter overlay's toast stack — the
/// cross-platform port of the native `ToastManager`.
///
/// Owns the queue, replace-by-`groupKey`, per-position `maxVisible`, wall-clock
/// auto-dismiss (surviving backgrounding), exactly-once teardown, and lifecycle
/// event emission. It is deliberately free of widget/render code so it can be
/// unit-tested headlessly; the render tree observes it as a [ChangeNotifier].
class ToastOverlayController extends ChangeNotifier with WidgetsBindingObserver {
  ToastOverlayController({required this.emit});

  /// Sink for native-equivalent lifecycle events, routed by the facade.
  final void Function(ToastEvent event) emit;

  final List<LiveToast> _toasts = [];
  final Map<String, Timer> _timers = {};

  int _maxVisible = 5;
  ToastDropPolicy _dropPolicy = ToastDropPolicy.dropOldest;
  bool _observing = false;

  /// Auto-dismiss bounds, matching the iOS clamp.
  static const int _minDurationMs = 1500;
  static const int _maxDurationMs = 10000;

  /// The live stack, in insertion order (read-only view for the render tree).
  List<LiveToast> get toasts => List.unmodifiable(_toasts);

  void configure(LiquidToastsConfig config) {
    _maxVisible = config.maxVisible < 1 ? 1 : config.maxVisible;
    _dropPolicy = config.dropPolicy;
  }

  /// Adds [toast] to the stack, or morphs an existing same-`groupKey` toast in
  /// place (emitting `dismissed(replaced)` for the old identity + `shown` for
  /// the new). Arms auto-dismiss, fires the haptic, and emits `shown`.
  void present(String id, Toast toast, String? actionId) {
    _ensureObserving();

    final groupKey = toast.groupKey;
    if (groupKey != null) {
      final existing = _firstLiveWhere((t) => t.toast.groupKey == groupKey);
      if (existing != null) {
        final oldId = existing.id;
        _cancelTimer(oldId);
        existing
          ..id = id
          ..toast = toast
          ..actionId = actionId
          ..phase = ToastPhase.visible
          ..exitReason = null;
        emit(ToastEvent(
          id: oldId,
          kind: ToastEventKind.dismissed,
          reason: ToastDismissReason.replaced,
        ));
        _arm(existing);
        _fireHaptic(_effectiveHaptic(toast));
        emit(_shownEvent(existing));
        notifyListeners();
        return;
      }
    }

    final live = LiveToast(id: id, toast: toast, actionId: actionId);
    _toasts.add(live);
    _arm(live);
    _enforceLimit(toast.position);
    _fireHaptic(_effectiveHaptic(toast));
    emit(_shownEvent(live));
    notifyListeners();
  }

  /// Replaces the content of the live toast [id] in place (the `update` path,
  /// used by `showLoading`'s loading→success/error morph). Re-arms auto-dismiss
  /// from the new toast's duration. Returns `false` if the toast was already
  /// gone (an expected race).
  bool morph(String id, Toast toast, String? actionId) {
    final live = _firstLiveWhere((t) => t.id == id);
    if (live == null) return false;
    live
      ..toast = toast
      ..actionId = actionId
      ..exitReason = null;
    _arm(live);
    emit(_shownEvent(live));
    notifyListeners();
    return true;
  }

  /// Begins tearing down toast [id] with [reason]. Returns whether it was live.
  bool requestDismiss(String id, ToastDismissReason reason) {
    final live = _firstLiveWhere((t) => t.id == id);
    if (live == null) return false;
    _beginExit(live, reason);
    notifyListeners();
    return true;
  }

  /// Tears down every live toast. Returns the ids actually torn down so the
  /// facade can reconcile its registry in one pass.
  List<String> dismissAll(ToastDismissReason reason) {
    final ids = <String>[];
    for (final live in _toasts) {
      if (live.phase != ToastPhase.exiting) {
        ids.add(live.id);
        _beginExit(live, reason);
      }
    }
    if (ids.isNotEmpty) notifyListeners();
    return ids;
  }

  /// Called by a card once its exit animation finishes — removes it for good.
  void onExitComplete(String id) {
    final idx = _toasts.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    _toasts.removeAt(idx);
    notifyListeners();
  }

  // --- Gesture / interaction routing (events only; callbacks live in the facade) ---

  void handleTap(LiveToast live) {
    if (live.toast.onTap != null) {
      emit(ToastEvent(id: live.id, kind: ToastEventKind.tap));
    }
    if (live.toast.tapToDismiss) {
      requestDismiss(live.id, ToastDismissReason.tap);
    }
  }

  void handleAction(LiveToast live) {
    emit(ToastEvent(
      id: live.id,
      kind: ToastEventKind.action,
      actionId: live.actionId,
    ));
    if (live.toast.action?.dismissOnPress ?? false) {
      requestDismiss(live.id, ToastDismissReason.action);
    }
  }

  void handleSwipeDismiss(LiveToast live) {
    requestDismiss(live.id, ToastDismissReason.swipe);
  }

  // --- Internals ---

  void _beginExit(LiveToast live, ToastDismissReason reason) {
    if (live.phase == ToastPhase.exiting) return;
    _cancelTimer(live.id);
    live
      ..phase = ToastPhase.exiting
      ..exitReason = reason;
    emit(ToastEvent(
      id: live.id,
      kind: ToastEventKind.dismissed,
      reason: reason,
    ));
  }

  void _enforceLimit(ToastPosition position) {
    final inPosition = _toasts
        .where((t) => t.toast.position == position && t.phase != ToastPhase.exiting)
        .toList();
    final overflow = inPosition.length - _maxVisible;
    if (overflow <= 0) return;
    final victims = _dropPolicy == ToastDropPolicy.dropOldest
        ? inPosition.take(overflow)
        : inPosition.skip(inPosition.length - overflow);
    for (final victim in victims.toList()) {
      _beginExit(victim, ToastDismissReason.replaced);
    }
  }

  void _arm(LiveToast live) {
    _cancelTimer(live.id);
    final toast = live.toast;
    if (toast.isPersistent) {
      live.deadline = null;
      return;
    }
    final ms = toast.duration!.inMilliseconds
        .clamp(_minDurationMs, _maxDurationMs)
        .toInt();
    live.deadline = DateTime.now().add(Duration(milliseconds: ms));
    _timers[live.id] = Timer(Duration(milliseconds: ms), () {
      _timers.remove(live.id);
      requestDismiss(live.id, ToastDismissReason.timeout);
    });
  }

  void _cancelTimer(String id) => _timers.remove(id)?.cancel();

  LiveToast? _firstLiveWhere(bool Function(LiveToast) test) {
    for (final t in _toasts) {
      if (t.phase != ToastPhase.exiting && test(t)) return t;
    }
    return null;
  }

  ToastEvent _shownEvent(LiveToast live) {
    final group = _toasts
        .where((t) =>
            t.toast.position == live.toast.position &&
            t.phase != ToastPhase.exiting)
        .toList();
    final index = group.indexOf(live);
    return ToastEvent(
      id: live.id,
      kind: ToastEventKind.shown,
      stackIndex: index < 0 ? 0 : index,
    );
  }

  void _ensureObserving() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _resumeDeadlines();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _suspendTimers();
    }
  }

  void _suspendTimers() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  void _resumeDeadlines() {
    final now = DateTime.now();
    final expired = <LiveToast>[];
    for (final live in _toasts) {
      if (live.phase == ToastPhase.exiting) continue;
      final deadline = live.deadline;
      if (deadline == null) continue;
      if (!deadline.isAfter(now)) {
        expired.add(live);
      } else {
        _timers[live.id] = Timer(deadline.difference(now), () {
          _timers.remove(live.id);
          requestDismiss(live.id, ToastDismissReason.timeout);
        });
      }
    }
    for (final live in expired) {
      _beginExit(live, ToastDismissReason.appBackgrounded);
    }
    if (expired.isNotEmpty) notifyListeners();
  }

  ToastHaptic _effectiveHaptic(Toast toast) {
    if (toast.haptic != null) return toast.haptic!;
    if (toast.loading) return ToastHaptic.none;
    switch (toast.semantic) {
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

  void _fireHaptic(ToastHaptic haptic) {
    switch (haptic) {
      case ToastHaptic.none:
        break;
      case ToastHaptic.success:
        HapticFeedback.mediumImpact();
      case ToastHaptic.warning:
        HapticFeedback.heavyImpact();
      case ToastHaptic.error:
        HapticFeedback.heavyImpact();
      case ToastHaptic.selection:
        HapticFeedback.selectionClick();
    }
  }

  /// Drops every toast with no events. Used on hot-restart handshake as a
  /// safety net (the widget tree is normally rebuilt from scratch anyway).
  void flushAll() {
    _suspendTimers();
    if (_toasts.isEmpty) return;
    _toasts.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    _suspendTimers();
    super.dispose();
  }
}
