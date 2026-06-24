import SwiftUI

/// Reports each toast's window-space frame up to the manager, so the overlay
/// host can hit-test for pass-through.
struct ToastFramePreferenceKey: PreferenceKey {
  static var defaultValue: [String: CGRect] = [:]
  static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
    value.merge(nextValue()) { _, new in new }
  }
}

/// Root SwiftUI view hosted in the overlay. Each position is an independent
/// **vertical list**: top positions grow downward (newest on top, pushing older
/// ones down); bottom positions grow upward (newest at the bottom). Toasts that
/// fall out of the list scale + fade + blur away in place. Respects Reduce
/// Motion. Top-center toasts on a Dynamic Island device reveal from the pill.
struct ToastContainerView: View {
  @ObservedObject var manager: ToastManager
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Toasts grouped by position, preserving insertion order — each position is
  /// its own independent list so a bottom toast never disturbs the top list.
  private var groups: [(position: ToastPositionModel, toasts: [ToastModel])] {
    var order: [ToastPositionModel] = []
    var map: [ToastPositionModel: [ToastModel]] = [:]
    for toast in manager.toasts {
      if map[toast.position] == nil { order.append(toast.position) }
      map[toast.position, default: []].append(toast)
    }
    return order.map { (position: $0, toasts: map[$0]!) }
  }

  var body: some View {
    // No .ignoresSafeArea(): the host view is pinned full-screen, so SwiftUI's
    // safe area places top toasts just below the Dynamic Island and bottom
    // toasts above the home indicator automatically.
    ZStack {
      Color.clear
      ForEach(groups, id: \.position) { group in
        positionedList(position: group.position, toasts: group.toasts)
      }
    }
    .animation(motion, value: manager.toasts.map(\.id))
    .onPreferenceChange(ToastFramePreferenceKey.self) { frames in
      manager.frames = frames
    }
  }

  @ViewBuilder
  private func positionedList(position: ToastPositionModel, toasts: [ToastModel]) -> some View {
    // Top lists show newest first (on top); bottom lists show newest last.
    let ordered = position.isBottom ? toasts : toasts.reversed()
    VStack(alignment: position.horizontalAlignment, spacing: 10) {
      ForEach(ordered, id: \.id) { toast in
        ToastView(
          toast: toast,
          onTapBody: { manager.handleBodyTap(id: toast.id) },
          onAction: { manager.handleAction(id: toast.id) },
          onSwipe: { manager.handleSwipe(id: toast.id) }
        )
        .background(
          GeometryReader { geo in
            Color.clear.preference(
              key: ToastFramePreferenceKey.self,
              value: [toast.id: geo.frame(in: .global)]
            )
          }
        )
        .transition(transition(for: toast))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
    .padding(.top, 8)
    .padding(.bottom, 8)
    .padding(.horizontal, 12)
  }

  private var motion: Animation? {
    reduceMotion
      ? .easeInOut(duration: 0.2)
      : .spring(response: 0.42, dampingFraction: 0.82)
  }

  private func transition(for toast: ToastModel) -> AnyTransition {
    if reduceMotion { return .opacity }
    let insertion: AnyTransition =
      (toast.isIslandInsertion && toast.position == .topCenter && manager.hasDynamicIsland)
        ? .islandReveal
        : .materialize(top: toast.position.isTop)
    return .asymmetric(insertion: insertion, removal: .fadeBlurOut)
  }
}

// MARK: - Transitions

extension AnyTransition {
  /// Entrance: a small drop-in from the anchored edge with a soft blur.
  static func materialize(top: Bool) -> AnyTransition {
    .modifier(
      active: MaterializeModifier(y: top ? -18 : 18, scale: 0.94, opacity: 0, blur: 6),
      identity: MaterializeModifier(y: 0, scale: 1, opacity: 1, blur: 0)
    )
  }

  /// Exit: scale + fade + blur away **in place** (no offset) — used both for a
  /// dismissed toast and for one pushed out of the list.
  static var fadeBlurOut: AnyTransition {
    .modifier(
      active: MaterializeModifier(y: 0, scale: 0.86, opacity: 0, blur: 9),
      identity: MaterializeModifier(y: 0, scale: 1, opacity: 1, blur: 0)
    )
  }

  static var islandReveal: AnyTransition {
    .modifier(
      active: IslandRevealModifier(progress: 0),
      identity: IslandRevealModifier(progress: 1)
    )
  }
}

private struct MaterializeModifier: ViewModifier {
  let y: CGFloat
  let scale: CGFloat
  let opacity: Double
  let blur: CGFloat
  func body(content: Content) -> some View {
    content
      .opacity(opacity)
      .scaleEffect(scale)
      .offset(y: y)
      .blur(radius: blur)
  }
}

/// "Extruded from the pill" reveal: the toast is born collapsed and narrow at
/// the island's bottom edge, then springs down to full size.
private struct IslandRevealModifier: ViewModifier, Animatable {
  var progress: Double
  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }
  func body(content: Content) -> some View {
    content
      .scaleEffect(x: 0.35 + 0.65 * progress, y: 0.12 + 0.88 * progress, anchor: .top)
      .offset(y: -22 * (1 - progress))
      .opacity(progress)
      .blur(radius: 8 * (1 - progress))
  }
}
