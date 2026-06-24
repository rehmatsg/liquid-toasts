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
    if let radius = toast.style?.cornerRadius {
      return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
    // Multi-line toasts read better as a rounded rect than a tall capsule.
    if toast.maxLines > 1 || (toast.title?.isEmpty == false) {
      return AnyShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    return AnyShape(Capsule())
  }

  private var foreground: Color {
    toast.style?.foreground?.resolved(scheme) ?? .primary
  }

  var body: some View {
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
            .frame(width: 180)
            .padding(.top, 3)
        }
      }
      // Hug short content; cap (and wrap) long text so the pill stays compact.
      .frame(maxWidth: 250, alignment: .leading)

      if let action = toast.action {
        ActionButton(action: action, onTap: onAction)
          .padding(.leading, 2)
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 13)
    .frame(maxWidth: 360)
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
