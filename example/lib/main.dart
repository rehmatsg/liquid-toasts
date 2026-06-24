import 'package:flutter/material.dart';
import 'package:liquid_toasts/liquid_toasts.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liquid Toasts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _replaceCount = 0;

  Future<String> _fakeWork({bool fail = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (fail) throw Exception('Network unreachable');
    return 'OK';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liquid Toasts')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          const _Section('Semantic'),
          _Btn('Success', () => LiquidToasts.success('Saved to favorites')),
          _Btn('Error', () => LiquidToasts.error('Could not connect')),
          _Btn('Warning', () => LiquidToasts.warning('Low storage')),
          _Btn('Info', () => LiquidToasts.info('3 updates available')),
          const _Section('Action button'),
          _Btn('Warning + action', () {
            LiquidToasts.warning(
              'Low storage',
              duration: null,
              action: ToastAction(
                label: 'Manage',
                role: ToastActionRole.primary,
                onPressed: () => LiquidToasts.info('Opening settings…'),
              ),
            );
          }),
          _Btn('Error + destructive retry', () {
            LiquidToasts.error(
              'Upload failed',
              duration: null,
              action: ToastAction(
                label: 'Retry',
                role: ToastActionRole.destructive,
                onPressed: () => LiquidToasts.success('Retrying…'),
              ),
            );
          }),
          const _Section('Loading lifecycle'),
          _Btn('Loading → success', () async {
            await LiquidToasts.showLoading<String>(
              _fakeWork(),
              config: const LoadingToast(
                loadingMessage: 'Syncing…',
                successMessage: 'Synced',
              ),
            );
          }),
          _Btn('Loading → error', () async {
            try {
              await LiquidToasts.showLoading<String>(
                _fakeWork(fail: true),
                config: const LoadingToast(
                  loadingMessage: 'Uploading…',
                  errorMessage: 'Upload failed',
                ),
              );
            } catch (_) {/* handled by the toast */}
          }),
          const _Section('Positioning & stacking'),
          _Btn('Bottom toast', () {
            LiquidToasts.show(const Toast(
              message: 'Copied link',
              icon: 'link',
              position: ToastPosition.bottomCenter,
            ));
          }),
          _Btn('Stack 4 quickly', () async {
            for (var i = 1; i <= 4; i++) {
              LiquidToasts.info('Notification #$i');
              await Future<void>.delayed(const Duration(milliseconds: 220));
            }
          }),
          const _Section('Persistent, replace & progress'),
          _Btn('Persistent + dismiss via handle', () async {
            final handle = await LiquidToasts.show(const Toast(
              message: 'Connecting…',
              icon: 'wifi',
              duration: null,
            ));
            await Future<void>.delayed(const Duration(seconds: 2));
            await handle.update(
                Toast.success(message: 'Connected', duration: null));
            await Future<void>.delayed(const Duration(seconds: 1));
            await handle.dismiss();
          }),
          _Btn('Replace-by-key (tap repeatedly)', () {
            _replaceCount++;
            LiquidToasts.info(
              'Tapped $_replaceCount time(s)',
              groupKey: 'counter',
              duration: null,
            );
          }),
          _Btn('Progress upload', _runProgress),
          const _Section('Bulk'),
          _Btn('Dismiss all', () => LiquidToasts.dismissAll()),
        ],
      ),
    );
  }

  Future<void> _runProgress() async {
    final handle = await LiquidToasts.show(const Toast(
      message: 'Uploading 0%',
      icon: 'arrow.up.circle',
      duration: null,
      progress: 0,
    ));
    for (var p = 1; p <= 10; p++) {
      await Future<void>.delayed(const Duration(milliseconds: 240));
      await handle.update(Toast(
        message: 'Uploading ${p * 10}%',
        icon: 'arrow.up.circle',
        duration: null,
        progress: p / 10,
      ));
    }
    // Keep `progress` set so the toast height stays identical at completion.
    await handle.update(const Toast(
      message: 'Upload complete',
      icon: 'checkmark.circle.fill',
      semantic: ToastSemantic.success,
      duration: Duration(seconds: 2),
      progress: 1,
    ));
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 6, left: 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                letterSpacing: 0.4,
              ),
        ),
      );
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
