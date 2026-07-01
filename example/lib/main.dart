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

  void _animatedIcon(ToastSymbolEffect effect, String icon, String label) {
    toast.raw(Toast(
      message: label,
      icon: icon,
      style: ToastStyleOverride(symbolEffect: effect),
      duration: const Duration(seconds: 3),
    ));
  }

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
          _Btn('Success', () => toast.success('Saved to favorites')),
          _Btn('Error', () => toast.error('Could not connect')),
          _Btn('Warning', () => toast.warning('Low storage')),
          _Btn('Info', () => toast.info('3 updates available')),
          const _Section('Action button'),
          _Btn('Warning + action', () {
            toast.warning(
              'Low storage',
              duration: null,
              action: ToastAction(
                label: 'Manage',
                role: ToastActionRole.primary,
                onPressed: () => toast.info('Opening settings…'),
              ),
            );
          }),
          _Btn('Error + destructive retry', () {
            toast.error(
              'Upload failed',
              duration: null,
              action: ToastAction(
                label: 'Retry',
                role: ToastActionRole.destructive,
                onPressed: () => toast.success('Retrying…'),
              ),
            );
          }),
          const _Section('Loading lifecycle'),
          _Btn('Loading → success', () async {
            await toast.promise<String>(
              _fakeWork(),
              loading: 'Syncing…',
              success: 'Synced',
            );
          }),
          _Btn('Loading → error', () async {
            try {
              await toast.promise<String>(
                _fakeWork(fail: true),
                loading: 'Uploading…',
                error: 'Upload failed',
              );
            } catch (_) {/* handled by the toast */}
          }),
          const _Section('Positioning & stacking'),
          _Btn('Bottom toast', () {
            toast.raw(const Toast(
              message: 'Copied link',
              icon: 'link',
              position: ToastPosition.bottomCenter,
            ));
          }),
          _Btn('Stack 4 quickly', () async {
            for (var i = 1; i <= 4; i++) {
              toast.info('Notification #$i');
              await Future<void>.delayed(const Duration(milliseconds: 220));
            }
          }),
          const _Section('Persistent, replace & progress'),
          _Btn('Persistent + dismiss via handle', () async {
            final handle = toast.raw(const Toast(
              message: 'Connecting…',
              icon: 'wifi',
              duration: null,
            ));
            await Future<void>.delayed(const Duration(seconds: 2));
            await handle.replace(
                Toast.success(message: 'Connected', duration: null));
            await Future<void>.delayed(const Duration(seconds: 1));
            await handle.dismiss();
          }),
          _Btn('Replace-by-key (tap repeatedly)', () {
            _replaceCount++;
            toast.info(
              'Tapped $_replaceCount time(s)',
              groupKey: 'counter',
              duration: null,
            );
          }),
          _Btn('Progress upload', _runProgress),
          const _Section('Animated icons'),
          _Btn('Bounce', () => _animatedIcon(ToastSymbolEffect.bounce, 'bell.fill', 'Bounce')),
          _Btn('Pulse', () => _animatedIcon(ToastSymbolEffect.pulse, 'heart.fill', 'Pulse')),
          _Btn('Rotate', () => _animatedIcon(ToastSymbolEffect.rotate, 'arrow.triangle.2.circlepath', 'Rotate')),
          _Btn('Variable color', () => _animatedIcon(ToastSymbolEffect.variableColor, 'wifi', 'Variable color')),
          _Btn('Draw on (iOS 26)', () => _animatedIcon(ToastSymbolEffect.drawOn, 'checkmark.seal', 'Draw on')),
          const _Section('Bulk'),
          _Btn('Dismiss all', () => toast.dismissAll()),
        ],
      ),
    );
  }

  Future<void> _runProgress() async {
    final handle = toast.raw(const Toast(
      message: 'Uploading 0%',
      icon: 'arrow.up.circle',
      duration: null,
      progress: 0,
    ));
    for (var p = 1; p <= 10; p++) {
      await Future<void>.delayed(const Duration(milliseconds: 240));
      await handle.replace(Toast(
        message: 'Uploading ${p * 10}%',
        icon: 'arrow.up.circle',
        duration: null,
        progress: p / 10,
      ));
    }
    // Keep `progress` set so the toast height stays identical at completion.
    await handle.replace(const Toast(
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
