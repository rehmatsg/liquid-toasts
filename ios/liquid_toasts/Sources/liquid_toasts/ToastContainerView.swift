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

  private var frontPosition: ToastPositionModel {
    manager.toasts.last?.position ?? .topCenter
  }

  var body: some View {
    GeometryReader { proxy in
      let insets = proxy.safeAreaInsets
      let hasDI = insets.top >= 51
      ZStack(alignment: frontPosition.alignment) {
        Color.clear
        ForEach(Array(manager.toasts.enumerated()), id: \.element.id) { index, toast in
          let depth = (manager.toasts.count - 1) - index
          layer(toast: toast, depth: depth, index: index, hasDI: hasDI)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frontPosition.alignment)
      .padding(.top, insets.top + 6)
      .padding(.bottom, insets.bottom + 10)
      .padding(.horizontal, 12)
      .animation(motion, value: manager.toasts.map(\.id))
    }
    .ignoresSafeArea()
    .onPreferenceChange(ToastFramePreferenceKey.self) { frames in
      manager.frames = frames
    }
  }

  @ViewBuilder
  private func layer(toast: ToastModel, depth: Int, index: Int, hasDI: Bool) -> some View {
    let isFront = depth == 0
    let capped = min(depth, manager.maxVisible)
    let scale = 1 - 0.06 * CGFloat(capped)
    let opacity: Double = depth == 0
      ? 1
      : (depth > manager.maxVisible ? 0 : 1 - 0.26 * Double(capped))
    let offset = stackOffsetY(depth: capped, isTop: toast.position.isTop)

    ToastView(
      toast: toast,
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
    .transition(transition(for: toast, hasDI: hasDI))
  }

  private func stackOffsetY(depth: Int, isTop: Bool) -> CGFloat {
    let magnitude = 9 * CGFloat(depth)
    return isTop ? magnitude : -magnitude
  }

  private var motion: Animation? {
    reduceMotion
      ? .easeInOut(duration: 0.2)
      : .spring(response: 0.42, dampingFraction: 0.82)
  }

  private func transition(for toast: ToastModel, hasDI: Bool) -> AnyTransition {
    if reduceMotion { return .opacity }
    if toast.isIslandInsertion && toast.position == .topCenter && hasDI {
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
