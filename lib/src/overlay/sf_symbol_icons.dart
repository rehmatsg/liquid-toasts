import 'package:flutter/material.dart';

import '../toast.dart';
import '../toast_style.dart';

/// Resolves a toast's icon for the Flutter overlay.
///
/// The wire format carries an SF Symbol name (iOS-native), which has no direct
/// Android/web/desktop equivalent. This maps the common symbols to Material
/// icons and otherwise falls back to the [ToastSemantic]-derived default —
/// mirroring how iOS derives a default symbol from the semantic. Unmapped,
/// non-semantic symbols resolve to `null` (no icon) rather than guessing.
class SfSymbolIcons {
  SfSymbolIcons._();

  /// The Material icon for [toast], or `null` when there is no icon to show.
  static IconData? resolve(Toast toast) {
    final name = toast.icon;
    if (name != null) {
      final mapped = _map[name];
      if (mapped != null) return mapped;
      // An explicit-but-unmapped symbol still prefers the semantic default.
      return _semanticIcon(toast.semantic);
    }
    return _semanticIcon(toast.semantic);
  }

  /// The default tint for [semantic] resolved against [brightness], matching the
  /// iOS system-color palette. Returns `null` for [ToastSemantic.none].
  static Color? semanticTint(ToastSemantic semantic, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    switch (semantic) {
      case ToastSemantic.success:
        return dark ? const Color(0xFF30D158) : const Color(0xFF34C759);
      case ToastSemantic.error:
        return dark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30);
      case ToastSemantic.warning:
        return dark ? const Color(0xFFFF9F0A) : const Color(0xFFFF9500);
      case ToastSemantic.info:
        return dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
      case ToastSemantic.none:
        return null;
    }
  }

  static IconData? _semanticIcon(ToastSemantic semantic) {
    switch (semantic) {
      case ToastSemantic.success:
        return Icons.check_circle_rounded;
      case ToastSemantic.error:
        return Icons.cancel_rounded;
      case ToastSemantic.warning:
        return Icons.warning_amber_rounded;
      case ToastSemantic.info:
        return Icons.info_rounded;
      case ToastSemantic.none:
        return null;
    }
  }

  /// Common SF Symbol → Material icon mappings. Intentionally small and
  /// high-confidence; extend as needed.
  static const Map<String, IconData> _map = {
    // Semantic-ish
    'checkmark': Icons.check_rounded,
    'checkmark.circle': Icons.check_circle_outline_rounded,
    'checkmark.circle.fill': Icons.check_circle_rounded,
    'checkmark.seal.fill': Icons.verified_rounded,
    'xmark': Icons.close_rounded,
    'xmark.circle': Icons.cancel_outlined,
    'xmark.circle.fill': Icons.cancel_rounded,
    'xmark.octagon.fill': Icons.dangerous_rounded,
    'exclamationmark.triangle': Icons.warning_amber_rounded,
    'exclamationmark.triangle.fill': Icons.warning_rounded,
    'exclamationmark.circle': Icons.error_outline_rounded,
    'exclamationmark.circle.fill': Icons.error_rounded,
    'info.circle': Icons.info_outline_rounded,
    'info.circle.fill': Icons.info_rounded,
    'questionmark.circle': Icons.help_outline_rounded,
    // Common UI
    'bell': Icons.notifications_none_rounded,
    'bell.fill': Icons.notifications_rounded,
    'star': Icons.star_border_rounded,
    'star.fill': Icons.star_rounded,
    'heart': Icons.favorite_border_rounded,
    'heart.fill': Icons.favorite_rounded,
    'trash': Icons.delete_outline_rounded,
    'trash.fill': Icons.delete_rounded,
    'bookmark': Icons.bookmark_border_rounded,
    'bookmark.fill': Icons.bookmark_rounded,
    'paperplane': Icons.send_outlined,
    'paperplane.fill': Icons.send_rounded,
    'arrow.down': Icons.arrow_downward_rounded,
    'arrow.up': Icons.arrow_upward_rounded,
    'arrow.down.circle': Icons.download_rounded,
    'arrow.up.circle': Icons.upload_rounded,
    'arrow.clockwise': Icons.refresh_rounded,
    'square.and.arrow.up': Icons.ios_share_rounded,
    'square.and.arrow.down': Icons.save_alt_rounded,
    'doc.on.doc': Icons.copy_rounded,
    'link': Icons.link_rounded,
    'gearshape': Icons.settings_rounded,
    'gearshape.fill': Icons.settings_rounded,
    'person': Icons.person_outline_rounded,
    'person.fill': Icons.person_rounded,
    'lock': Icons.lock_outline_rounded,
    'lock.fill': Icons.lock_rounded,
    'lock.open': Icons.lock_open_rounded,
    'wifi': Icons.wifi_rounded,
    'wifi.slash': Icons.wifi_off_rounded,
    'bolt': Icons.bolt_rounded,
    'bolt.fill': Icons.bolt_rounded,
    'bolt.slash': Icons.flash_off_rounded,
    'cloud': Icons.cloud_outlined,
    'cloud.fill': Icons.cloud_rounded,
    'envelope': Icons.mail_outline_rounded,
    'envelope.fill': Icons.mail_rounded,
    'cart': Icons.shopping_cart_outlined,
    'cart.fill': Icons.shopping_cart_rounded,
    'magnifyingglass': Icons.search_rounded,
    'hand.thumbsup': Icons.thumb_up_off_alt_rounded,
    'hand.thumbsup.fill': Icons.thumb_up_rounded,
  };
}
