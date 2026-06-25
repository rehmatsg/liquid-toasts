import 'package:flutter/physics.dart';

/// Spring specs for the Flutter overlay, converted from the iOS SwiftUI springs
/// so the cross-platform motion matches the native one.
///
/// SwiftUI's `spring(response: r, dampingFraction: d)` is a unit-mass spring
/// whose natural frequency is `ω = 2π / r`. A Flutter [SpringDescription] takes
/// stiffness `k = ω² = (2π / r)²` and a damping ratio equal to `d`. The values
/// below are those conversions, rounded.
class ToastSprings {
  ToastSprings._();

  /// Entrance / stack-settle. iOS `spring(response: 0.42, dampingFraction: 0.82)`.
  static final SpringDescription entrance = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 223.8,
    ratio: 0.82,
  );

  /// Action-button press. iOS `spring(response: 0.3, dampingFraction: 0.6)`.
  static final SpringDescription press = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 438.6,
    ratio: 0.6,
  );

  /// Swipe bounce-back. iOS `spring(response: 0.35, dampingFraction: 0.7)`.
  static final SpringDescription bounceBack = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 322.4,
    ratio: 0.7,
  );
}
