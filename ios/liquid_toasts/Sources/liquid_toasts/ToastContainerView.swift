import SwiftUI

/// Reports each interactive toast's window-space frame up to the manager, so the
/// overlay host can hit-test for pass-through.
struct ToastFramePreferenceKey: PreferenceKey {
  static var defaultValue: [String: CGRect] = [:]
  static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
    value.merge(nextValue()) { _, new in new }
  }
}

/// Root SwiftUI view hosted in the overlay. Lays the queue out as a depth stack
/// (front fully visible; ones behind peek out, scaled + dimmed), drives the
/// entrance/exit transitions (Dynamic Island reveal for top-center, slide-in
/// otherwise), and respects Reduce Motion.
struct ToastContainerView: View {
  @ObservedObject var manager: ToastManager
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Toasts grouped by position, preserving insertion order — each position is
  /// its own independent stack so a bottom toast never disturbs the top stack.
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
        positionedStack(position: group.position, toasts: group.toasts)
      }
    }
    .animation(motion, value: manager.toasts.map(\.id))
    .onPreferenceChange(ToastFramePreferenceKey.self) { frames in
      manager.frames = frames
    }
  }

  @ViewBuilder
  private func positionedStack(position: ToastPositionModel, toasts: [ToastModel]) -> some View {
    // Peeking cards adopt the front card's measured width so the stack reads as
    // uniform cards even though each toast hugs its own content when frontmost.
    let frontWidth = toasts.last.flatMap { manager.frames[$0.id]?.width }
    ZStack(alignment: position.alignment) {
      ForEach(Array(toasts.enumerated()), id: \.element.id) { index, toast in
        let depth = (toasts.count - 1) - index
        layer(toast: toast, depth: depth, index: index, frontWidth: frontWidth)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
    .padding(.top, 8)
    .padding(.bottom, 8)
    .padding(.horizontal, 12)
  }

  @ViewBuilder
  private func layer(toast: ToastModel, depth: Int, index: Int, frontWidth: CGFloat?) -> some View {
    let isFront = depth == 0
    let capped = min(depth, manager.maxVisible)
    let scale = 1 - 0.05 * CGFloat(capped)
    let opacity: Double = depth == 0
      ? 1
      : (depth > manager.maxVisible ? 0 : 1 - 0.2 * Double(capped))
    let offset = stackOffsetY(depth: capped, isTop: toast.position.isTop)

    ToastView(
      toast: toast,
      width: isFront ? nil : frontWidth,
      onTapBody: { manager.handleBodyTap(id: toast.id) },
      onAction: { manager.handleAction(id: toast.id) },
      onSwipe: { manager.handleSwipe(id: toast.id) }
    )
    .allowsHitTesting(isFront)
    .background(
      GeometryReader { geo in
        Color.clear.preference(
          key: ToastFramePreferenceKey.self,
          value: isFront ? [toast.id: geo.frame(in: .global)] : [:]
        )
      }
    )
    .scaleEffect(scale, anchor: toast.position.isTop ? .top : .bottom)
    .offset(y: offset)
    .opacity(opacity)
    .zIndex(Double(index))
    .accessibilityHidden(!isFront)
    .transition(transition(for: toast))
  }

  private func stackOffsetY(depth: Int, isTop: Bool) -> CGFloat {
    let magnitude = 13 * CGFloat(depth)
    return isTop ? magnitude : -magnitude
  }

  private var motion: Animation? {
    reduceMotion
      ? .easeInOut(duration: 0.2)
      : .spring(response: 0.42, dampingFraction: 0.82)
  }

  private func transition(for toast: ToastModel) -> AnyTransition {
    if reduceMotion { return .opacity }
    if toast.isIslandInsertion && toast.position == .topCenter && manager.hasDynamicIsland {
      return .asymmetric(insertion: .islandReveal, removal: .stackEdge(top: true))
    }
    return .stackEdge(top: toast.position.isTop)
  }
}

// MARK: - Transitions

extension AnyTransition {
  static func stackEdge(top: Bool) -> AnyTransition {
    .modifier(
      active: StackEdgeModifier(y: top ? -90 : 90, scale: 0.85, opacity: 0),
      identity: StackEdgeModifier(y: 0, scale: 1, opacity: 1)
    )
  }

  static var islandReveal: AnyTransition {
    .modifier(
      active: IslandRevealModifier(progress: 0),
      identity: IslandRevealModifier(progress: 1)
    )
  }
}

private struct StackEdgeModifier: ViewModifier {
  let y: CGFloat
  let scale: CGFloat
  let opacity: Double
  func body(content: Content) -> some View {
    content.opacity(opacity).scaleEffect(scale).offset(y: y)
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
