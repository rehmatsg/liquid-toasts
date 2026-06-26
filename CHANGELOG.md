## 0.1.0

iOS multiline layout, progress styles, and interaction polish. No breaking
changes — everything below is additive (`progressStyle` defaults to `.linear`,
which reproduces the previous rendering).

* **Multiline toasts** — a message that wraps past one line (set `maxLines >= 2`)
  now renders as a wider, left-aligned rounded rectangle (≈4/5 width, inset like
  an iOS notification, capped on large screens) instead of a tall centered
  capsule. Single-line toasts keep the hugging capsule. Note `Toast.error` /
  `Toast.warning` default to `maxLines: 2`, so their long messages adopt this.
* **Progress styles** — new `ToastProgressStyle { linear, circular }` on
  `Toast.progressStyle`. `linear` is the bar under the text (now fills the width
  on multiline toasts); `circular` shows a determinate ring in the leading slot.
* **Pause on interaction** — a toast's auto-dismiss countdown now pauses while
  you touch / hold / drag it, and resumes on release.
* **Animated morphs** — updating a toast across the single-line ↔ multiline
  boundary (e.g. an upload's progress → "done") animates its width and corners
  in place instead of snapping.
* Tooling: `tool/record_demo.sh` + `example/lib/demo_harness.dart` for recording
  high-quality 60fps demo clips on the iOS simulator.

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
