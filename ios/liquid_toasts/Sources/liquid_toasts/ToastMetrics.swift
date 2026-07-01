import SwiftUI

/// Single source for every shared layout constant and spring in the toast
/// render tree. The off-screen measurement probes must mirror the live
/// layout's insets exactly or the wrap/width decisions drift — routing every
/// value through here makes that lockstep structural instead of copy-paste.
enum ToastMetrics {
  // MARK: Row insets (multiline gets roomier insets than the hugging capsule)

  static func leadingPadding(multiline: Bool) -> CGFloat { multiline ? 18 : 16 }
  static func verticalPadding(multiline: Bool) -> CGFloat { multiline ? 14 : 11 }

  /// Trailing inset. With an action present it matches the (tighter) button
  /// margin; otherwise it mirrors the leading inset.
  static func trailingPadding(multiline: Bool, hasAction: Bool) -> CGFloat {
    hasAction ? 11 : leadingPadding(multiline: multiline)
  }

  /// Spacing between the icon, the text column, and the action.
  static func rowSpacing(multiline: Bool) -> CGFloat { multiline ? 14 : 12 }

  // MARK: Slots & column widths

  /// Leading glyph slot (spinner / SF Symbol / progress ring).
  static let iconSlot: CGFloat = 22
  /// Determinate progress ring diameter (sits inside the icon slot).
  static let progressRingSize: CGFloat = 20
  /// Leading avatar / thumbnail diameter.
  static let avatarSize: CGFloat = 26
  /// Single-line text column cap so the capsule never spans the screen.
  static let textColumnMaxWidth: CGFloat = 260
  /// Fixed linear progress bar width on a hugging capsule.
  static let linearProgressWidth: CGFloat = 160
  /// Estimated action button width until its first real measurement lands.
  static let actionWidthEstimate: CGFloat = 72
  /// Floor for the multiline probe's reference text width.
  static let probeMinReferenceWidth: CGFloat = 120

  // MARK: Multiline geometry

  static let multilineSideMargin: CGFloat = 20
  static let multilineMaxWidth: CGFloat = 440

  /// Width of a multiline toast: near-full device width, comfortably inset,
  /// capped so it never stretches unwieldily wide on iPad / landscape.
  static func multilineWidth(deviceWidth: CGFloat) -> CGFloat {
    min(multilineMaxWidth, deviceWidth - multilineSideMargin * 2)
  }

  // MARK: Shape

  static let multilineCornerRadius: CGFloat = 22
  /// Large radius that `RoundedRectangle` clamps to a capsule on compact toasts.
  static let capsuleCornerRadius: CGFloat = 99

  // MARK: Drag

  static let dragMinDistance: CGFloat = 6
  /// Translation past which a drag toward the edge commits to dismissal.
  static let dragCommitDistance: CGFloat = 28
  /// Predicted end translation past which a flick commits regardless of travel.
  static let flickDistance: CGFloat = 140
  /// Damping applied when dragging away from the dismiss edge.
  static let rubberBandFactor: CGFloat = 0.35

  // MARK: Springs

  /// The stack's shared motion: entrances, reorders, morphs, width changes.
  static let stackSpring: Animation = .spring(response: 0.42, dampingFraction: 0.82)
  /// Snappier settle: drag return, icon swaps.
  static let settleSpring: Animation = .spring(response: 0.35, dampingFraction: 0.7)
}
