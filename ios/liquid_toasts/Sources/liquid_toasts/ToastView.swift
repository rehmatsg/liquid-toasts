import SwiftUI
import UIKit

/// A single toast: icon · (title + message + optional progress) · optional
/// action, on an adaptive glass surface, with swipe- and tap-to-dismiss.
struct ToastView: View {
  let toast: ToastModel
  /// Width of the overlay host (device width); drives the multiline width.
  let deviceWidth: CGFloat
  /// True while the action's async `onPressed` runs — the button shows a spinner.
  let isActionLoading: Bool
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
  /// notification) rather than edge-to-edge. Capped so it never stretches
  /// unwieldily wide on large screens (iPad / landscape).
  private var multilineWidth: CGFloat {
    ToastMetrics.multilineWidth(deviceWidth: deviceWidth)
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
    // One shape type for every state (so the frame can animate across the
    // multiline boundary without the shape snapping). The radius keys off width:
    // at the full multiline width use 22; narrower (a hugging single-line toast)
    // use a large radius that `RoundedRectangle` clamps to a capsule.
    let radius = toast.style?.cornerRadius
      ?? (isMultiline ? ToastMetrics.multilineCornerRadius : ToastMetrics.capsuleCornerRadius)
    return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
  }

  private var foreground: Color {
    toast.style?.foreground?.resolved(scheme) ?? .primary
  }

  /// Row insets & spacing — shared with the off-screen probes via ToastMetrics
  /// so the wrap/width decisions can never drift from the live layout.
  private var leadingPadding: CGFloat { ToastMetrics.leadingPadding(multiline: isMultiline) }
  private var verticalPadding: CGFloat { ToastMetrics.verticalPadding(multiline: isMultiline) }
  private var trailingPadding: CGFloat {
    ToastMetrics.trailingPadding(multiline: isMultiline, hasAction: toast.action != nil)
  }
  private var rowSpacing: CGFloat { ToastMetrics.rowSpacing(multiline: isMultiline) }

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

  /// A leading raster image (avatar / thumbnail) takes the leading slot.
  private var showsImage: Bool { toast.image != nil }

  /// Whether anything occupies the leading slot (image / ring / spinner / icon).
  private var showsLeading: Bool { showsImage || showsCircularProgress || showsIcon }

  /// Accent for the progress ring / bar: the icon-color override, then the tint,
  /// then the semantic color (falling back to the accent for `.none`).
  private var accentTint: Color {
    if let c = toast.style?.iconColor?.resolved(scheme) { return c }
    if let c = toast.style?.tint?.resolved(scheme) { return c }
    return toast.semantic == .none ? .accentColor : toast.semantic.tint
  }

  /// Center the text on a compact, text-only toast: no leading glyph, no
  /// trailing action, and not the full-width multiline layout.
  private var centerText: Bool {
    !showsLeading && toast.action == nil && !isMultiline
  }

