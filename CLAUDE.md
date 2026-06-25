# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`liquid_toasts` is a Flutter **plugin** that renders premium toasts on an overlay
above the Flutter app — springy entrance, per-position vertical stacking, async
loading toasts — with **no `BuildContext` required** (the whole Dart API is
static). **iOS renders natively** in SwiftUI (adaptive Liquid Glass). **Every
other platform** (Android, macOS, Windows, Linux) shares a **Flutter-rendered
overlay** (`OverlayLiquidToasts`) with a real `BackdropFilter` blur. The Dart API
and wire protocol are platform-neutral, and the facade is identical everywhere.

## Commands

Run Dart commands from the repo root; run the app from `example/`.

```bash
flutter analyze                         # lint (flutter_lints, see analysis_options.yaml)
flutter test                            # all Dart unit tests
flutter test test/liquid_toasts_test.dart                    # one file
flutter test --plain-name 'show serializes the toast'        # one test by name

cd example && flutter run               # demo app (iOS sim/device, Android emulator, or desktop)
cd example && flutter run -t lib/showcase.dart   # run the README recording harness
```

Native Swift code is built by the Flutter/Xcode toolchain when you run the
example; there is no standalone Swift build step. The iOS sources live as a
local Swift package under `ios/liquid_toasts/`.

### Example app caveat

The bundled `example/` depends on the plugin via a **path** dependency. Flutter's
Swift Package Manager integration derives the package identity from the project
**folder name**, so the local checkout folder must be `liquid_toasts` (matching
the Dart package name), **not** `liquid-toasts`. The GitHub repo is named
`liquid-toasts`; rename the folder if you re-clone. Consumers installing from
pub.dev are unaffected. CocoaPods is also supported (`ios/liquid_toasts.podspec`).

## Architecture

The plugin is a **two-layer bridge**: a context-free Dart facade that owns
caller-facing state, behind a `LiquidToastsPlatform` interface with two
implementations. On **iOS** it's a SwiftUI overlay reached over a method/event
channel (`MethodChannelLiquidToasts`). On **every other platform** it's a
Flutter-rendered overlay in pure Dart (`OverlayLiquidToasts`). Both speak the
same `ToastEvent` contract, so the facade — registry, callbacks, completers —
is identical regardless of platform.

### Dart side (`lib/`)

- `LiquidToasts` (`lib/liquid_toasts.dart`) — the entire public API, all static.
  Owns a `_registry` mapping toast id → `_Registration` (the dismissal
  `Completer`, the action callback, the `onTap` callback). It mints ids, routes
  inbound events to the right callback, and completes `ToastHandle.onDismissed`.
  **All user callbacks (action/tap) live here, never cross the wire** — native
  only echoes back ids, so a stale tap after an `update` swapped the action is
  dropped by comparing `activeActionId`.
- `LiquidToastsPlatform` (`lib/liquid_toasts_platform_interface.dart`) — the
  `PlatformInterface` the facade talks to; swap `.instance` with a fake in tests.
  Its default picks `MethodChannelLiquidToasts` on iOS and `OverlayLiquidToasts`
  everywhere else (and the non-iOS Dart plugin registrant also calls
  `OverlayLiquidToasts.registerWith` via the pubspec `dartPluginClass`).
- `MethodChannelLiquidToasts` (`lib/liquid_toasts_method_channel.dart`) — the iOS
  impl. Every command is wrapped in an `_envelope` carrying `protocolVersion`
  (currently `1`); bump it on incompatible wire changes.
- `lib/src/` — the wire models: `toast.dart` (`Toast` + `toMap`), `toast_action.dart`,
  `toast_handle.dart`, `loading_toast.dart`, `toast_event.dart` (inbound events +
  `ToastDismissReason`), `toast_style.dart`, `toast_position.dart`,
  `liquid_toasts_config.dart`, `ids.dart` (id minting).

### iOS side (`ios/liquid_toasts/Sources/liquid_toasts/`)

- `LiquidToastsPlugin.swift` — the `FlutterPlugin`/`FlutterStreamHandler`. Decodes
  channel args into `ToastModel`s and drives the manager. Flutter calls channel
  handlers on the main thread, so it uses `MainActor.assumeIsolated` and touches
  UI directly with no actor hop.
- `ToastOverlayHost.swift` — singleton that installs a transparent
  `PassthroughHostView` + `UIHostingController` into the **same window** as
  Flutter content (so Liquid Glass can sample the live app behind it). The host
  hit-tests against `manager.frames` so touches pass through to Flutter except
  where a real toast sits. Installed eagerly at plugin registration so the first
  toast gets its entrance transition.
- `ToastManager.swift` — `@MainActor ObservableObject`, the single source of
  truth for the stack. Owns the queue, replace-by-`groupKey`, per-position
  `maxVisible` enforcement, **wall-clock** auto-dismiss deadlines (survive
  backgrounding), exactly-once teardown, and emits lifecycle events via `onEvent`.
- `ToastContainerView` / `ToastView` / `IconView` / `GlassBackground` /
  `ActionButton` — the SwiftUI render tree. `GlassBackground` picks real
  `glassEffect` (iOS 26+) vs `.ultraThinMaterial` (iOS 17–25) vs opaque (Reduce
  Transparency).
