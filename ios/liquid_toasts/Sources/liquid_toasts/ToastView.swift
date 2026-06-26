import SwiftUI
import UIKit

/// A single toast: icon · (title + message + optional progress) · optional
/// action, on an adaptive glass surface, with swipe- and tap-to-dismiss.
struct ToastView: View {
  let toast: ToastModel
  /// Width of the overlay host (device width); drives the multiline width.
  let deviceWidth: CGFloat
  let onTapBody: () -> Void
  let onAction: () -> Void
  let onSwipe: () -> Void

  @Environment(\.colorScheme) private var scheme
  @State private var dragOffset: CGFloat = 0
  @State private var isDragging = false
  /// True once the message wraps onto more than one line — measured off-screen.
  /// Multiline toasts trade the hugging capsule for a wider, left-aligned
  /// rounded rectangle.
  @State private var isMultiline = false

  /// Width of a multiline toast: the full device width minus a comfortable
  /// horizontal margin on each side, so it reads clearly inset (like an iOS
  /// notification) rather than edge-to-edge. Capped at `multilineMaxWidth` so it
  /// never stretches unwieldily wide on large screens (iPad / landscape) — and
  /// is never the full device width.
  private var multilineSideMargin: CGFloat { 20 }
  private var multilineMaxWidth: CGFloat { 440 }
  private var multilineWidth: CGFloat {
    min(multilineMaxWidth, deviceWidth - multilineSideMargin * 2)
  }

  private var shape: AnyShape {
    // An explicit cornerRadius always wins. Otherwise multiline toasts use a
    // rounded rectangle (22) and single-line toasts stay a capsule.
    if let radius = toast.style?.cornerRadius {
      return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
    if isMultiline {
      return AnyShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    return AnyShape(Capsule(style: .continuous))
  }

  private var foreground: Color {
    toast.style?.foreground?.resolved(scheme) ?? .primary
  }

  /// Leading inset — roomier when multiline so text breathes off the icon.
  private var leadingPadding: CGFloat { isMultiline ? 18 : 16 }

  /// Vertical inset — taller when multiline so the rounded rect isn't cramped.
  private var verticalPadding: CGFloat { isMultiline ? 14 : 11 }

  /// Trailing inset. With an action present it matches the (tighter) button
  /// margin; otherwise it mirrors the leading inset.
  private var trailingPadding: CGFloat { toast.action == nil ? leadingPadding : 11 }

  /// Spacing between the icon, the text column, and the action — widened in
  /// multiline layouts.
  private var rowSpacing: CGFloat { isMultiline ? 14 : 12 }

  /// Whether a leading glyph (spinner or SF Symbol) will render. When false the
  /// icon is dropped from the row entirely — slot and spacing — so a text-only
  /// toast hugs its leading padding instead of reserving an empty icon box.
  private var showsIcon: Bool {
    toast.state == .loading || toast.resolvedSymbol != nil
  }

  private var content: some View {
    // Icon and action stay vertically centered against the (possibly tall)
    // text column.
    HStack(alignment: .center, spacing: rowSpacing) {
      if showsIcon {
        IconView(toast: toast)
      }

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
          .multilineTextAlignment(.leading)
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
      // Single-line caps the text column so the capsule never spans the screen;
      // multiline fills the fixed-width rounded rect.
      .frame(maxWidth: isMultiline ? .infinity : 260, alignment: .leading)

      if let action = toast.action {
        ActionButton(action: action, onTap: onAction)
      }
    }
    .padding(.leading, leadingPadding)
    .padding(.trailing, trailingPadding)
    .padding(.vertical, verticalPadding)
  }

  var body: some View {
    content
      // Multiline pins to the (capped) near-full width; single-line hugs content.
      .modifier(ToastWidthModifier(width: isMultiline ? multilineWidth : nil))
      .background { GlassBackground(shape: shape) }
      .overlay(shape.stroke(Color.white.opacity(scheme == .dark ? 0.08 : 0.0), lineWidth: 0.5))
      .contentShape(shape)
      .background(multilineProbe)
      .offset(y: dragOffset)
      .highPriorityGesture(dragGesture)
      .onTapGesture {
        Haptics.impact(.light)
        onTapBody()
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(toast.accessibilityText)
      .accessibilityAddTraits(.isStaticText)
  }

  /// Off-screen measurement of the message at the width it would occupy in a
  /// multiline layout. If it needs more than one line there, the toast commits
  /// to the multiline treatment. Measuring at a *fixed* reference width (not the
  /// live layout width) keeps the decision stable — it can't oscillate as the
  /// layout flips between capsule and rounded rect.
  private var multilineProbe: some View {
    // Reference width = the text column in the *multiline* layout (fixed insets,
    // independent of `isMultiline`) so the measurement can't feed back into
    // itself and oscillate.
    let reference = max(160, multilineWidth - 18 - 18 - (showsIcon ? 22 + 14 : 0))
    return Text(toast.message)
      .font(.system(.subheadline, design: .rounded))
      .lineLimit(toast.maxLines)
      .fixedSize(horizontal: false, vertical: true)
      .frame(width: reference, alignment: .leading)
      .background(
        GeometryReader { geo in
          Color.clear.preference(key: MessageHeightKey.self, value: geo.size.height)
        }
      )
      .hidden()
      .onPreferenceChange(MessageHeightKey.self) { height in
        let lineHeight = UIFont.preferredFont(forTextStyle: .subheadline).lineHeight
        isMultiline = deviceWidth > 0 && height > lineHeight * 1.5
      }
  }

  // MARK: - Drag

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 6)
      .onChanged { value in
        if !isDragging {
          isDragging = true
          Haptics.impact(.light) // drag begins
        }
        let dy = value.translation.height
        let towardEdge = toast.position.isBottom ? dy > 0 : dy < 0
        dragOffset = towardEdge ? dy : dy * 0.35 // rubber-band the wrong way
      }
      .onEnded { value in
        isDragging = false
        let dy = value.translation.height
        // Velocity-aware: a quick flick dismisses even if the finger barely moved.
        let predicted = value.predictedEndTranslation.height
        let towardEdge = toast.position.isBottom ? dy > 0 : dy < 0
        let flick = toast.position.isBottom ? predicted > 140 : predicted < -140
        if towardEdge && (abs(dy) > 28 || flick) {
          Haptics.impact(.medium) // commit
          onSwipe()
        } else {
          withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            dragOffset = 0
          }
        }
      }
  }
}

// MARK: - Width

/// Applies a fixed width for multiline toasts, or hugs content (single-line).
/// A plain conditional `.frame`/`.fixedSize` can't be expressed inline because
/// the two branches return different layouts, so it lives in a modifier.
private struct ToastWidthModifier: ViewModifier {
  let width: CGFloat?

  func body(content: Content) -> some View {
    if let width {
      content.frame(width: width)
    } else {
      content.fixedSize(horizontal: true, vertical: false)
    }
  }
}

// MARK: - Measurement

/// Carries the rendered height of the off-screen message probe up to `ToastView`
/// so it can decide whether the message wraps past a single line.
private struct MessageHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}
