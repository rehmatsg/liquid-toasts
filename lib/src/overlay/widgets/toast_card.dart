import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../../toast_position.dart';
import '../../toast_style.dart';
import '../sf_symbol_icons.dart';
import '../toast_overlay_controller.dart';
import '../toast_springs.dart';
import 'toast_action_button.dart';
import 'toast_glass.dart';
import 'toast_icon.dart';

/// One toast on the overlay. Owns its entrance (spring slide + scale + fade),
/// exit (scale + fade + blur), and swipe-to-dismiss — the cross-platform port of
/// the SwiftUI `ToastView`. Keyed by its [LiveToast] instance so a `groupKey`
/// morph keeps the same state (no re-entrance).
class ToastCard extends StatefulWidget {
  const ToastCard({
    super.key,
    required this.live,
    required this.controller,
  });

  final LiveToast live;
  final ToastOverlayController controller;

  @override
  State<ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<ToastCard> with TickerProviderStateMixin {
  late final AnimationController _enter =
      AnimationController.unbounded(vsync: this);
  late final AnimationController _exit =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  late final AnimationController _drag = AnimationController.unbounded(vsync: this);

  double _dragDy = 0;
  bool _swipingOut = false;
  bool _exitStarted = false;
  bool _entered = false;

  bool get _dismissUpward => widget.live.toast.position.isTop;

  @override
  void initState() {
    super.initState();
    _exit.addStatusListener(_onExitDone);
    _drag.addListener(() => setState(() => _dragDy = _drag.value));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entered) return;
    _entered = true;
    if (widget.live.phase == ToastPhase.exiting) {
      _maybeStartExit();
      return;
    }
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _enter.value = 1;
    } else {
      _enter.animateWith(SpringSimulation(ToastSprings.entrance, 0, 1, 0));
    }
  }

  @override
  void didUpdateWidget(ToastCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeStartExit();
  }

  void _maybeStartExit() {
    if (_exitStarted || widget.live.phase != ToastPhase.exiting) return;
    _exitStarted = true;
    if (_swipingOut) return; // the fling animation finishes the exit itself
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _exit.duration = Duration(milliseconds: reduceMotion ? 120 : 220);
    _exit.forward(from: 0);
  }

  void _onExitDone(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.controller.onExitComplete(widget.live.id);
    }
  }

  // --- Swipe ---

  void _onDragStart(DragStartDetails _) {
    _drag.stop();
    HapticFeedback.selectionClick();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    var dy = _dragDy + d.delta.dy;
    final wrongDirection = _dismissUpward ? dy > 0 : dy < 0;
    if (wrongDirection) dy *= 0.35; // rubber-band resistance away from the edge
    setState(() => _dragDy = dy);
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0; // px/s
    final predicted = _dragDy + velocity * 0.15;
    final correctDir =
        _dismissUpward ? (_dragDy < 0 || velocity < 0) : (_dragDy > 0 || velocity > 0);
    final shouldDismiss =
        correctDir && (_dragDy.abs() > 28 || predicted.abs() > 140);
    if (shouldDismiss) {
      _flingOut(velocity);
    } else {
      _bounceBack(velocity);
    }
  }

  void _flingOut(double velocity) {
    _swipingOut = true;
    HapticFeedback.mediumImpact();
    widget.controller.handleSwipeDismiss(widget.live);
    final height = MediaQuery.of(context).size.height;
    _drag
      ..value = _dragDy
      ..addStatusListener(_onFlingDone);
    _drag.animateTo(
      _dismissUpward ? -height : height,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeIn,
    );
  }

  void _onFlingDone(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _drag.removeStatusListener(_onFlingDone);
      widget.controller.onExitComplete(widget.live.id);
    }
  }

  void _bounceBack(double velocity) {
    _drag.value = _dragDy;
    _drag.animateWith(SpringSimulation(ToastSprings.bounceBack, _dragDy, 0, velocity));
  }

  @override
  void dispose() {
    _enter.dispose();
    _exit.dispose();
    _drag.dispose();
    super.dispose();
  }

  double _enterDistance(MediaQueryData mq) {
    final pos = widget.live.toast.position;
    if (pos.isTop) return -math.max(16.0, mq.padding.top * 0.5);
    if (pos.isBottom) return math.max(16.0, mq.padding.bottom * 0.5);
    return 16.0;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final mq = MediaQuery.of(context);
    final enterOffset = _enterDistance(mq);
    final content = _buildContent(context, brightness, mq);

    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onTap: () => widget.controller.handleTap(widget.live),
      onVerticalDragStart: _onDragStart,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: AnimatedBuilder(
        animation: Listenable.merge([_enter, _exit]),
        child: content,
        builder: (context, child) {
          final ec = _enter.value.clamp(0.0, 1.0);
          double scale;
          double opacity;
          double blurSigma;
          double translateY;

          if (_exitStarted && !_swipingOut) {
            final ex = _exit.value;
            scale = lerpDouble(1.0, 0.86, ex)!;
            opacity = (1 - ex).clamp(0.0, 1.0);
            blurSigma = 9 * ex;
            translateY = _dragDy;
          } else {
            scale = lerpDouble(0.9, 1.0, _enter.value)!;
            opacity = ec;
            blurSigma = 0;
            translateY = lerpDouble(enterOffset, 0.0, ec)! + _dragDy;
            if (_dragDy != 0) {
              opacity *= (1 - (_dragDy.abs() / 220)).clamp(0.0, 1.0);
            }
          }

          Widget result = child!;
          if (blurSigma > 0) {
            result = ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: result,
            );
          }
          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, translateY),
              child: Transform.scale(scale: scale, child: result),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, Brightness brightness, MediaQueryData mq) {
    final toast = widget.live.toast;
    final dark = brightness == Brightness.dark;
    Color? pick(ToastColor? c) => c == null ? null : (dark ? c.dark : c.light);

    final fg = pick(toast.style?.foreground) ??
        (dark ? Colors.white : Colors.black.withValues(alpha: 0.9));
    final accent = pick(toast.style?.tint) ??
        SfSymbolIcons.semanticTint(toast.semantic, brightness) ??
        fg;
    final showIcon = toast.loading || SfSymbolIcons.resolve(toast) != null;

    final textChildren = <Widget>[
      if (toast.title != null)
        Text(
          toast.title!,
          style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 15),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      Text(
        toast.message,
        style: TextStyle(
          color: toast.title != null ? fg.withValues(alpha: 0.85) : fg,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        maxLines: toast.maxLines,
        overflow: TextOverflow.ellipsis,
      ),
      if (toast.progress != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: SizedBox(
            width: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: toast.progress!.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: fg.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
        ),
    ];

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showIcon) ...[
          ToastIconView(toast: toast, brightness: brightness),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: textChildren,
          ),
        ),
        if (toast.action != null) ...[
          const SizedBox(width: 12),
          ToastActionButton(
            action: toast.action!,
            brightness: brightness,
            onPressed: () => widget.controller.handleAction(widget.live),
          ),
        ],
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: math.min(mq.size.width - 24, 460)),
      child: GlassBackground(
        brightness: brightness,
        cornerRadius: toast.style?.cornerRadius,
        glass: toast.style?.glass,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 11, toast.action != null ? 11 : 16, 11),
          child: row,
        ),
      ),
    );
  }
}
