import 'package:meta/meta.dart';

import 'toast_position.dart';
import 'toast_style.dart';

/// What to drop when more toasts are queued than the stack can hold.
enum ToastDropPolicy { dropOldest, dropNewest }

/// App-wide defaults, applied via [LiquidToasts.setDefaults].
///
/// [defaultPosition], [defaultDuration] and [defaultGlass] are applied by the
/// convenience constructors (`success`/`error`/…) when the caller omits them.
/// [maxVisible], [maxQueue] and [dropPolicy] govern the native stack/queue.
@immutable
class LiquidToastsConfig {
  const LiquidToastsConfig({
    this.defaultPosition = ToastPosition.topCenter,
    this.defaultDuration = const Duration(seconds: 3),
    this.defaultGlass = ToastGlass.adaptive,
    this.maxVisible = 3,
    this.maxQueue = 8,
    this.dropPolicy = ToastDropPolicy.dropOldest,
  });

  final ToastPosition defaultPosition;
  final Duration defaultDuration;
  final ToastGlass defaultGlass;

  /// Max toasts shown with depth transforms at once (others queue behind).
  final int maxVisible;

  /// Max total toasts (visible + queued) before [dropPolicy] kicks in.
  final int maxQueue;

  final ToastDropPolicy dropPolicy;

  /// Only the native-relevant knobs are sent over the channel.
  Map<String, Object?> toMap() => {
        'maxVisible': maxVisible,
        'maxQueue': maxQueue,
        'dropPolicy': dropPolicy.name,
        'defaultGlass': defaultGlass.name,
      };
}
