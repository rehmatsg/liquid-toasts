import SwiftUI
import UIKit

/// The single source of truth for the toast stack. Owns the queue, auto-dismiss
/// timers (wall-clock so backgrounding can't corrupt them), replace-by-groupKey,
/// auto-promote-on-resolve, and exactly-once teardown. Emits lifecycle events
/// back to the plugin via [onEvent].
@MainActor
final class ToastManager: ObservableObject {
  @Published private(set) var toasts: [ToastModel] = []

  /// Frames (window coordinates) of the interactive (front) toasts, fed by the
  /// SwiftUI layer and read by the overlay host's hit-test for pass-through.
  @Published var frames: [String: CGRect] = [:]

  /// Top safe-area inset (set by the overlay host from the window). Drives the
  /// entrance slide distance.
  @Published var topSafeArea: CGFloat = 0

  /// Max toasts shown per position (a vertical list); the oldest is dismissed
  /// when a new toast would exceed this.
  var maxVisible: Int = 5
  var maxQueue: Int = 8
  var dropOldest: Bool = true

  /// Emits a wire-ready event payload to the plugin's event sink.
  var onEvent: (([String: Any]) -> Void)?
  /// Notified when the stack transitions between empty and non-empty.
  var onEmptyChanged: ((Bool) -> Void)?

  private var deadlineTasks: [String: Task<Void, Never>] = [:]
  private var backgrounded = false
  private var wasEmpty = true

  private var stackSpring: Animation { .spring(response: 0.42, dampingFraction: 0.82) }

  // MARK: - Present / update / dismiss

  func present(_ toast: ToastModel) {
    var model = toast

    // Replace-by-groupKey: morph an existing toast instead of stacking a dup.
    if let key = model.groupKey,
       let index = toasts.firstIndex(where: { $0.groupKey == key }) {
      let oldId = toasts[index].id
      cancelDeadline(oldId)
      frames[oldId] = nil
      withAnimation(stackSpring) { toasts[index] = model }
      emitDismissed(oldId, reason: "replaced")
      arm(model)
      fireHaptic(model)
      emitShown(model)
      return
    }

    withAnimation(stackSpring) {
      toasts.append(model)
    }
    enforcePositionLimit(model.position)
    arm(model)
    fireHaptic(model)
    emitShown(model)
    notifyEmpty()
  }

  @discardableResult
  func update(id: String, with toast: ToastModel) -> Bool {
    guard let index = toasts.firstIndex(where: { $0.id == id }) else { return false }
    var updated = toasts[index]
    updated.applyContent(from: toast)
    cancelDeadline(id)
    // Morph in place — the list keeps every toast visible, so there is no need
    // to reorder a resolving toast.
    withAnimation(stackSpring) {
      toasts[index] = updated
    }
    arm(updated)
    fireHaptic(updated)
    return true
  }

  @discardableResult
  func dismiss(id: String, reason: String) -> Bool {
    guard toasts.contains(where: { $0.id == id }) else { return false }
    teardown(id: id, reason: reason)
    return true
  }

  func dismissAll(reason: String) -> [String] {
    let ids = toasts.map(\.id)
    for id in ids { teardown(id: id, reason: reason) }
    return ids
  }

  /// Hot-restart flush: drop everything silently (the old Dart sink is dead).
  func flushAll() {
    for task in deadlineTasks.values { task.cancel() }
    deadlineTasks.removeAll()
    withAnimation(.none) { toasts.removeAll() }
    frames.removeAll()
    notifyEmpty()
  }

  // MARK: - Interaction (called from the SwiftUI layer)

  func handleAction(id: String) {
    guard let model = toasts.first(where: { $0.id == id }), let action = model.action else { return }
    emitAction(id: id, actionId: action.actionId)
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

  // MARK: - App lifecycle

  func appDidEnterBackground() {
    backgrounded = true
    for task in deadlineTasks.values { task.cancel() }
    deadlineTasks.removeAll()
    // Deadlines remain stored on the models (wall-clock).
  }

  func appWillEnterForeground() {
    backgrounded = false
    let now = Date()
    for model in toasts {
      guard let deadline = model.deadline else { continue }
      if deadline <= now {
        teardown(id: model.id, reason: "appBackgrounded")
      } else {
        scheduleTask(for: model.id, fireAt: deadline)
      }
    }
  }

  // MARK: - Teardown (exactly once)

  private func teardown(id: String, reason: String) {
    guard toasts.contains(where: { $0.id == id }) else { return }
    cancelDeadline(id)
    withAnimation(stackSpring) { toasts.removeAll { $0.id == id } }
    frames[id] = nil
    emitDismissed(id, reason: reason)
    notifyEmpty()
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

  // MARK: - Auto-dismiss timers (wall-clock)

  private func arm(_ model: ToastModel) {
    cancelDeadline(model.id)
    guard let duration = model.autoDuration else {
      setDeadline(model.id, nil)
      return
    }
    let deadline = Date().addingTimeInterval(duration)
    setDeadline(model.id, deadline)
    if !backgrounded { scheduleTask(for: model.id, fireAt: deadline) }
  }

  private func setDeadline(_ id: String, _ date: Date?) {
    guard let index = toasts.firstIndex(where: { $0.id == id }) else { return }
    toasts[index].deadline = date
  }

  private func scheduleTask(for id: String, fireAt: Date) {
    deadlineTasks[id]?.cancel()
    deadlineTasks[id] = Task { [weak self] in
      let interval = max(0, fireAt.timeIntervalSinceNow)
      try? await Task.sleep(for: .seconds(interval))
      guard !Task.isCancelled, let self, !self.backgrounded else { return }
      self.teardown(id: id, reason: "timeout")
    }
  }

  private func cancelDeadline(_ id: String) {
    deadlineTasks[id]?.cancel()
    deadlineTasks[id] = nil
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

  private func notifyEmpty() {
    let empty = toasts.isEmpty
    if empty != wasEmpty {
      wasEmpty = empty
      onEmptyChanged?(empty)
    }
  }
}
