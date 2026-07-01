import SwiftUI
import UIKit

/// The single source of truth for the toast stack. Owns the queue,
/// replace-by-`groupKey`, per-position `maxVisible` enforcement, exactly-once
/// teardown, and emits lifecycle events back to the plugin via [onEvent].
/// Auto-dismiss timing (wall-clock deadlines, pause banking, backgrounding)
/// lives in [DeadlineScheduler].
@MainActor
final class ToastManager: ObservableObject {
  /// The one SwiftUI input: the stack itself. Everything the render tree needs
  /// lives on the models — including runtime flags like
  /// `ToastModel.isActionBusy` — so a change to one toast invalidates the
  /// container once and per-row equality gating keeps the other rows cheap.
  @Published private(set) var toasts: [ToastModel] = []

  /// Top safe-area inset (set by the overlay host from the window). Drives the
  /// entrance slide distance. The host writes it only on change.
  @Published var topSafeArea: CGFloat = 0

  /// Frames (window coordinates) of the interactive toasts, fed by the SwiftUI
  /// layer and read ONLY imperatively by the overlay host's hit-test.
  /// Deliberately **not** `@Published`: no SwiftUI view depends on it, and it
  /// updates on every animation frame of a drag or stack spring — publishing
  /// it would invalidate the whole container per frame.
  var frames: [String: CGRect] = [:]

  /// Bumped exactly when the set of toast ids changes (present / teardown /
  /// flush) — the container's `.animation(value:)` token. Content morphs keep
  /// the generation; they ride the mutation-site `withAnimation`. Plain (not
  /// published) because it only ever changes in the same transaction as
  /// `toasts`.
  private(set) var stackGeneration = 0

  /// Max toasts shown per position (a vertical list); the oldest is dismissed
  /// when a new toast would exceed this.
  var maxVisible: Int = 5
  var maxQueue: Int = 8
  var dropOldest: Bool = true

  /// Emits a wire-ready event payload to the plugin's event sink.
  var onEvent: (([String: Any]) -> Void)?

  private let scheduler = DeadlineScheduler()

  /// Guards stale async image decodes: each present/update with bytes bumps
  /// the toast's generation, and a decode only attaches if it still matches.
  private var imageGeneration: [String: Int] = [:]

  private var stackSpring: Animation { ToastMetrics.stackSpring }

  init() {
    // The existing teardown guard preserves exactly-once if a stale expiry
    // races a manual dismissal.
    scheduler.onExpire = { [weak self] id, reason in
      self?.teardown(id: id, reason: reason)
    }
  }

  // MARK: - Present / update / dismiss

  func present(_ model: ToastModel, imageData: Data? = nil) {
    // Replace-by-groupKey: morph an existing toast instead of stacking a dup.
    if let key = model.groupKey,
       let index = toasts.firstIndex(where: { $0.groupKey == key }) {
      let oldId = toasts[index].id
      scheduler.disarm(id: oldId)
      frames[oldId] = nil
      imageGeneration[oldId] = nil
      var incoming = model
      if imageData != nil, let preserved = toasts[index].image {
        // Keep the old avatar up until the fresh decode lands (no blank flash).
        incoming.image = preserved
      }
      stackGeneration += 1
      withAnimation(stackSpring) { toasts[index] = incoming }
      emitDismissed(oldId, reason: "replaced")
      scheduler.arm(id: model.id, duration: model.autoDuration)
      fireHaptic(model)
      emitShown(model)
      decodeImageIfNeeded(id: model.id, data: imageData)
      return
    }

    stackGeneration += 1
    withAnimation(stackSpring) {
      toasts.append(model)
    }
    enforcePositionLimit(model.position)
    scheduler.arm(id: model.id, duration: model.autoDuration)
    fireHaptic(model)
    emitShown(model)
    decodeImageIfNeeded(id: model.id, data: imageData)
  }

  @discardableResult
  func update(id: String, with toast: ToastModel, imageData: Data? = nil) -> Bool {
    guard let index = toasts.firstIndex(where: { $0.id == id }) else { return false }
    var updated = toasts[index]
    let preserved = updated.image
    // applyContent also clears isActionBusy — a morph supersedes any in-flight
    // action spinner.
    updated.applyContent(from: toast)
    if imageData != nil {
      // Keep the old avatar up until the fresh decode lands (no blank flash).
      updated.image = preserved
    }
    // Morph in place — the list keeps every toast visible, so there is no need
    // to reorder a resolving toast. The id is unchanged, so stackGeneration
    // stays put and only this row re-renders.
    withAnimation(stackSpring) {
      toasts[index] = updated
    }
    scheduler.arm(id: id, duration: updated.autoDuration)
    fireHaptic(updated)
    decodeImageIfNeeded(id: id, data: imageData)
    return true
  }

  @discardableResult
  func dismiss(id: String, reason: String) -> Bool {
    teardown(id: id, reason: reason)
  }

  func dismissAll(reason: String) -> [String] {
    let ids = toasts.map(\.id)
    for id in ids { teardown(id: id, reason: reason) }
    return ids
  }

  /// Hot-restart flush: drop everything silently (the old Dart sink is dead).
  func flushAll() {
    scheduler.removeAll()
    imageGeneration.removeAll()
    stackGeneration += 1
    withAnimation(.none) { toasts.removeAll() }
    frames.removeAll()
  }

  // MARK: - Interaction (called from the SwiftUI layer)

