import SwiftUI

/// Adaptive glass surface for a toast.
///
/// - iOS 26+: native Liquid Glass via `glassEffect`. Per the toast design rule,
///   the surface stays **neutral** (a subtle dark/light tint for notification
///   legibility) so it refracts the app cleanly — the semantic color lives in
///   the icon, not the surface.
/// - iOS 17–25: a frosted `.ultraThinMaterial` fallback with a scheme tint,
///   hairline stroke, and soft shadow.
/// - Reduce Transparency: an opaque background instead of any blur/glass.
struct GlassBackground<S: Shape>: View {
  let shape: S
  var tint: Color? = nil

  @Environment(\.colorScheme) private var scheme
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  var body: some View {
    let isDark = scheme == .dark
    if reduceTransparency {
      shape
        .fill(isDark ? Color(white: 0.14) : Color(white: 0.98))
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
      let glassTint = tint ?? (isDark ? Color.black : Color.white).opacity(0.28)
      shape
        .fill(.clear)
        .glassEffect(.regular.tint(glassTint), in: shape)
    } else {
      frosted(isDark: isDark)
    }
    #else
    frosted(isDark: isDark)
    #endif
  }

  @ViewBuilder
  private func frosted(isDark: Bool) -> some View {
    shape
      .fill(.ultraThinMaterial)
      .overlay(shape.fill((isDark ? Color.black : Color.white).opacity(isDark ? 0.26 : 0.16)))
      .overlay(shape.stroke(Color.white.opacity(isDark ? 0.10 : 0.30), lineWidth: 0.5))
      .shadow(color: .black.opacity(isDark ? 0.35 : 0.12), radius: 16, y: 8)
  }
}
