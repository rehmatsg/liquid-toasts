import SwiftUI
import UIKit

/// The toast's leading glyph: a rotating spinner while loading, otherwise a
/// validated SF Symbol that animates its swap.
struct IconView: View {
  let toast: ToastModel
  @Environment(\.colorScheme) private var scheme

  private var tintColor: Color {
    if let c = toast.style?.iconColor?.resolved(scheme) { return c }
    if let c = toast.style?.tint?.resolved(scheme) { return c }
    return toast.semantic.tint
  }

  var body: some View {
    ZStack {
      if toast.state == .loading {
        SpinnerView(color: tintColor)
          .transition(.scale.combined(with: .opacity))
      } else if let symbol = validatedSymbol {
        Image(systemName: symbol)
          .font(.system(size: 17, weight: .semibold))
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(tintColor)
          .contentTransition(.symbolEffect(.replace.downUp))
          .transition(.scale.combined(with: .opacity))
      }
    }
    .frame(width: 22, height: 22)
    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: toast.state)
  }

  /// `Image(systemName:)` silently renders nothing for an unknown name, so we
  /// validate with `UIImage(systemName:)` first and fall back to the semantic
  /// default if the caller's symbol is invalid on this OS version.
  private var validatedSymbol: String? {
    guard let name = toast.resolvedSymbol else { return nil }
    if UIImage(systemName: name) != nil { return name }
    if let fallback = toast.semantic.defaultSymbol, UIImage(systemName: fallback) != nil {
      return fallback
    }
    return nil
  }
}

/// A lightweight indeterminate spinner — a trimmed circle stroke spinning
/// forever, sized to match the icon slot.
struct SpinnerView: View {
  let color: Color
  @State private var rotation: Double = 0

  var body: some View {
    Circle()
      .trim(from: 0, to: 0.72)
      .stroke(color.opacity(0.85), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
      .frame(width: 17, height: 17)
      .rotationEffect(.degrees(rotation))
      .onAppear {
        withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) {
          rotation = 360
        }
      }
  }
}
