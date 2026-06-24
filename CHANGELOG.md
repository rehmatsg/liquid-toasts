## 0.0.1

Initial release — iOS support.

* SwiftUI-native toasts rendered on a same-window overlay (no `BuildContext`).
* Adaptive Liquid Glass (iOS 26+) with a frosted `.ultraThinMaterial` fallback
  (iOS 17–25) and an opaque surface under Reduce Transparency.
* Dynamic Island origin animation for top-center toasts (public APIs only);
  slide-in fallback elsewhere and on notch / home-button devices.
* Loading toasts tied to a `Future` — spinner → success/error — that return the
  value / rethrow the error to the caller.
* Depth stacking, semantic styles (success/error/warning/info), SF Symbol icons,
  and a single role-colored action button.
* Production extras: tap-to-dismiss, replace-by-key, determinate progress,
  haptics, accessibility (VoiceOver + Reduce Motion), app-wide defaults, and
  active-toast introspection.
* Requires iOS 17.0+ and Flutter 3.27+. Android is not yet implemented.
