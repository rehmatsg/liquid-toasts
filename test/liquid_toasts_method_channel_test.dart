import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_toasts/liquid_toasts.dart';
import 'package:liquid_toasts/liquid_toasts_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelLiquidToasts platform = MethodChannelLiquidToasts();
  const MethodChannel channel = MethodChannel('liquid_toasts');
  final List<MethodCall> calls = [];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      calls.add(methodCall);
      switch (methodCall.method) {
        case 'show':
          return {'id': methodCall.arguments['id'], 'accepted': true};
        case 'update':
          return {'applied': true};
        case 'dismiss':
          return {'dismissed': true};
        case 'dismissAll':
          return {
            'dismissedIds': ['lt_x_0000']
          };
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('show serializes the toast and parses the ack', () async {
    final accepted = await platform.show(
      'lt_x_0001',
      Toast.success(message: 'Saved', icon: 'checkmark'),
      actionId: null,
    );
    expect(accepted, isTrue);

    final call = calls.single;
    expect(call.method, 'show');
    final args = call.arguments as Map;
    expect(args['protocolVersion'], 1);
    expect(args['id'], 'lt_x_0001');
    expect(args['message'], 'Saved');
    expect(args['icon'], 'checkmark');
    expect(args['semantic'], 'success');
    expect(args['state'], 'static');
    expect(args['position'], 'topCenter');
  });

  test('loading toast serializes as persistent with state=loading', () {
    final map = Toast.loading(message: 'Working').toMap();
    expect(map['state'], 'loading');
    expect(map['persistent'], true);
    expect(map.containsKey('durationMs'), isFalse);
  });

  test('action serializes the actionId and role', () {
    final map = Toast(
      message: 'x',
      action: ToastAction(
          label: 'Retry',
          role: ToastActionRole.destructive,
          onPressed: () {}),
    ).toMap(actionId: 'a7');
    final action = map['action'] as Map;
    expect(action['actionId'], 'a7');
    expect(action['role'], 'destructive');
    expect(action['label'], 'Retry');
  });

  test('dismissAll parses the dismissedIds list', () async {
    final ids = await platform.dismissAll();
    expect(ids, ['lt_x_0000']);
  });
}
