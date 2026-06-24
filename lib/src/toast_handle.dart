import 'dart:async';

import 'toast.dart';
import 'toast_event.dart';

/// A live controller for a shown toast, returned by every `show*` call.
///
/// Lets callers [update] or [dismiss] a (typically persistent) toast and
/// `await` its dismissal. The backing completer is **always** completed — by the
/// terminal native event, by `dismissAll` reconciliation, or fail-safe if the
/// event channel is lost — so `await handle.onDismissed` never hangs.
class ToastHandle {
  /// Internal: constructed by the facade, which owns [completer] and the
  /// update/dismiss closures. Not intended for direct use.
  ToastHandle.internal(
    this.id,
    this.completer,
    this._update,
    this._dismiss,
  );

  final String id;

  /// Owned jointly with the facade registry so either side can complete it.
  final Completer<ToastDismissReason> completer;

  final Future<bool> Function(String id, Toast toast) _update;
  final Future<void> Function(String id) _dismiss;

  bool get isShowing => !completer.isCompleted;
  bool get isDismissed => completer.isCompleted;

  /// Resolves when the toast leaves the screen, with the reason.
  Future<ToastDismissReason> get onDismissed => completer.future;

  /// Mutates this toast in place (native cross-fades / morphs the content).
  /// Returns whether the update was applied (`false` if already dismissed or the
  /// native toast was gone — an expected race, not an error).
  Future<bool> update(Toast toast) =>
      isShowing ? _update(id, toast) : Future<bool>.value(false);

  /// Explicit dismissal. The only way to remove a persistent toast (besides a
  /// user swipe / tap). No-op if already dismissed.
  Future<void> dismiss() => isShowing ? _dismiss(id) : Future<void>.value();
}