- `Models.swift` — `ToastModel` and friends; mirrors the Dart wire format.
- `DynamicIslandGeometry.swift` — device geometry snapshot for `queryGeometry`.
- `Haptics.swift` — maps the toast's haptic enum to `UINotificationFeedbackGenerator`.

### Cross-platform side (`lib/src/overlay/`)

Used on Android, macOS, Windows, and Linux. Renders the same toast UI with
Flutter widgets in the app's root `Overlay`; no native code. Mirrors the iOS
split — a headless state machine + a render tree.

- `OverlayLiquidToasts` (`overlay_liquid_toasts.dart`) — the non-iOS
  `LiquidToastsPlatform`. Implements the 8 members + the `events` stream + the
  `dartPluginClass` `registerWith`. Receives the typed `Toast` directly (no map
  parsing) but still routes action/tap through `ToastEvent`s so the facade's
  stale-action-id guard holds.
- `ToastOverlayController` (`toast_overlay_controller.dart`) — the headless,
  unit-testable port of `ToastManager.swift`: queue, replace-by-`groupKey`,
  per-position `maxVisible` + `dropPolicy`, **wall-clock** auto-dismiss surviving
  backgrounding (it's a `WidgetsBindingObserver`), exactly-once teardown, and
  event emission. Cards are keyed by the `LiveToast` instance so a `groupKey`
  morph keeps state (no re-entrance).
- `ToastOverlayHost` (`toast_overlay_host.dart`) — discovers the app's root
  `OverlayState` by walking `WidgetsBinding.rootElement` (context-free; works for
  any `MaterialApp`/`CupertinoApp`) and inserts one passthrough `OverlayEntry`.
- `widgets/` — the render tree (≈ the SwiftUI views): `toast_layer.dart`
  (7-position stacking), `toast_card.dart` (entrance spring, exit scale+fade+blur,
  swipe-to-dismiss), `toast_glass.dart` (`BackdropFilter` frosted background — the
  simple-blur stand-in for Liquid Glass; blurs the live app content),
  `toast_icon.dart`, `toast_action_button.dart`.
- `toast_springs.dart` — SwiftUI→Flutter spring conversions
  (`stiffness = (2π/response)²`). `sf_symbol_icons.dart` — SF Symbol → Material
  icon map + semantic defaults.

**Fidelity deltas vs iOS** (by design): a simple blur instead of Liquid Glass,
Material icons instead of SF Symbols (semantic toasts map cleanly; arbitrary SF
Symbol names fall back), and coarser `HapticFeedback`. Animations, stacking,
gestures, loading morph, and every lifecycle event match iOS.

### Wire protocol invariants

When changing anything that crosses the channel, keep both sides in lockstep:

- **Enum/event strings are identical on both sides** by exact string match
  (e.g. dismiss reasons `timeout`/`manual`/`swipe`/`action`/`tap`/`replaced`/
  `dismissAll`/`appBackgrounded`; events `shown`/`actionTapped`/`tapped`/
  `dismissed`). `ToastEvent.fromMap` and `reasonFromWire` map them on the Dart side.
- **Ids are minted in Dart** (`ids.dart`): `lt_<sessionPrefix>_<counter>`. The
  `sessionPrefix` is random per isolate and sent in `handshake`; native uses it
  to `flushAll` stale toasts after a **hot restart** (the old Dart event sink is
  dead, so those toasts must be dropped silently).
- Command acks are maps: `show`→`{accepted}`, `update`→`{applied}`,
  `dismiss`→`{dismissed}`, `dismissAll`→`{dismissedIds}`. A `false`/missing ack is
  an expected race (toast already gone) — the facade reconciles by locally
  completing the handle so `onDismissed` never hangs.

### Loading-toast contract

`LiquidToasts.showLoading<T>(future, ...)` shows a spinner, then morphs to
success/error. It **returns the future's value / rethrows its error** — the
visual is best-effort (skipped if the toast was already dismissed) but the
caller always owns the outcome. Don't change this to swallow results.

## Testing notes

- Dart tests use a `FakeLiquidToastsPlatform` (in `test/liquid_toasts_test.dart`)
  installed via `LiquidToastsPlatform.instance`, with manual control over the
  event stream and which ids native considers "live".
- `LiquidToasts.debugReset()` resets all static state between tests;
  `LiquidToasts.debugEmit(event)` injects a native event into the router. Both are
  `@visibleForTesting` — use them rather than reaching into private state.
- `test/toast_overlay_controller_test.dart` drives the overlay state machine
  headlessly; `test/overlay_liquid_toasts_test.dart` pumps a `MaterialApp` and
  asserts the rendered cards, gestures, and lifecycle events end-to-end. Tests
  that leave an armed auto-dismiss `Timer` must cancel it (e.g. `dismissAll`)
  before the body ends, or the test binding flags a pending timer.

## Showcase clips

`example/lib/showcase.dart` is a recording harness for the README's
`assets/showcase/*.mp4` clips (full-bleed wallpaper so glass has something to
refract, clean gaps between previews). The exact ffmpeg/simctl regeneration
recipe is documented in that file's header comment.