  func handleAction(id: String) {
    guard let index = toasts.firstIndex(where: { $0.id == id }),
          let action = toasts[index].action else { return }
    emitAction(id: id, actionId: action.actionId)
    if action.loadingOnPress {
      // Async action: show the spinner and keep the toast up while the Dart
      // `onPressed` future runs; the facade dismisses it on completion. Disarm
      // auto-dismiss so the timer can't fire mid-task.
      toasts[index].isActionBusy = true
      scheduler.disarm(id: id)
      return
    }
    if action.dismissOnPress { teardown(id: id, reason: "action") }
  }

  func handleBodyTap(id: String) {
    guard let model = toasts.first(where: { $0.id == id }) else { return }
    if model.hasTap { emitTapped(id: id) }
    if model.tapToDismiss { teardown(id: id, reason: "tap") }
  }

  func handleSwipe(id: String) {
    teardown(id: id, reason: "swipe")
  }

  /// Pauses a toast's auto-dismiss while the user is touching it. No-op for
  /// persistent / loading toasts (they have no deadline).
  func pauseAutoDismiss(id: String) {
    guard toasts.contains(where: { $0.id == id }) else { return }
    scheduler.pause(id: id)
  }

  /// Clears a `loadingOnPress` action's spinner and re-arms the toast's
  /// auto-dismiss without removing it — for an async action whose `onPressed`
  /// finished but `dismissOnPress` is false (the toast stays, button idle again).
  func finishAction(id: String) {
    guard let index = toasts.firstIndex(where: { $0.id == id }),
          toasts[index].isActionBusy else { return }
    toasts[index].isActionBusy = false
    scheduler.arm(id: id, duration: toasts[index].autoDuration)
  }

  /// Resumes a paused toast's auto-dismiss with its banked remaining time.
  func resumeAutoDismiss(id: String) {
    guard toasts.contains(where: { $0.id == id }) else { return }
    scheduler.resume(id: id)
  }

  // MARK: - App lifecycle

  func appDidEnterBackground() { scheduler.appDidEnterBackground() }
  func appWillEnterForeground() { scheduler.appWillEnterForeground() }

  // MARK: - Teardown (exactly once)

  @discardableResult
  private func teardown(id: String, reason: String) -> Bool {
    guard let index = toasts.firstIndex(where: { $0.id == id }) else { return false }
    scheduler.disarm(id: id)
    imageGeneration[id] = nil
    stackGeneration += 1
    withAnimation(stackSpring) { _ = toasts.remove(at: index) }
    frames[id] = nil
    emitDismissed(id, reason: reason)
    return true
  }

  // MARK: - Async image decode

  /// Decodes image bytes off the main thread and attaches the pixels to the
  /// (still-live, still-current) toast. The reserved slot (`expectsImage`)
  /// keeps the layout stable while this runs; on decode failure the slot is
  /// collapsed instead of leaving a permanent gap.
  private func decodeImageIfNeeded(id: String, data: Data?) {
    guard let data else { return }
    let generation = (imageGeneration[id] ?? 0) + 1
    imageGeneration[id] = generation
    Task.detached(priority: .userInitiated) {
      let image = await ToastImageDecoder.decode(data)
      await MainActor.run { [weak self] in
        self?.attachImage(id: id, generation: generation, image: image)
      }
    }
  }

  private func attachImage(id: String, generation: Int, image: UIImage?) {
    guard imageGeneration[id] == generation,
          let index = toasts.firstIndex(where: { $0.id == id }) else { return }
    if let image {
      // Plain assignment: the id set is unchanged (stackGeneration untouched),
      // so no container animation fires — the pixels just appear in the
      // already-reserved slot.
      toasts[index].image = ToastImage(uiImage: image)
    } else {
      // Undecodable bytes: collapse the reserved slot. The width probe reacts
      // and the row animates to its narrower layout via the usual width morph.
      toasts[index].expectsImage = false
    }
  }

  /// Keeps at most `maxVisible` toasts per position, dismissing the oldest
  /// (which sits at the tail of the list) so it fades/blurs out in place.
  private func enforcePositionLimit(_ position: ToastPositionModel) {
    let inPosition = toasts.filter { $0.position == position }
    let overflow = inPosition.count - maxVisible
    guard overflow > 0 else { return }
    let victims = dropOldest
      ? Array(inPosition.prefix(overflow)) // oldest first
      : Array(inPosition.suffix(overflow))
    for victim in victims {
      teardown(id: victim.id, reason: "replaced")
    }
  }

  // MARK: - Events / haptics

  private func emitShown(_ model: ToastModel) {
    let index = toasts.firstIndex(where: { $0.id == model.id }) ?? 0
    onEvent?(["event": "shown", "id": model.id, "stackIndex": index, "tsMs": nowMs()])
  }

  private func emitDismissed(_ id: String, reason: String) {
    onEvent?(["event": "dismissed", "id": id, "reason": reason, "tsMs": nowMs()])
  }

  private func emitAction(id: String, actionId: String) {
    onEvent?(["event": "actionTapped", "id": id, "actionId": actionId, "tsMs": nowMs()])
  }

  private func emitTapped(id: String) {
    onEvent?(["event": "tapped", "id": id, "tsMs": nowMs()])
  }

  private func nowMs() -> Int { Int(Date().timeIntervalSince1970 * 1000) }

  private func fireHaptic(_ model: ToastModel) {
    switch model.haptic {
    case .none: break
    case .success: Haptics.notify(.success)
    case .warning: Haptics.notify(.warning)
    case .error: Haptics.notify(.error)
    case .selection: Haptics.selection()
    }
  }
}
