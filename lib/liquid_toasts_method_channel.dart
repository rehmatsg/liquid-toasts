import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'liquid_toasts_platform_interface.dart';

/// An implementation of [LiquidToastsPlatform] that uses method channels.
class MethodChannelLiquidToasts extends LiquidToastsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('liquid_toasts');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
