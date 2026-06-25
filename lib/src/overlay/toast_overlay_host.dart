import 'package:flutter/widgets.dart';

import 'toast_overlay_controller.dart';
import 'widgets/toast_layer.dart';

/// Installs the toast overlay into the app's root [Overlay] **without a
/// `BuildContext`** — preserving the plugin's context-free API.
///
/// It discovers the root [OverlayState] by walking the element tree from
/// [WidgetsBinding.rootElement] (the `Navigator`/`WidgetsApp` overlay, present in
/// any `MaterialApp`/`CupertinoApp`), then inserts one persistent [OverlayEntry]
/// rendering the [ToastLayer]. A caller may instead supply an explicit overlay
/// via [useOverlay] for exotic trees.
class ToastOverlayHost {
  ToastOverlayHost(this.controller);

  final ToastOverlayController controller;

  OverlayEntry? _entry;
  bool _installed = false;
  OverlayState? _explicitOverlay;

  /// Pins the overlay to render into [overlay] instead of the discovered root.
  void useOverlay(OverlayState overlay) => _explicitOverlay = overlay;

  /// Ensures the overlay entry is inserted. Returns `true` optimistically; if the
  /// tree isn't built yet it retries after the current frame.
  bool ensureInstalled() {
    if (_installed) return true;
    final overlay = _resolveOverlay();
    if (overlay != null) {
      _install(overlay);
      return true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_installed) return;
      final retry = _resolveOverlay();
      if (retry != null) {
        _install(retry);
      } else {
        debugPrint(
          '[liquid_toasts] No Overlay found in the widget tree; toasts cannot '
          'render. Ensure a MaterialApp/CupertinoApp (or a Navigator/Overlay) '
          'is present above where toasts are shown.',
        );
      }
    });
    return true;
  }

  OverlayState? _resolveOverlay() {
    final explicit = _explicitOverlay;
    if (explicit != null && explicit.mounted) return explicit;
    return _findRootOverlay();
  }

  void _install(OverlayState overlay) {
    _entry = OverlayEntry(
      opaque: false,
      maintainState: true,
      builder: (_) => ToastLayer(controller: controller),
    );
    overlay.insert(_entry!);
    _installed = true;
  }

  OverlayState? _findRootOverlay() {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return null;
    OverlayState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is OverlayState) {
        found = element.state as OverlayState;
        return;
      }
      element.visitChildren(visit);
    }

    root.visitChildren(visit);
    return found;
  }

  void dispose() {
    _entry?.remove();
    _entry = null;
    _installed = false;
  }
}
