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
  /// Touch-down / touch-up — used to pause & resume the auto-dismiss timer while
  /// the user is interacting with (reading / holding / dragging) the toast.
  let onPressStart: () -> Void
  let onPressEnd: () -> Void

  @Environment(\.colorScheme) private var scheme
  @State private var dragOffset: CGFloat = 0
  @State private var isDragging = false
  @State private var isPressed = false
  /// Measured width of the action button, fed back into the multiline probe so
  /// the wrap decision accounts for the space the button takes.
  @State private var actionWidth: CGFloat = 0
  /// True when the message wraps onto more than one line — measured off-screen.
  /// Multiline toasts trade the hugging capsule for a wider, left-aligned
  /// rounded rectangle.
  @State private var isMultiline = false
  /// Hugging (single-line) width, measured off-screen. Used as the concrete
  /// frame width in single-line mode so the toast can *animate* between it and
  /// `multilineWidth` when the message crosses the wrap boundary.
  @State private var naturalWidth: CGFloat = 0
  /// Whether the first off-screen measurement has landed. The initial multiline
  /// decision is applied instantly (no entrance wobble); later changes animate.
  @State private var didMeasure = false

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

  /// Concrete frame width: the multiline width when wrapped, else the measured
  /// hugging width. `nil` only before the first measurement, where it falls back
  /// to hugging via `fixedSize` (the natural width ≈ this, so the hand-off when
  /// the measurement lands is invisible).
  private var resolvedWidth: CGFloat? {
    if isMultiline { return multilineWidth }
    return naturalWidth > 0 ? naturalWidth : nil
  }

  private var shape: AnyShape {
    // One shape for both layouts. A `RoundedRectangle` clamps its radius to half
    // the smaller side, so on a short single-line toast (radius 22) it renders
    // as a capsule, while a tall multiline toast keeps the 22pt corner. Using a
    // single shape type (rather than swapping Capsule <-> RoundedRectangle) lets
    // a toast animate its frame across the multiline boundary without snapping.
    let radius = toast.style?.cornerRadius ?? 22
    return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
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

  /// A determinate circular progress ring renders in place of the leading icon.
  private var showsCircularProgress: Bool {
    toast.progress != nil && toast.progressStyle == .circular
  }

  /// Whether anything occupies the leading slot (icon / spinner / progress ring).
  private var showsLeading: Bool { showsCircularProgress || showsIcon }

  /// Accent for the progress ring / bar: the icon-color override, then the tint,
  /// then the semantic color (falling back to the accent for `.none`).
  private var accentTint: Color {
    if let c = toast.style?.iconColor?.resolved(scheme) { return c }
    if let c = toast.style?.tint?.resolved(scheme) { return c }
    return toast.semantic == .none ? .accentColor : toast.semantic.tint
  }

  private var content: some View {
    // Icon and action stay vertically centered against the (possibly tall)
    // text column.
    HStack(alignment: .center, spacing: rowSpacing) {
      if showsCircularProgress {
        CircularProgressView(value: toast.progress ?? 0, tint: accentTint)
      } else if showsIcon {
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

        if let progress = toast.progress, toast.progressStyle == .linear {
          ProgressView(value: max(0, min(1, progress)))
            .progressViewStyle(.linear)
            .tint(accentTint)
            // Fills the text column when multiline; fixed on a hugging capsule.
            .frame(maxWidth: isMultiline ? .infinity : 160)
            .padding(.top, 4)
        }
      }
      // Single-line caps the text column so the capsule never spans the screen;
      // multiline fills the fixed-width rounded rect.
      .frame(maxWidth: isMultiline ? .infinity : 260, alignment: .leading)

      if let action = toast.action {
        ActionButton(action: action, onTap: onAction)
          .background(GeometryReader { g in
            Color.clear.preference(key: ActionWidthKey.self, value: g.size.width)
          })
      }
    }
    .padding(.leading, leadingPadding)
    .padding(.trailing, trailingPadding)
    .padding(.vertical, verticalPadding)
  }

  var body: some View {
    content
      // Multiline pins to the (capped) near-full width; single-line hugs content
      // — both concrete widths so a morph across the boundary animates.
      .modifier(ToastWidthModifier(width: resolvedWidth))
      .background { GlassBackground(shape: shape) }
      .overlay(shape.stroke(Color.white.opacity(scheme == .dark ? 0.08 : 0.0), lineWidth: 0.5))
      .contentShape(shape)
      .background(multilineProbe)
      .background(widthProbe)
      .offset(y: dragOffset)
      .highPriorityGesture(dragGesture)
      .onTapGesture {
        Haptics.impact(.light)
        onTapBody()
      }
      .simultaneousGesture(
        // Touch-down pauses auto-dismiss, lift resumes it. Runs alongside the
        // swipe (highPriority) and tap gestures without consuming them.
        DragGesture(minimumDistance: 0)
          .onChanged { _ in if !isPressed { isPressed = true; onPressStart() } }
          .onEnded { _ in if isPressed { isPressed = false; onPressEnd() } }
      )
      .onPreferenceChange(ActionWidthKey.self) { actionWidth = $0 }
      .onPreferenceChange(NaturalWidthKey.self) { naturalWidth = $0 }
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
    let leading: CGFloat = 18
    let trailing: CGFloat = toast.action == nil ? 18 : 11
    let glyph: CGFloat = showsLeading ? 22 + 14 : 0 // leading slot + row spacing
    // Subtract the action button (measured; estimate until first layout) + spacing.
    let act: CGFloat = toast.action != nil ? (actionWidth > 0 ? actionWidth : 72) + 14 : 0
    let reference = max(120, multilineWidth - leading - trailing - glyph - act)
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
        let multi = deviceWidth > 0 && height > lineHeight * 1.5
        if !didMeasure {
          isMultiline = multi // first measurement: apply instantly (no entrance wobble)
          didMeasure = true
        } else if multi != isMultiline {
          // A morph (e.g. an upload's progress -> "done") crossed the wrap
          // boundary — animate the width + reflow instead of snapping.
          withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            isMultiline = multi
          }
        }
      }
  }

  /// Off-screen measurement of the row at its single-line (hugging) width — the
  /// concrete width single-line mode frames to, so the toast can animate between
  /// it and `multilineWidth` rather than snapping. Mirrors the single-line
  /// layout (16/12 insets, 260pt text cap, icon + action slots).
  private var widthProbe: some View {
    HStack(spacing: 12) {
      if showsLeading {
        Color.clear.frame(width: 22, height: 22)
      }
      VStack(alignment: .leading, spacing: 2) {
        if let title = toast.title, !title.isEmpty {
          Text(title)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .lineLimit(1)
        }
        Text(toast.message)
          .font(.system(.subheadline, design: .rounded))
          .lineLimit(1)
      }
      .frame(maxWidth: 260, alignment: .leading)
      if toast.action != nil {
        Color.clear.frame(width: max(1, actionWidth), height: 1)
      }
    }
    .padding(.leading, 16)
    .padding(.trailing, toast.action == nil ? 16 : 11)
    .fixedSize(horizontal: true, vertical: false)
    .background(
      GeometryReader { geo in
        Color.clear.preference(key: NaturalWidthKey.self, value: geo.size.width)
      }
    )
    .hidden()
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

/// Carries the action button's rendered width up to `ToastView` so the multiline
/// probe can subtract the horizontal space the button occupies.
private struct ActionWidthKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

/// Carries the single-line (hugging) row width up to `ToastView` so single-line
/// mode frames to a concrete width and can animate across the multiline boundary.
private struct NaturalWidthKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}

// MARK: - Circular progress

/// A determinate circular progress ring sized to the leading icon slot — an
/// upload/download-style indicator. (SwiftUI's `.circular` progress style is
/// indeterminate on iOS, so the arc is drawn directly.)
struct CircularProgressView: View {
  let value: Double
  let tint: Color

  var body: some View {
    let clamped = max(0, min(1, value))
    ZStack {
      Circle()
        .stroke(tint.opacity(0.22), lineWidth: 2.6)
      Circle()
        .trim(from: 0, to: clamped)
        .stroke(tint, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        .rotationEffect(.degrees(-90))
        .animation(.easeInOut(duration: 0.25), value: clamped)
    }
    .frame(width: 20, height: 20)
  }
}
