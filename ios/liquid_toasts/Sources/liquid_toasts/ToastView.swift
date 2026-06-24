import SwiftUI

/// A single toast: icon · (title + message + optional progress) · optional
/// action, on an adaptive glass surface, with swipe- and tap-to-dismiss.
struct ToastView: View {
  let toast: ToastModel
  let onTapBody: () -> Void
  let onAction: () -> Void
  let onSwipe: () -> Void

  @Environment(\.colorScheme) private var scheme
  @State private var dragOffset: CGFloat = 0

  private var shape: AnyShape {
    // Fully rounded (capsule) by default; a custom cornerRadius opts into a
    // rounded rectangle instead.
    if let radius = toast.style?.cornerRadius {
      return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
    return AnyShape(Capsule(style: .continuous))
  }

  private var foreground: Color {
    toast.style?.foreground?.resolved(scheme) ?? .primary
  }

  /// When an action is present its trailing inset matches the vertical inset so
  /// the button sits with a uniform margin on its top / bottom / right edges.
  private var trailingPadding: CGFloat { toast.action == nil ? 16 : 11 }

  private var content: some View {
    HStack(spacing: 12) {
      IconView(toast: toast)

      VStack(alignment: .leading, spacing: 2) {
        if let title = toast.title, !title.isEmpty {
          Text(title)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(foreground)
            .lineLimit(1)
        }
        Text(toast.message)
          .font(.system(.subheadline, design: .rounded))
          .foregroundStyle(toast.title == nil ? foreground : foreground.opacity(0.85))
          .lineLimit(toast.maxLines)
          .fixedSize(horizontal: false, vertical: true)

        if let progress = toast.progress {
          ProgressView(value: max(0, min(1, progress)))
            .progressViewStyle(.linear)
            .tint(toast.semantic.tint)
            .frame(width: 160)
            .padding(.top, 4)
        }
      }
      // Cap (and wrap) very long text so the pill never spans the screen.
      .frame(maxWidth: 260, alignment: .leading)

      if let action = toast.action {
        ActionButton(action: action, onTap: onAction)
      }
    }
    .padding(.leading, 16)
    .padding(.trailing, trailingPadding)
    .padding(.vertical, 11)
  }

  var body: some View {
    content
      // Hug content to the minimal width the layout needs.
      .fixedSize(horizontal: true, vertical: false)
      .background { GlassBackground(shape: shape) }
      .overlay(shape.stroke(Color.white.opacity(scheme == .dark ? 0.08 : 0.0), lineWidth: 0.5))
      .contentShape(shape)
      .offset(y: dragOffset)
      .highPriorityGesture(dragGesture)
      .onTapGesture { onTapBody() }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(toast.accessibilityText)
      .accessibilityAddTraits(.isStaticText)
  }

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 8)
      .onChanged { value in
        let dy = value.translation.height
        let towardEdge = toast.position.isBottom ? dy > 0 : dy < 0
        dragOffset = towardEdge ? dy : dy * 0.35 // rubber-band the wrong way
      }
      .onEnded { value in
        let dy = value.translation.height
        let towardEdge = toast.position.isBottom ? dy > 0 : dy < 0
        if towardEdge && abs(dy) > 24 {
          onSwipe()
        } else {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            dragOffset = 0
          }
        }
      }
  }
}
