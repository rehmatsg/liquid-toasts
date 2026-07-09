import SwiftUI

/// Adaptive glass surface for a toast.
///
/// - iOS 26+: native Liquid Glass via `glassEffect`. By default the surface
///   stays **neutral** (a subtle dark/light tint for notification legibility)
///   so it refracts the app cleanly. A caller-supplied `surfaceTint`
///   (`ToastStyleOverride.background`) colors the glass instead — a translucent
///   wash over the live refraction.
/// - iOS 17–25: a frosted `.ultraThinMaterial` fallback, tinted by
///   `surfaceTint` when set (else a neutral scheme wash).
/// - Reduce Transparency: an opaque background — filled with `surfaceTint` when
///   set, else neutral.
struct GlassBackground<S: Shape>: View {
  let shape: S
  /// Surface color from `ToastStyleOverride.background`. Nil keeps the neutral
  /// adaptive default on every tier.
  var surfaceTint: Color? = nil

  @Environment(\.colorScheme) private var scheme
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  var body: some View {
    let isDark = scheme == .dark
    if reduceTransparency {
      shape
        .fill(surfaceTint ?? (isDark ? Color(white: 0.14) : Color(white: 0.98)))
        .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(isDark ? 0.4 : 0.14), radius: 14, y: 6)
    } else {
      glass(isDark: isDark)
    }
  }

  @ViewBuilder
  private func glass(isDark: Bool) -> some View {
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) {
      let glassTint = surfaceTint ?? (isDark ? Color.black : Color.white).opacity(0.28)
      shape
        .fill(.clear)
        .glassEffect(.regular.tint(glassTint), in: shape)
        // Explicit shadow: the entrance animates opacity/scale/offset on top of
        // this glass, which forces SwiftUI to rasterize it and suppresses the
        // glass's *system* ambient shadow mid-animation (it dips out, then snaps
        // back on settle). Our own shadow is a normal primitive that fades and
        // scales smoothly with the entrance, so the visible shadow stays
        // continuous instead of flickering.
        .shadow(color: .black.opacity(isDark ? 0.24 : 0.08), radius: 10, y: 4)
    } else {
      frosted(isDark: isDark)
    }
    #else
    frosted(isDark: isDark)
    #endif
  }

  @ViewBuilder
  private func frosted(isDark: Bool) -> some View {
    let wash = surfaceTint ?? (isDark ? Color.black : Color.white).opacity(isDark ? 0.26 : 0.16)
    shape
      .fill(.ultraThinMaterial)
      .overlay(shape.fill(wash))
      .overlay(shape.stroke(Color.white.opacity(isDark ? 0.10 : 0.30), lineWidth: 0.5))
      .shadow(color: .black.opacity(isDark ? 0.35 : 0.12), radius: 16, y: 8)
  }
}
