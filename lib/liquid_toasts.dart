
import 'liquid_toasts_platform_interface.dart';

class LiquidToasts {
  Future<String?> getPlatformVersion() {
    return LiquidToastsPlatform.instance.getPlatformVersion();
  }
}
