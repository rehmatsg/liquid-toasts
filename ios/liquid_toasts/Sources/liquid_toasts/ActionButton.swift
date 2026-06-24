import SwiftUI

/// The single, fully-rounded action button. Color is derived from the role
/// (adaptive) unless an explicit color override was supplied.
struct ActionButton: View {
  let action: ToastActionModel
  let onTap: () -> Void
  @Environment(\.colorScheme) private var scheme

  private var color: Color {
    action.color?.resolved(scheme) ?? action.role.color
  }

  var body: some View {
    Button(action: onTap) {
      Text(action.label)
        .font(.system(.subheadline, design: .rounded).weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(color.opacity(scheme == .dark ? 0.24 : 0.15), in: Capsule())
        .contentShape(Capsule())
    }
    .buttonStyle(PressableButtonStyle())
    .fixedSize()
  }
}

/// Shrinks the button under the finger and fires a light haptic on the
/// press-down edge — the premium "real button" feel.
struct PressableButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.92 : 1)
      .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
      .onChange(of: configuration.isPressed) { _, pressed in
        if pressed { Haptics.impact(.light) }
      }
  }
}
