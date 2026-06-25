import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../liquid_toasts_platform_interface.dart';
import '../liquid_toasts_config.dart';
import '../toast.dart';
import '../toast_event.dart';
import 'toast_overlay_controller.dart';
import 'toast_overlay_host.dart';

/// The cross-platform (non-iOS) implementation of [LiquidToastsPlatform].
///
/// Instead of a native overlay, it renders the same toast UI with Flutter
/// widgets in the app's root [Overlay] and reports lifecycle through the same
/// [ToastEvent] stream the facade consumes — so the facade, the wire models, and
/// every callback contract are identical across platforms. iOS keeps its native
/// `MethodChannelLiquidToasts`; this powers Android (and web/desktop).
class OverlayLiquidToasts extends LiquidToastsPlatform {
  OverlayLiquidToasts() {
    _controller = ToastOverlayController(emit: _events.add);
    _host = ToastOverlayHost(_controller);
  }

  final StreamController<ToastEvent> _events =
      StreamController<ToastEvent>.broadcast();
  late final ToastOverlayController _controller;
  late final ToastOverlayHost _host;

  /// Registered by the Flutter Dart plugin registrant (via `dartPluginClass`)
  /// on non-iOS platforms. Idempotent with the platform-interface default
  /// selection, which already picks this implementation off iOS.
  static void registerWith() {
    if (LiquidToastsPlatform.instance is! OverlayLiquidToasts) {
      LiquidToastsPlatform.instance = OverlayLiquidToasts();
    }
  }

  @override
  Future<void> handshake(String session) async {
    // A restarted isolate rebuilds the whole tree, so nothing usually lingers;
    // flushing is a safety net mirroring the native hot-restart behavior.
    _controller.flushAll();
    _host.ensureInstalled();
  }

  @override
  Future<void> configure(LiquidToastsConfig config) async {
    _controller.configure(config);
  }

  @override
  Future<bool> show(String id, Toast toast, {String? actionId}) async {
    if (!_host.ensureInstalled()) return false;
    _controller.present(id, toast, actionId);
    return true;
  }

  @override
  Future<bool> update(String id, Toast toast, {String? actionId}) async {
    return _controller.morph(id, toast, actionId);
  }

  @override
  Future<bool> dismiss(String id) async {
    return _controller.requestDismiss(id, ToastDismissReason.manual);
  }

  @override
  Future<List<String>> dismissAll() async {
    return _controller.dismissAll(ToastDismissReason.dismissAll);
  }

  @override
  Future<Map<String, dynamic>> queryGeometry() async {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final dpr = view.devicePixelRatio;
    final padding = view.padding; // physical pixels
    final size = view.physicalSize;
    final topLogical = dpr == 0 ? 0.0 : padding.top / dpr;
    return {
      'hasDynamicIsland': false,
      'cutoutType': topLogical > 40 ? 'cutout' : 'none',
      'safeArea': {
        'top': topLogical,
        'left': dpr == 0 ? 0.0 : padding.left / dpr,
        'right': dpr == 0 ? 0.0 : padding.right / dpr,
        'bottom': dpr == 0 ? 0.0 : padding.bottom / dpr,
      },
      'screen': {
        'width': dpr == 0 ? size.width : size.width / dpr,
        'height': dpr == 0 ? size.height : size.height / dpr,
        'scale': dpr,
      },
      'glassMode': 'blur',
    };
  }

  @override
  Stream<ToastEvent> get events => _events.stream;

  /// Releases the overlay entry, controller (timers + lifecycle observer), and
  /// event stream. Primarily for tests; a long-lived app never needs this.
  void dispose() {
    _host.dispose();
    _controller.dispose();
    _events.close();
  }

  /// Test hook: pin rendering to an explicit overlay (e.g. the one in a pumped
  /// `MaterialApp`).
  @visibleForTesting
  void debugUseOverlay(OverlayState overlay) => _host.useOverlay(overlay);
}
