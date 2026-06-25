# liquid_toasts

Premium, **SwiftUI-native** toasts for Flutter — rendered above your app with
adaptive **Liquid Glass**, a springy slide-in entrance, per-position vertical
stacking, and async **loading** toasts. No `BuildContext` required.

> iOS is supported today. Android is on the roadmap; the Dart API and wire
> protocol are platform-neutral so the same surface will light up on Android.

## Showcase

<table>
  <tr>
    <td width="50%" align="center">
      <video src="https://github.com/rehmatsg/liquid-toasts/raw/main/assets/showcase/stacking.mp4" controls width="100%"></video><br/>
      <sub><b>Stacking</b> — notifications slide in with a small delay, then drain</sub>
    </td>
    <td width="50%" align="center">
      <video src="https://github.com/rehmatsg/liquid-toasts/raw/main/assets/showcase/variable-color.mp4" controls width="100%"></video><br/>
      <sub><b>Animated SF Symbols</b> — e.g. variable-color Wi-Fi</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <video src="https://github.com/rehmatsg/liquid-toasts/raw/main/assets/showcase/progress.mp4" controls width="100%"></video><br/>
      <sub><b>Progress</b> — determinate upload</sub>
    </td>
    <td width="50%" align="center">
      <video src="https://github.com/rehmatsg/liquid-toasts/raw/main/assets/showcase/action.mp4" controls width="100%"></video><br/>
      <sub><b>Action button</b> — inline Undo</sub>
    </td>
  </tr>
</table>

> Recorded on the iOS 26 simulator. If a clip doesn't play inline, click it to
> open the file.

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
  liquid_toasts: ^0.0.1
```

## Usage

```dart
import 'package:liquid_toasts/liquid_toasts.dart';

// Semantic one-liners
LiquidToasts.success('Saved to favorites');
LiquidToasts.error('Could not connect');
LiquidToasts.warning('Low storage');
LiquidToasts.info('3 updates available');
```

### Action button

```dart
LiquidToasts.warning(
  'Low storage',
  duration: null, // persistent until tapped/dismissed
  action: ToastAction(
    label: 'Manage',
    role: ToastActionRole.primary,
    onPressed: openStorageSettings,
  ),
);
```

### Loading toast (the call returns your result)

```dart
final user = await LiquidToasts.showLoading<User>(
  api.signIn(email, password),
  config: const LoadingToast(
    loadingMessage: 'Signing in…',
    successMessage: 'Welcome back!',
  ),
  onSuccess: (u) => Toast.success(message: 'Hi ${u.firstName}!'),
  onError: (e, _) => Toast.error(message: 'Sign-in failed'),
);
// `user` is your value; on failure the call rethrows so your try/catch fires.
```

### Persistent toast + handle

```dart
final handle = await LiquidToasts.show(const Toast(
  message: 'Connecting…',
  icon: 'wifi',
  duration: null,
));
await handle.update(Toast.success(message: 'Connected'));
await handle.dismiss();
final reason = await handle.onDismissed; // always completes
```

### Positioning, replace-by-key, progress

```dart
// Bottom toast
LiquidToasts.show(const Toast(
  message: 'Copied link',
  icon: 'link',
  position: ToastPosition.bottomCenter,
));

// Replace-or-update instead of stacking duplicates
LiquidToasts.info('Reconnecting…', groupKey: 'net', duration: null);

// Determinate progress
final h = await LiquidToasts.show(const Toast(
  message: 'Uploading…', duration: null, progress: 0,
));
await h.update(const Toast(message: 'Uploading…', duration: null, progress: 0.6));
```

### App-wide defaults

```dart
LiquidToasts.setDefaults(const LiquidToastsConfig(
  defaultPosition: ToastPosition.topCenter,
  defaultDuration: Duration(seconds: 3),
  maxVisible: 3,
));
```

## API at a glance

| Type | Purpose |
|---|---|
| `LiquidToasts` | Static facade: `show` · `success/error/warning/info` · `showLoading` · `dismiss/dismissAll` · `queryGeometry` · `setDefaults` · `activeCount/activeIds` |
| `Toast` | Immutable content (message, title, SF Symbol icon, semantic, style, position, duration, action, progress, haptic, …) with named constructors |
| `ToastAction` | Single action button (`label`, `onPressed`, `role`, `color`) |
| `ToastHandle` | Live controller: `update`, `dismiss`, `onDismissed` |
| `LoadingToast` | Loading→success/error phase config |
| `ToastStyleOverride` / `ToastColor` | Per-toast tint/foreground/glass overrides (adaptive light/dark) |

## Notes for contributors

The bundled `example/` depends on the plugin via a path dependency. Flutter's
Swift Package Manager integration derives the package identity from the project
**folder name**, so the local checkout folder must be `liquid_toasts` (matching
the Dart package name), not `liquid-toasts`. Consumers installing from pub.dev
are unaffected. CocoaPods is also supported.

## License

See [LICENSE](LICENSE).
