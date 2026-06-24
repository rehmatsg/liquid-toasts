import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_toasts/liquid_toasts.dart';
import 'package:liquid_toasts/liquid_toasts_platform_interface.dart';
import 'package:liquid_toasts/liquid_toasts_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockLiquidToastsPlatform
    with MockPlatformInterfaceMixin
    implements LiquidToastsPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final LiquidToastsPlatform initialPlatform = LiquidToastsPlatform.instance;

  test('$MethodChannelLiquidToasts is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelLiquidToasts>());
  });

  test('getPlatformVersion', () async {
    LiquidToasts liquidToastsPlugin = LiquidToasts();
    MockLiquidToastsPlatform fakePlatform = MockLiquidToastsPlatform();
    LiquidToastsPlatform.instance = fakePlatform;

    expect(await liquidToastsPlugin.getPlatformVersion(), '42');
  });
}
