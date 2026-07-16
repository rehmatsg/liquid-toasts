import SwiftUI
import UIKit

/// Screen-edge insets in logical points. The effective safe area is the
/// edge-wise maximum of the device geometry and the app-provided minimum.
struct ToastSafeAreaInsets: Equatable {
  var top: CGFloat = 0
  var left: CGFloat = 0
  var bottom: CGFloat = 0
  var right: CGFloat = 0

  init(top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0) {
    self.top = max(0, top)
    self.left = max(0, left)
    self.bottom = max(0, bottom)
    self.right = max(0, right)
  }

  init(_ insets: UIEdgeInsets) {
    self.init(top: insets.top, left: insets.left, bottom: insets.bottom, right: insets.right)
  }

  func union(_ other: Self) -> Self {
    Self(
      top: max(top, other.top),
      left: max(left, other.left),
      bottom: max(bottom, other.bottom),
      right: max(right, other.right)
    )
  }

  /// Extra padding SwiftUI needs beyond the system safe area it applies
  /// automatically to the root hosting view.
  func excess(over device: Self) -> Self {
    Self(
      top: max(0, top - device.top),
      left: max(0, left - device.left),
      bottom: max(0, bottom - device.bottom),
      right: max(0, right - device.right)
    )
  }
}

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

  /// Device safe-area geometry plus the app-provided minimum. The host/config
  /// paths write only on change so unrelated toasts are not re-rendered.
  @Published private(set) var deviceSafeArea = ToastSafeAreaInsets()
  @Published var customSafeArea = ToastSafeAreaInsets()

  var effectiveSafeArea: ToastSafeAreaInsets {
    deviceSafeArea.union(customSafeArea)
  }

  var customSafeAreaPadding: ToastSafeAreaInsets {
    effectiveSafeArea.excess(over: deviceSafeArea)
  }

  func updateDeviceSafeArea(_ insets: UIEdgeInsets) {
    let next = ToastSafeAreaInsets(insets)
    if deviceSafeArea != next { deviceSafeArea = next }
  }

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
      let existing = toasts[index]
      let oldId = existing.id
      scheduler.disarm(id: oldId)
      frames[oldId] = nil
      imageGeneration[oldId] = nil
      var incoming = model
      if imageData != nil, let preserved = existing.image {
        // Keep the old avatar up until the fresh decode lands (no blank flash).
        incoming.image = preserved
      }
      // Re-show of a group whose text is unchanged: shake the existing toast in
      // place instead of exit+enter. Keeping the old view identity is what avoids
      // the re-entrance; adopting the incoming id keeps the newest handle in
      // control of the (same) toast, exactly like a content morph.
      let textUnchanged = existing.title == incoming.title && existing.message == incoming.message
      if textUnchanged {
        incoming.identity = existing.identity
        incoming.shakeToken = existing.shakeToken &+ 1
        // No stackGeneration bump: the identity set is unchanged, so nothing
        // structural animates — only the row's one-shot shake plays.
        toasts[index] = incoming
      } else {
        stackGeneration += 1
        withAnimation(stackSpring) { toasts[index] = incoming }
      }
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
    enforcePositionLimit(model.position, incomingId: model.id)
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

  /// Keeps at most `maxVisible` toasts per position, dismissing the oldest so
  /// it fades/blurs out in place.
  ///
  /// Only **auto-dismiss** toasts are eligible: a persistent or loading toast
  /// has no deadline (`autoDuration == nil`) and is caller-/promise-owned, so
  /// it is never force-dismissed by overflow. When a position fills with such
  /// toasts the stack is allowed to **exceed** `maxVisible` (a soft cap) rather
  /// than reap one the caller is still managing. The just-presented
  /// `incomingId` is likewise never evicted under `dropOldest` — it was
  /// explicitly requested now, so it shows even if that means a soft overflow.
  private func enforcePositionLimit(_ position: ToastPositionModel, incomingId: String) {
    let inPosition = toasts.filter { $0.position == position }
    let overflow = inPosition.count - maxVisible
    guard overflow > 0 else { return }
    // Persistent / loading toasts (no deadline) are exempt from eviction.
    let evictable = inPosition.filter { $0.autoDuration != nil }
    let victims = dropOldest
      ? Array(evictable.filter { $0.id != incomingId }.prefix(overflow)) // oldest first, keep incoming
      : Array(evictable.suffix(overflow)) // newest — rejects the incoming transient
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
