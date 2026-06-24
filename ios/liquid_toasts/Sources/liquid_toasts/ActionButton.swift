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
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(color.opacity(scheme == .dark ? 0.22 : 0.14), in: Capsule())
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .fixedSize()
  }
}