  private var content: some View {
    // Icon and action stay vertically centered against the (possibly tall)
    // text column.
    HStack(alignment: .center, spacing: rowSpacing) {
      if let image = toast.image {
        AvatarView(image: image)
      } else if showsCircularProgress {
        CircularProgressView(value: toast.progress ?? 0, tint: accentTint)
      } else if showsIcon {
        IconView(toast: toast)
      }

      VStack(alignment: centerText ? .center : .leading, spacing: 2) {
        if let title = toast.title, !title.isEmpty {
          Text(title)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(foreground)
            .multilineTextAlignment(centerText ? .center : .leading)
            .lineLimit(toast.titleMaxLines)
            .fixedSize(horizontal: false, vertical: true)
        }
        if !toast.message.isEmpty {
          Text(toast.message)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(toast.title == nil ? foreground : foreground.opacity(0.85))
            .multilineTextAlignment(centerText ? .center : .leading)
            .lineLimit(toast.maxLines)
            .fixedSize(horizontal: false, vertical: true)
        }

        if let progress = toast.progress, toast.progressStyle == .linear {
          ProgressView(value: max(0, min(1, progress)))
            .progressViewStyle(.linear)
            .tint(accentTint)
            // Fills the text column when multiline; fixed on a hugging capsule.
            .frame(maxWidth: isMultiline ? .infinity : ToastMetrics.linearProgressWidth)
            .padding(.top, 4)
        }
      }
      // Single-line caps the text column so the capsule never spans the screen;
      // multiline fills the fixed-width rounded rect.
      .frame(
        maxWidth: isMultiline ? .infinity : ToastMetrics.textColumnMaxWidth,
        alignment: centerText ? .center : .leading)

      if let action = toast.action {
        ActionButton(action: action, isLoading: isActionLoading, onTap: onAction)
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
      .onPreferenceChange(NaturalWidthKey.self) { w in
        // Animate single-line width changes too, so a capsule -> capsule morph
        // (e.g. "Downloading season 2" -> "Download complete") grows/shrinks
        // smoothly. First measurement applies instantly.
        if naturalWidth == 0 {
          naturalWidth = w
        } else if w != naturalWidth {
          withAnimation(ToastMetrics.stackSpring) { naturalWidth = w }
        }
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
    let leading = ToastMetrics.leadingPadding(multiline: true)
    let trailing = ToastMetrics.trailingPadding(multiline: true, hasAction: toast.action != nil)
    let spacing = ToastMetrics.rowSpacing(multiline: true)
    let glyph: CGFloat = showsLeading ? ToastMetrics.iconSlot + spacing : 0
    // Subtract the action button (measured; estimate until first layout) + spacing.
    let act: CGFloat = toast.action != nil
      ? (actionWidth > 0 ? actionWidth : ToastMetrics.actionWidthEstimate) + spacing
      : 0
    let reference = max(
      ToastMetrics.probeMinReferenceWidth,
      multilineWidth - leading - trailing - glyph - act)
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
          withAnimation(ToastMetrics.stackSpring) {
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
    HStack(spacing: ToastMetrics.rowSpacing(multiline: false)) {
      if showsLeading {
        Color.clear.frame(width: ToastMetrics.iconSlot, height: ToastMetrics.iconSlot)
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
      .frame(maxWidth: ToastMetrics.textColumnMaxWidth, alignment: .leading)
      if toast.action != nil {
        Color.clear.frame(width: max(1, actionWidth), height: 1)
      }
    }
    .padding(.leading, ToastMetrics.leadingPadding(multiline: false))
    .padding(.trailing,
             ToastMetrics.trailingPadding(multiline: false, hasAction: toast.action != nil))
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
    DragGesture(minimumDistance: ToastMetrics.dragMinDistance)
      .onChanged { value in
        if !isDragging {
          isDragging = true
          Haptics.impact(.light) // drag begins
        }
        let dy = value.translation.height
        let towardEdge = toast.position.isBottom ? dy > 0 : dy < 0
        // Rubber-band drags away from the dismiss edge.
        dragOffset = towardEdge ? dy : dy * ToastMetrics.rubberBandFactor
      }
      .onEnded { value in
        isDragging = false
        let dy = value.translation.height
        // Velocity-aware: a quick flick dismisses even if the finger barely moved.
        let predicted = value.predictedEndTranslation.height
        let towardEdge = toast.position.isBottom ? dy > 0 : dy < 0
        let flick = toast.position.isBottom
          ? predicted > ToastMetrics.flickDistance
          : predicted < -ToastMetrics.flickDistance
        if towardEdge && (abs(dy) > ToastMetrics.dragCommitDistance || flick) {
          Haptics.impact(.medium) // commit
          onSwipe()
        } else {
          withAnimation(ToastMetrics.settleSpring) {
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
    .frame(width: ToastMetrics.progressRingSize, height: ToastMetrics.progressRingSize)
  }
}

// MARK: - Avatar

/// A circular avatar / thumbnail in the leading slot — a raster image passed
/// from Dart (any `ImageProvider`, resolved to bytes), in place of the SF Symbol.
struct AvatarView: View {
  let image: UIImage

  var body: some View {
    Image(uiImage: image)
      .resizable()
      .scaledToFill()
      .frame(width: ToastMetrics.avatarSize, height: ToastMetrics.avatarSize)
      .clipShape(Circle())
      .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
  }
}
