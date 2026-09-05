import 'package:flutter/material.dart';

import 'night.dart';

/// The app's motion vocabulary, in one place so every screen moves the same
/// way: settle-in reveals rather than pops, one easing family, and every
/// effect collapsing to nothing when the OS asks for reduced motion.
///
/// Three pieces:
///
/// * [Reveal] — a child that fades and drifts up into place, optionally on a
///   stagger, for lists of content that arrive at once (a reading, a journal).
/// * [StateSwitcher] — swaps between screen states (capture → reading → done)
///   with a fade and a short drift instead of a cut.
/// * [PressScale] — the press feedback for tappable cards and pills.
class Motion {
  const Motion._();

  static const quick = Duration(milliseconds: 220);
  static const base = Duration(milliseconds: 420);
  static const slow = Duration(milliseconds: 620);

  /// One stagger step between sibling reveals.
  static const stagger = Duration(milliseconds: 70);

  static const curve = Ob.pageCurve;

  static bool reduced(BuildContext c) => MediaQuery.disableAnimationsOf(c);
}

/// Fades and drifts [child] into place once, when it is first built.
///
/// [index] staggers siblings: each one starts [Motion.stagger] after the
/// previous. The animation runs on a single tween per widget, so a list of
/// twenty reveals costs twenty cheap builders and no controllers.
class Reveal extends StatelessWidget {
  final Widget child;
  final int index;

  /// Drift distance in logical pixels. Kept small — the point is that content
  /// settles, not that it travels.
  final double offset;
  final Duration duration;

  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 14,
    this.duration = Motion.base,
  });

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    final delay = Motion.stagger * index;
    final total = duration + delay;
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Motion.curve),
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, offset * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Cross-fades between screen states. The incoming state drifts up a touch as
/// it fades in; the outgoing one simply fades, so the two never fight for
/// attention in the middle of the transition.
class StateSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const StateSwitcher({
    super.key,
    required this.child,
    this.duration = Motion.base,
  });

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Motion.curve,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (w, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(a),
          child: w,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: child,
    );
  }
}

/// Press feedback: the child eases down to [pressedScale] while a finger is
/// on it and springs back on release. Wraps anything tappable without taking
/// over its gesture handling — the child still owns the tap.
class PressScale extends StatefulWidget {
  final Widget child;
  final double pressedScale;
  final bool enabled;

  const PressScale({
    super.key,
    required this.child,
    this.pressedScale = 0.97,
    this.enabled = true,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: _down ? const Duration(milliseconds: 90) : Motion.quick,
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
