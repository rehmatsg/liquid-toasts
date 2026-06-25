import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_toasts/liquid_toasts.dart';
import 'package:liquid_toasts/liquid_toasts_platform_interface.dart';

/// End-to-end tests for the Flutter-rendered overlay: drive the real
/// [LiquidToasts] facade against [OverlayLiquidToasts] and assert the rendered
/// cards, gestures, and lifecycle events.
void main() {
  late OverlayLiquidToasts platform;

  setUp(() async {
    await LiquidToasts.debugReset();
    platform = OverlayLiquidToasts();
    LiquidToastsPlatform.instance = platform;
  });

  tearDown(() async {
    await LiquidToasts.debugReset();
    platform.dispose();
  });

  Future<void> pumpApp(WidgetTester tester) =>
      tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox.expand())));

  testWidgets('renders a toast card with its message', (tester) async {
    await pumpApp(tester);
    await LiquidToasts.success('Saved');
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);

    // Cancel the auto-dismiss timer before the test body ends.
    await LiquidToasts.dismissAll();
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('tap dismisses and completes the handle with tap', (tester) async {
    await pumpApp(tester);
    final handle =
        await LiquidToasts.show(const Toast(message: 'Tap me', duration: null));
    await tester.pumpAndSettle();
    expect(find.text('Tap me'), findsOneWidget);

    await tester.tap(find.text('Tap me'));
    await tester.pumpAndSettle();

    expect(await handle.onDismissed, ToastDismissReason.tap);
    expect(find.text('Tap me'), findsNothing);
  });

  testWidgets('auto-dismisses after its duration with timeout', (tester) async {
    await pumpApp(tester);
    final handle = await LiquidToasts.show(
        const Toast(message: 'Bye', duration: Duration(seconds: 2)));
    await tester.pump(); // build + entrance
    expect(find.text('Bye'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2)); // fire the auto-dismiss timer
    await tester.pumpAndSettle(); // play the exit animation out

    expect(await handle.onDismissed, ToastDismissReason.timeout);
    expect(find.text('Bye'), findsNothing);
  });

  testWidgets('same groupKey replaces the visible toast', (tester) async {
    await pumpApp(tester);
    final first = await LiquidToasts.show(
        const Toast(message: 'First', groupKey: 'g', duration: null));
    await tester.pump();
    final second = await LiquidToasts.show(
        const Toast(message: 'Second', groupKey: 'g', duration: null));
    await tester.pumpAndSettle();

    expect(find.text('Second'), findsOneWidget);
    expect(find.text('First'), findsNothing);
    expect(await first.onDismissed, ToastDismissReason.replaced);
    expect(second.isShowing, isTrue);
  });

  testWidgets('dismissAll clears every toast and completes the handles',
      (tester) async {
    await pumpApp(tester);
    final h1 = await LiquidToasts.show(const Toast(message: 'One', duration: null));
    final h2 = await LiquidToasts.show(const Toast(message: 'Two', duration: null));
    await tester.pump();

    await LiquidToasts.dismissAll();
    await tester.pumpAndSettle();

    expect(await h1.onDismissed, ToastDismissReason.dismissAll);
    expect(await h2.onDismissed, ToastDismissReason.dismissAll);
    expect(find.text('One'), findsNothing);
    expect(find.text('Two'), findsNothing);
  });

  testWidgets('flinging a top toast up dismisses it with swipe', (tester) async {
    await pumpApp(tester);
    final handle = await LiquidToasts.show(const Toast(
      message: 'Swipe me',
      position: ToastPosition.topCenter,
      duration: null,
    ));
    await tester.pumpAndSettle();

    await tester.fling(find.text('Swipe me'), const Offset(0, -240), 1200);
    await tester.pumpAndSettle();

    expect(await handle.onDismissed, ToastDismissReason.swipe);
    expect(find.text('Swipe me'), findsNothing);
  });

  testWidgets('action tap fires onPressed and dismisses', (tester) async {
    await pumpApp(tester);
    var pressed = false;
    final handle = await LiquidToasts.show(Toast(
      message: 'With action',
      duration: null,
      action: ToastAction(label: 'Undo', onPressed: () => pressed = true),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(pressed, isTrue);
    expect(await handle.onDismissed, ToastDismissReason.action);
  });

  testWidgets('showLoading shows a spinner then morphs to success',
      (tester) async {
    await pumpApp(tester);
    final completer = Completer<String>();
    final future = LiquidToasts.showLoading<String>(
      completer.future,
      config: const LoadingToast(loadingMessage: 'Working', successMessage: 'Done'),
    );
    // Avoid pumpAndSettle here: the spinner animates forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Working'), findsOneWidget);

    completer.complete('ok');
    await tester.pump(); // flush the morph (update)
    await tester.pump(const Duration(milliseconds: 350)); // switcher transition

    expect(await future, 'ok');
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Working'), findsNothing);

    // Cancel the success toast's auto-dismiss timer before the test body ends.
    await LiquidToasts.dismissAll();
    await tester.pump(const Duration(milliseconds: 400));
  });
}
