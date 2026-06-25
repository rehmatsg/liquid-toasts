import 'package:flutter/widgets.dart';

import '../../toast_position.dart';
import '../toast_overlay_controller.dart';
import 'toast_card.dart';

/// The root of the overlay: arranges live toasts into the seven positions and
/// stacks each position vertically — the cross-platform port of the SwiftUI
/// `ToastContainerView`. Empty regions don't hit-test, so touches pass straight
/// through to the app below; only the toast cards are interactive.
class ToastLayer extends StatelessWidget {
  const ToastLayer({super.key, required this.controller});

  final ToastOverlayController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final toasts = controller.toasts;
        return SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Stack(
            children: [
              for (final position in ToastPosition.values)
                ..._buildPosition(
                  position,
                  toasts.where((t) => t.toast.position == position).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildPosition(ToastPosition position, List<LiveToast> items) {
    if (items.isEmpty) return const [];

    // Top positions render newest-on-top (reversed); bottom/center keep newest
    // at the bottom — matching the iOS stacking order.
    final ordered = position.isTop ? items.reversed.toList() : items;

    final children = <Widget>[];
    for (var i = 0; i < ordered.length; i++) {
      if (i > 0) children.add(const SizedBox(height: 10));
      final live = ordered[i];
      children.add(ToastCard(
        key: ObjectKey(live),
        live: live,
        controller: controller,
      ));
    }

    return [
      Align(
        alignment: _alignmentFor(position),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: _crossAxisFor(position),
          children: children,
        ),
      ),
    ];
  }

  AlignmentDirectional _alignmentFor(ToastPosition position) {
    switch (position) {
      case ToastPosition.topCenter:
        return AlignmentDirectional.topCenter;
      case ToastPosition.topLeading:
        return AlignmentDirectional.topStart;
      case ToastPosition.topTrailing:
        return AlignmentDirectional.topEnd;
      case ToastPosition.center:
        return AlignmentDirectional.center;
      case ToastPosition.bottomCenter:
        return AlignmentDirectional.bottomCenter;
      case ToastPosition.bottomLeading:
        return AlignmentDirectional.bottomStart;
      case ToastPosition.bottomTrailing:
        return AlignmentDirectional.bottomEnd;
    }
  }

  CrossAxisAlignment _crossAxisFor(ToastPosition position) {
    switch (position) {
      case ToastPosition.topLeading:
      case ToastPosition.bottomLeading:
        return CrossAxisAlignment.start;
      case ToastPosition.topTrailing:
      case ToastPosition.bottomTrailing:
        return CrossAxisAlignment.end;
      case ToastPosition.topCenter:
      case ToastPosition.center:
      case ToastPosition.bottomCenter:
        return CrossAxisAlignment.center;
    }
  }
}
