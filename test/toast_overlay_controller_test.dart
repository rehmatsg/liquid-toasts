import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_toasts/liquid_toasts.dart';
import 'package:liquid_toasts/src/overlay/toast_overlay_controller.dart';

/// Headless tests for the overlay's state machine — the cross-platform port of
/// the native `ToastManager`. Exercises queue/replace/maxVisible/wall-clock/
/// lifecycle logic without pumping any widgets.
void main() {
  // Needed because the controller registers a WidgetsBindingObserver.
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<ToastEvent> events;
  late ToastOverlayController controller;

  setUp(() {
    events = [];
    controller = ToastOverlayController(emit: events.add);
  });

  tearDown(() => controller.dispose());

  Iterable<ToastEvent> dismissedFor(ToastDismissReason reason) => events.where(
        (e) => e.kind == ToastEventKind.dismissed && e.reason == reason,
      );

  test('present tracks the toast and emits shown', () {
    controller.present(
      'lt_1',
      const Toast(message: 'hi', duration: Duration(seconds: 3)),
      null,
    );
    expect(controller.toasts.single.id, 'lt_1');
    expect(
      events.where((e) => e.kind == ToastEventKind.shown).map((e) => e.id),
      ['lt_1'],
    );
  });

  test('arms a deadline for transient toasts, none for persistent', () {
    controller.present(
        'a', const Toast(message: 'x', duration: Duration(seconds: 3)), null);
    controller.present('b', const Toast(message: 'y', duration: null), null);
    expect(controller.toasts.firstWhere((t) => t.id == 'a').deadline, isNotNull);
    expect(controller.toasts.firstWhere((t) => t.id == 'b').deadline, isNull);
  });

  test('same groupKey morphs in place (dismissed replaced + shown)', () {
    controller.present('a',
        const Toast(message: 'A', groupKey: 'g', duration: null), null);
    controller.present('b',
        const Toast(message: 'B', groupKey: 'g', duration: null), null);

    expect(controller.toasts.length, 1);
    expect(controller.toasts.single.id, 'b');
    expect(controller.toasts.single.toast.message, 'B');
    expect(
      events.any((e) =>
          e.id == 'a' &&
          e.kind == ToastEventKind.dismissed &&
          e.reason == ToastDismissReason.replaced),
      isTrue,
    );
    expect(
      events.any((e) => e.id == 'b' && e.kind == ToastEventKind.shown),
      isTrue,
    );
  });

  test('maxVisible evicts the oldest in a position (dropOldest)', () {
    controller.configure(const LiquidToastsConfig(maxVisible: 2));
    for (final id in ['a', 'b', 'c']) {
      controller.present(id, const Toast(message: '_', duration: null), null);
    }
    expect(
      events.any((e) =>
          e.id == 'a' &&
          e.kind == ToastEventKind.dismissed &&
          e.reason == ToastDismissReason.replaced),
      isTrue,
    );
    final live = controller.toasts
        .where((t) => t.phase != ToastPhase.exiting)
        .map((t) => t.id)
        .toList();
    expect(live, ['b', 'c']);
  });

  test('maxVisible drops the newest under dropNewest', () {
    controller.configure(const LiquidToastsConfig(
      maxVisible: 1,
      dropPolicy: ToastDropPolicy.dropNewest,
    ));
    controller.present('a', const Toast(message: '_', duration: null), null);
    controller.present('b', const Toast(message: '_', duration: null), null);
    final live = controller.toasts
        .where((t) => t.phase != ToastPhase.exiting)
        .map((t) => t.id)
        .toList();
    expect(live, ['a']);
  });

  test('requestDismiss emits the reason and is idempotent', () {
    controller.present('a', const Toast(message: 'A', duration: null), null);
    expect(controller.requestDismiss('a', ToastDismissReason.manual), isTrue);
    expect(dismissedFor(ToastDismissReason.manual).map((e) => e.id), ['a']);
    // Already exiting → no longer "live".
    expect(controller.requestDismiss('a', ToastDismissReason.manual), isFalse);
    expect(controller.requestDismiss('ghost', ToastDismissReason.manual), isFalse);
  });

  test('morph updates a live toast and re-arms; fails on a gone id', () {
    controller.present('a', const Toast(message: 'A', duration: null), null);
    expect(
      controller.morph(
          'a', const Toast(message: 'A2', duration: Duration(seconds: 2)), null),
      isTrue,
    );
    expect(controller.toasts.single.toast.message, 'A2');
    expect(controller.toasts.single.deadline, isNotNull);
    expect(controller.morph('ghost', const Toast(message: 'x'), null), isFalse);
  });

  test('dismissAll returns ids and emits dismissed for each', () {
    controller.present('a', const Toast(message: 'A', duration: null), null);
    controller.present('b', const Toast(message: 'B', duration: null), null);
    final ids = controller.dismissAll(ToastDismissReason.dismissAll);
    expect(ids.toSet(), {'a', 'b'});
    expect(
      dismissedFor(ToastDismissReason.dismissAll).map((e) => e.id).toSet(),
      {'a', 'b'},
    );
  });

  test('onExitComplete removes a toast that finished exiting', () {
    controller.present('a', const Toast(message: 'A', duration: null), null);
    controller.requestDismiss('a', ToastDismissReason.manual);
    expect(controller.toasts.length, 1, reason: 'still mounted while exiting');
    controller.onExitComplete('a');
    expect(controller.toasts, isEmpty);
  });

  test('expired deadline on resume dismisses with appBackgrounded', () {
    controller.present(
        'a', const Toast(message: 'A', duration: Duration(seconds: 3)), null);
    controller.toasts.single.deadline =
        DateTime.now().subtract(const Duration(seconds: 1));
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(dismissedFor(ToastDismissReason.appBackgrounded).map((e) => e.id), ['a']);
  });

  test('handleTap emits tap and dismisses when tapToDismiss', () {
    controller.present(
      'a',
      Toast(message: 'A', duration: null, onTap: () {}),
      null,
    );
    controller.handleTap(controller.toasts.single);
    expect(events.any((e) => e.id == 'a' && e.kind == ToastEventKind.tap), isTrue);
    expect(dismissedFor(ToastDismissReason.tap).map((e) => e.id), ['a']);
  });

  test('handleAction echoes the actionId and dismisses on dismissOnPress', () {
    controller.present(
      'a',
      Toast(
        message: 'A',
        duration: null,
        action: ToastAction(label: 'Go', onPressed: () {}),
      ),
      'act1',
    );
    controller.handleAction(controller.toasts.single);
    expect(
      events.any((e) =>
          e.id == 'a' &&
          e.kind == ToastEventKind.action &&
          e.actionId == 'act1'),
      isTrue,
    );
    expect(dismissedFor(ToastDismissReason.action).map((e) => e.id), ['a']);
  });
}
