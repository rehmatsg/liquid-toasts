# liquid_toasts

Premium, **SwiftUI-native** toasts for Flutter — rendered above your app with
adaptive **Liquid Glass**, a springy slide-in entrance, per-position vertical
stacking, and async **loading** toasts. No `BuildContext` required.

## Showcase

<table>
  <tr>
    <td width="50%" align="center">
      <video src="https://github.com/user-attachments/assets/35c34736-37f6-478c-911f-7d94a9234b13" width="300" muted controls></video><br/>
      <sub><b>Stacking</b> — staggered in and out</sub>
    </td>
    <td width="50%" align="center">
      <video src="https://github.com/user-attachments/assets/3af9f57d-c4e9-4e44-9113-74d56a5e7e14" width="300" muted controls></video><br/>
      <sub><b>Animated icons</b> — SF Symbol effects</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <video src="https://github.com/user-attachments/assets/4929a654-f2e2-437a-aa40-95209c7d7344" width="300" muted controls></video><br/>
      <sub><b>Progress</b> — determinate upload</sub>
    </td>
    <td width="50%" align="center">
      <video src="https://github.com/user-attachments/assets/fad24d65-6794-4289-a440-60576e57d40d" width="300" muted controls></video><br/>
      <sub><b>Action button</b> — inline Undo</sub>
    </td>
  </tr>
</table>

## Highlights

- **Native rendering** — toasts are drawn in SwiftUI on an overlay above your
  Flutter UI, so they float over everything and need no `BuildContext`.
- **Adaptive Liquid Glass** — real `glassEffect` on iOS 26+, a frosted
  `.ultraThinMaterial` fallback on iOS 17–25, and an opaque surface under
  *Reduce Transparency*.
- **Springy entrance** — toasts slide in from the nearest edge (down from the
  top, up from the bottom) with a fade + scale, and fade + blur away in place.
- **Loading lifecycle** — wrap a `Future`; show a spinner, then morph to
  success/error. The call **returns your value / rethrows your error**, so your
  app owns the outcome.
- **Vertical stacking** — each position is its own list (up to 5 toasts);
  newest pushes the rest along, and overflow scales + fades + blurs away in
  place.
- **Semantic styles** — `success` / `error` / `warning` / `info`, each
  overridable. SF Symbols by name, with customizable (adaptive) icon colors.
- **Animated icons** — opt into an SF Symbol effect (`bounce`, `pulse`,
  `wiggle`, `rotate`, `breathe`, `variableColor`, or iOS-26 `drawOn`) per toast.
- **One action button** — fully rounded, color derived from a semantic role.
- **Production extras** — tap-to-dismiss, replace-by-key, determinate progress,
  haptics, accessibility (VoiceOver + Reduce Motion), app-wide defaults, and
  `activeCount` / `activeIds` introspection.

## Requirements

- iOS **17.0+** (Liquid Glass auto-activates on iOS 26+; frosted fallback below).
- Flutter **3.27+**.

## Install

```yaml
dependencies:
  liquid_toasts: ^0.3.0
```

## Usage

```dart
import 'package:liquid_toasts/liquid_toasts.dart';

// Semantic one-liners — fire and forget, no await, no BuildContext
toast.success('Saved to favorites');
toast.error('Could not connect');
toast.warning('Low storage');
toast.info('3 updates available');
toast('Plain message'); // the object is callable
```

### Action button

```dart
toast.warning(
  'Low storage',
  duration: null, // persistent until tapped/dismissed
  action: ToastAction(
    label: 'Manage',
    role: ToastActionRole.primary,
    onPressed: openStorageSettings,
  ),
);
```

### Wrap a future (the call returns your result)

```dart
final user = await toast.promise(
  api.signIn(email, password),
  loading: 'Signing in…',
  success: (u) => 'Welcome back, ${u.firstName}!',
  error: 'Sign-in failed',
);
// `user` is your value; on failure the call rethrows so your try/catch fires.
```

`loading` / `success` / `error` each take a `String`, a full `Toast`, or a
builder (`(value) => …` / `(error) => …`).

### Persistent toast + live handle

```dart
final t = toast.loading('Connecting…');       // handle returned synchronously
await Future.delayed(const Duration(seconds: 2));
t.update(loading: false, message: 'Connected', semantic: ToastSemantic.success);
t.dismiss();
final reason = await t.onDismissed;           // always completes
```

`update` patches only the fields you pass (rapid patches compose, in order);
`replace(Toast(...))` swaps the content wholesale.

### Positioning, replace-by-key, progress

```dart
// Bottom toast
toast.show('Copied link', icon: 'link', position: ToastPosition.bottomCenter);

// Replace-or-update instead of stacking duplicates
toast.info('Reconnecting…', groupKey: 'net', duration: null);

// Determinate progress via patch updates
final t = toast.show('Uploading…', duration: null, progress: 0);
t.update(progress: 0.6);
t.update(progress: 1.0, message: 'Uploaded', duration: const Duration(seconds: 2));
```

### App-wide defaults

```dart
toast.setDefaults(const LiquidToastsConfig(
  defaultPosition: ToastPosition.topCenter,
  maxVisible: 3,
));
```

`defaultDuration` left null keeps the per-semantic defaults
(success/info/warning 3 s, error 4 s).

> **Name collision?** `import 'package:liquid_toasts/liquid_toasts.dart' hide
> toast;` and use `Toaster.instance`.

## API at a glance

| Type | Purpose |
|---|---|
| `toast` (a `Toaster`) | The primary API: callable `show` · `success/error/warning/info/loading` · `raw(Toast)` · `promise` · `dismiss/dismissAll` · `setDefaults` · `queryGeometry` · `activeCount/activeIds` — all shows return the handle synchronously |
| `Toast` | Immutable content (message, title, SF Symbol icon, semantic, style, position, duration, action, progress, haptic, …) with named constructors and `copyWith` |
| `ToastAction` | Single action button (`label`, `onPressed`, `role`, `color`) |
| `ToastHandle` | Live controller: patch-style `update(...)`, `replace(Toast)`, `dismiss`, `onDismissed` |
| `ToastStyleOverride` / `ToastColor` | Per-toast tint/foreground/glass overrides (adaptive light/dark) |
| `LiquidToasts` / `LoadingToast` | **Deprecated** legacy facade — working delegates until 1.0 |

## Migrating from `LiquidToasts`

The old static facade still works (with deprecation hints) and shares the same
engine, so you can migrate incrementally:

| Before | After |
|---|---|
| `await LiquidToasts.success('Hi')` | `toast.success('Hi')` (no await) |
| `await LiquidToasts.show(Toast(...))` | `toast.raw(Toast(...))` |
| `LiquidToasts.showLoading(f, config: LoadingToast(...))` | `toast.promise(f, loading:, success:, error:)` |
| `handle.update(Toast(...))` | `handle.replace(Toast(...))` — or patch: `handle.update(progress: 0.6)` |
| `LiquidToasts.dismissAll()` | `toast.dismissAll()` |
| `LiquidToasts.setDefaults(...)` | `toast.setDefaults(...)` |

## Notes for contributors

The bundled `example/` depends on the plugin via a path dependency. Flutter's
Swift Package Manager integration derives the package identity from the project
**folder name**, so the local checkout folder must be `liquid_toasts` (matching
the Dart package name), not `liquid-toasts`. Consumers installing from pub.dev
are unaffected. CocoaPods is also supported.

## License

See [LICENSE](LICENSE).
