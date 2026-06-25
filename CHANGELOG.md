## 0.1.0

Cross-platform rendering: **Android, macOS, Windows, and Linux** now show toasts
via a Flutter-rendered overlay (no native platform code) — the same API,
animations, stacking, gestures, loading morph, and lifecycle events as iOS.

* New `OverlayLiquidToasts` platform implementation renders the toast UI in the
  app's root `Overlay`, discovered context-free (still no `BuildContext`).
* The background is a real `BackdropFilter` blur of the live app content — the
  cross-platform stand-in for Liquid Glass.
* Behavior parity: spring entrance, scale + fade + blur exit, swipe-to-dismiss,
  wall-clock auto-dismiss surviving backgrounding, replace-by-`groupKey`, and
  per-position `maxVisible`.
* Fidelity deltas by design: a simple blur (not Liquid Glass), Material icons
  instead of SF Symbols, and coarser haptics.
* iOS is unchanged (native SwiftUI Liquid Glass). The Android native
  method-channel stub was removed; Android is now a Dart-only platform.

## 0.0.1

Initial release — iOS support.

* SwiftUI-native toasts rendered on a same-window overlay (no `BuildContext`).
* Adaptive Liquid Glass (iOS 26+) with a frosted `.ultraThinMaterial` fallback
  (iOS 17–25) and an opaque surface under Reduce Transparency.
* Dynamic Island origin animation for top-center toasts (public APIs only);
  slide-in fallback elsewhere and on notch / home-button devices.
* Loading toasts tied to a `Future` — spinner → success/error — that return the
  value / rethrow the error to the caller.
* Per-position vertical stacking (max 5; overflow fades/blurs out in place),
  semantic styles (success/error/warning/info), SF Symbol icons with
  customizable adaptive colors and optional animated symbol effects (bounce,
  pulse, wiggle, rotate, breathe, variableColor, iOS-26 drawOn), and a single
  role-colored action button.
* Production extras: tap-to-dismiss, replace-by-key, determinate progress,
  haptics, accessibility (VoiceOver + Reduce Motion), app-wide defaults, and
  active-toast introspection.
* Requires iOS 17.0+ and Flutter 3.27+. Android is not yet implemented.
