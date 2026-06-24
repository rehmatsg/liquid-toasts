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
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        brightness: Brightness.dark,
      ),
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
    // A colorful backdrop so the Liquid Glass refraction is visible.
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6FD8), Color(0xFF3813C2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
            children: [
              const Text(
                'Liquid Toasts',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Native iOS toasts · tap to fire',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 24),
              const _Section('Semantic styles'),
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
                final result = await LiquidToasts.showLoading<String>(
                  _fakeWork(),
                  config: const LoadingToast(
                    loadingMessage: 'Syncing…',
                    successMessage: 'Synced',
                  ),
                );
                debugPrint('work returned: $result');
              }),
              _Btn('Loading → error (rethrows)', () async {
                try {
                  await LiquidToasts.showLoading<String>(
                    _fakeWork(fail: true),
                    config: const LoadingToast(
                      loadingMessage: 'Uploading…',
                      errorMessage: 'Upload failed',
                    ),
                    onError: (e, _) => Toast.error(
                      message: 'Upload failed',
                      duration: null,
                      action: ToastAction(
                        label: 'Retry',
                        role: ToastActionRole.destructive,
                        onPressed: () {},
                      ),
                    ),
                  );
                } catch (e) {
                  debugPrint('caught (expected): $e');
                }
              }),
              const _Section('Positioning & stacking'),
              _Btn('Bottom toast (no island origin)', () {
                LiquidToasts.show(Toast(
                  message: 'Copied link',
                  icon: 'link',
                  position: ToastPosition.bottomCenter,
                  style: const ToastStyleOverride(glass: ToastGlass.frosted),
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
        ),
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
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await handle.update(Toast(
        message: 'Uploading ${p * 10}%',
        icon: 'arrow.up.circle',
        duration: null,
        progress: p / 10,
      ));
    }
    await handle.update(Toast.success(message: 'Upload complete'));
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.tonal(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
