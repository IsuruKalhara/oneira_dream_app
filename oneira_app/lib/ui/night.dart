import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/palette.dart';

/// Visual language for onboarding: **print, rendered at night**.
///
/// The product's claim is that it quotes real books rather than inventing an
/// answer, so the first run borrows the vernacular of one — a title page, a
/// letterspaced eyebrow, hairline rules, italic book titles — and sets it on a
/// luminous night field. Warm parchment carries the display type; the indigo
/// brand colour is demoted to structural accents so the screen doesn't read as
/// a generic dark-app-with-one-bright-accent.
///
/// Used by every screen — nothing here mutates [AppTheme]; it adds the few
/// values the Material scheme can't express.
class Ob {
  const Ob._();

  // ── Palette (shared with the main shell — see core/palette.dart) ─────────
  static const ink = Palette.ink;
  static const inkDeep = Palette.inkDeep;
  static const parchment = Palette.parchment;
  static const muted = Palette.muted;
  static const rule = Palette.rule;

  // ── Motion ────────────────────────────────────────────────────────────────
  /// Slow and settled rather than snappy — the app is used half-asleep.
  static const pageCurve = Cubic(0.22, 1.0, 0.36, 1.0);
  static const pageDuration = Duration(milliseconds: 520);

  // ── Layout ────────────────────────────────────────────────────────────────
  /// Content never stretches past a comfortable measure on tablets.
  static const maxContentWidth = 520.0;

  static bool isShort(BuildContext c) => MediaQuery.sizeOf(c).height < 720;
  static bool isLandscape(BuildContext c) =>
      MediaQuery.orientationOf(c) == Orientation.landscape;

  /// Constrains and centres content so it stays readable on any width.
  static Widget measure({required Widget child}) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      );

  // ── Type ──────────────────────────────────────────────────────────────────
  // No font files ship with the app. 'Georgia' exists on iOS and most Android
  // OEM images; 'New York' is the iOS system serif; generic 'serif' resolves to
  // Noto Serif on Android. Worst case a platform serif renders — verified on an
  // Android emulator, where Noto Serif picks it up cleanly.
  static const _serifStack = <String>[
    'New York',
    'Times New Roman',
    'Times',
    'serif',
  ];

  static TextStyle serif({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = parchment,
    double height = 1.15,
    double letterSpacing = 0,
    FontStyle style = FontStyle.normal,
  }) =>
      TextStyle(
        fontFamily: 'Georgia',
        fontFamilyFallback: _serifStack,
        fontSize: size,
        fontWeight: weight,
        fontStyle: style,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// Letterspaced uppercase label. Extends the eyebrow style already used by
  /// `InterpretationView`, so onboarding and the reading share a house style.
  static TextStyle eyebrow(BuildContext context, {Color? color}) =>
      Theme.of(context).textTheme.labelSmall!.copyWith(
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
            color: color ?? Theme.of(context).colorScheme.primary,
          );

  static TextStyle body(BuildContext context, {Color color = muted}) =>
      Theme.of(context).textTheme.bodyLarge!.copyWith(color: color, height: 1.55);
}

/// Hairline rule — the recurring structural device.
class Hairline extends StatelessWidget {
  final double width;
  const Hairline({super.key, this.width = double.infinity});

  @override
  Widget build(BuildContext context) =>
      Container(width: width, height: 1, color: Ob.rule);
}

// ─────────────────────────────────────────────────────────────────────────────
// Ambient night field
// ─────────────────────────────────────────────────────────────────────────────

/// The luminous ground everything sits on: a soft indigo bloom plus a slow
/// drifting, twinkling starfield. Replaces a flat black rectangle, which is
/// what made the first pass read as unfinished.
///
/// Deterministic (fixed seed) so it never flickers between rebuilds, capped at
/// a modest star count, isolated behind a [RepaintBoundary], and frozen
/// entirely when the OS asks for reduced motion.
class NightCanvas extends StatefulWidget {
  final Widget child;
  const NightCanvas({super.key, required this.child});

  @override
  State<NightCanvas> createState() => _NightCanvasState();
}

class _NightCanvasState extends State<NightCanvas>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _starCount = 44;

  // One full drift wrap. The drift term is `(dy + t) % 1.0`, so the t=1 -> 0
  // loop is seamless ONLY because the coefficient of t is an integer — the
  // previous 0.12 coefficient made every star jump 12% of the screen height
  // once per cycle.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 750),
  );

  /// Painting is driven by this, not by the raw controller: stars drift
  /// imperceptibly slowly, so repainting them at display rate (and re-running
  /// the nav bar's backdrop blur every frame) was pure battery burn. ~12fps is
  /// indistinguishable for this effect.
  final ValueNotifier<double> _frame = ValueNotifier(0);
  double _lastPainted = 0;

  late final List<_Star> _stars = _seedStars();

  bool _configured = false;

  static List<_Star> _seedStars() {
    final rnd = math.Random(0xDECAF); // fixed seed -> stable across rebuilds
    return List.generate(_starCount, (_) {
      return _Star(
        dx: rnd.nextDouble(),
        dy: rnd.nextDouble(),
        radius: 0.5 + rnd.nextDouble() * 1.4,
        opacity: 0.16 + rnd.nextDouble() * 0.5,
        phase: rnd.nextDouble() * math.pi * 2,
      );
    });
  }

  void _onTick() {
    final t = _drift.value;
    // Wrap-aware elapsed seconds since the last painted frame.
    final elapsed = ((t - _lastPainted + 1) % 1) * 750;
    if (elapsed >= 0.08) {
      _lastPainted = t;
      _frame.value = t;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configured) return;
    _configured = true;
    WidgetsBinding.instance.addObserver(this);
    if (!MediaQuery.disableAnimationsOf(context)) {
      _drift.addListener(_onTick);
      _drift.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No visible surface, no animation — the sky doesn't need to turn while
    // the app is backgrounded.
    if (_configured && !MediaQuery.disableAnimationsOf(context)) {
      if (state == AppLifecycleState.resumed) {
        if (!_drift.isAnimating) _drift.repeat();
      } else {
        _drift.stop();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _drift.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.75),
          radius: 1.25,
          colors: [
            Color.alphaBlend(primary.withValues(alpha: 0.13), Ob.ink),
            Ob.ink,
            Ob.inkDeep,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: ValueListenableBuilder<double>(
              valueListenable: _frame,
              builder: (_, t, _) => CustomPaint(
                painter: _StarPainter(stars: _stars, t: t),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Star {
  final double dx, dy, radius, opacity, phase;
  const _Star({
    required this.dx,
    required this.dy,
    required this.radius,
    required this.opacity,
    required this.phase,
  });
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final double t;
  const _StarPainter({required this.stars, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in stars) {
      // Drift downward and wrap — like the sky turning, not like snow.
      // Integer t-coefficients keep both terms continuous across t=1 -> 0.
      final y = ((s.dy + t) % 1.0) * size.height;
      final x = s.dx * size.width;
      final twinkle = 0.65 + 0.35 * math.sin(t * math.pi * 2 * 25 + s.phase);
      paint.color = Ob.parchment.withValues(alpha: s.opacity * twinkle);
      canvas.drawCircle(Offset(x, y), s.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Moon-phase progress
// ─────────────────────────────────────────────────────────────────────────────

/// Progress rendered as a waxing moon: new at the first step, full at the last.
///
/// Borrowed from Moonly's moon-phase date row, but load-bearing here rather
/// than decorative — it is the only progress indicator, it is the brand mark,
/// and it is the one thing on screen that moves when you advance. A phase alone
/// isn't legible as "step 3 of 5", so the count sits beneath it in words.
class MoonPhaseIndicator extends StatelessWidget {
  final int step; // 0-based
  final int total;
  final double size;

  const MoonPhaseIndicator({
    super.key,
    required this.step,
    required this.total,
    this.size = 68,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    // Start at a sliver rather than a true new moon so step 1 isn't a void.
    final target = 0.12 + (step / (total - 1)) * 0.88;

    return Semantics(
      label: 'Step ${step + 1} of $total',
      liveRegion: true,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: target, end: target),
            duration: Ob.pageDuration,
            curve: Ob.pageCurve,
            builder: (_, phase, _) =>
                MoonDisc(size: size, phase: phase, glow: primary),
          ),
          SizedBox(height: size * 0.18),
          Text(
            'STEP ${step + 1} OF $total',
            style: Ob.eyebrow(context, color: Ob.muted),
          ),
        ],
      ),
    );
  }
}

/// A single moon at a given [phase] (0 = new, 1 = full). Shared by the
/// onboarding progress indicator and the bento imagery, so there is exactly
/// one moon in the app rather than two that drift apart.
class MoonDisc extends StatelessWidget {
  final double size;
  final double phase;
  final Color? glow;

  const MoonDisc({
    super.key,
    required this.size,
    required this.phase,
    this.glow,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _MoonPainter(
          phase: phase,
          glow: glow ?? Theme.of(context).colorScheme.primary,
        ),
      );
}

class _MoonPainter extends CustomPainter {
  /// 0 = new, 1 = full.
  final double phase;
  final Color glow;

  const _MoonPainter({required this.phase, required this.glow});

  // Fixed so the moon looks like the same body every time it is drawn.
  static const _craters = <({double dx, double dy, double r, double a})>[
    (dx: -0.28, dy: -0.30, r: 0.17, a: 0.10),
    (dx: 0.16, dy: -0.12, r: 0.10, a: 0.08),
    (dx: -0.10, dy: 0.30, r: 0.22, a: 0.07),
    (dx: 0.34, dy: 0.28, r: 0.12, a: 0.06),
    (dx: 0.02, dy: -0.44, r: 0.08, a: 0.06),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);

    // Halo — the luminosity that makes it read as lit rather than drawn.
    canvas.drawCircle(
      c,
      r * 1.6,
      Paint()
        ..shader = RadialGradient(
          colors: [glow.withValues(alpha: 0.34 * phase), Colors.transparent],
          stops: const [0.42, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.6)),
    );

    // Body in shadow. Always drawn, so the dark limb still reads as a sphere
    // rather than a shape that partly ceases to exist.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [Ob.rule, Ob.rule.withValues(alpha: 0.35)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // ── Lit sphere ──────────────────────────────────────────────────────────
    canvas.saveLayer(Rect.fromCircle(center: c, radius: r * 1.1), Paint());

    // Sphere shading: brightest toward the lit limb, falling off across the
    // face. This is what separates a rendered sphere from a flat disc.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.35, -0.35),
          radius: 0.95,
          colors: [
            Colors.white,
            Ob.parchment,
            Color.alphaBlend(Ob.rule.withValues(alpha: 0.55), Ob.parchment),
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Craters, clipped to the disc.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    for (final k in _craters) {
      canvas.drawCircle(
        Offset(c.dx + k.dx * r, c.dy + k.dy * r),
        k.r * r,
        Paint()
          ..color = const Color(0xFF6B6480).withValues(alpha: k.a)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, k.r * r * 0.5),
      );
    }
    canvas.restore();

    // Terminator: erase with an offset disc, softened so the shadow edge is a
    // gradient rather than a cut. At phase 0 it sits dead-centre (new); at 1 it
    // is tangent (full); at 0.5 it covers the left half, lighting the right.
    canvas.drawCircle(
      Offset(c.dx - phase * 2 * r, c.dy),
      r,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.06),
    );

    canvas.restore();

    // Rim light along the lit edge, fading as the moon fills.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - 0.5),
      -math.pi / 2.6,
      math.pi * 0.78,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: 0.32 * (1 - phase * 0.55)),
    );
  }

  @override
  bool shouldRepaint(_MoonPainter old) =>
      old.phase != phase || old.glow != glow;
}

/// A glossy sphere in the Moonly idiom — base gradient, specular highlight,
/// rim light — rendered rather than imported, so it scales to any size and
/// tints from the theme.
class Orb extends StatelessWidget {
  final double size;
  final Color color;
  final IconData? icon;
  final bool lit;

  const Orb({
    super.key,
    required this.size,
    required this.color,
    this.icon,
    this.lit = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _OrbPainter(color: color, lit: lit),
          child: icon == null
              ? null
              : Center(
                  child: Icon(
                    icon,
                    size: size * 0.36,
                    color: lit ? Ob.ink : color,
                  ),
                ),
        ),
      );
}

class _OrbPainter extends CustomPainter {
  final Color color;
  final bool lit;
  const _OrbPainter({required this.color, required this.lit});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);

    canvas.drawCircle(
      c,
      r * 1.55,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: lit ? 0.34 : 0.16), Colors.transparent],
          stops: const [0.45, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.55)),
    );

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.1,
          colors: lit
              ? [Colors.white, color, Color.alphaBlend(Ob.ink.withValues(alpha: 0.45), color)]
              : [
                  color.withValues(alpha: 0.30),
                  color.withValues(alpha: 0.12),
                  Ob.ink.withValues(alpha: 0.30),
                ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Rim light — the cue that sells it as a sphere rather than a circle.
    canvas.drawCircle(
      c,
      r - 0.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: lit ? 0.55 : 0.32),
            Colors.transparent,
            color.withValues(alpha: 0.35),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Specular highlight.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx - r * 0.34, c.dy - r * 0.42),
        width: r * 0.62,
        height: r * 0.40,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: lit ? 0.42 : 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.18),
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) => old.color != color || old.lit != lit;
}

// ─────────────────────────────────────────────────────────────────────────────
// Entrance motion
// ─────────────────────────────────────────────────────────────────────────────

/// Staggered fade-and-rise, replayed whenever [step] changes so every screen
/// arrives with the same composure — not just the first.
class Stagger extends StatefulWidget {
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  /// Whether this page is the one on screen. PageView builds neighbours ahead
  /// of time, so without this the entrance would play out of sight and the
  /// page would be already-settled by the time you swipe to it.
  final bool active;

  const Stagger({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.active = true,
  });

  @override
  State<Stagger> createState() => _StaggerState();
}

class _StaggerState extends State<Stagger> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  bool _configured = false;

  void _play() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configured) return;
    _configured = true;
    // Built while off-screen: stay hidden until this page is actually shown.
    if (widget.active) {
      _play();
    } else {
      _c.value = 0;
    }
  }

  @override
  void didUpdateWidget(Stagger old) {
    super.didUpdateWidget(old);
    // Play the entrance when a page becomes active. Deliberately do NOTHING
    // when it deactivates: `active` flips at the START of the page transition,
    // and zeroing the controller here blanked the outgoing page for the whole
    // 520ms slide. Re-activating replays from 0, which covers the
    // return-to-page case the old reset was for.
    if (widget.active && !old.active) _play();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.children.length;
    return Column(
      crossAxisAlignment: widget.crossAxisAlignment,
      children: [
        for (var i = 0; i < n; i++)
          // Intervals spread across a fixed 0–0.55 window rather than a
          // per-index step, so the last child keeps its full runway however
          // many spacers sit in the list.
          _StaggerItem(
            controller: _c,
            begin: n <= 1 ? 0 : (i / (n - 1)) * 0.55,
            child: widget.children[i],
          ),
      ],
    );
  }
}

class _StaggerItem extends StatelessWidget {
  final AnimationController controller;
  final double begin;
  final Widget child;

  const _StaggerItem({
    required this.controller,
    required this.begin,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, begin + 0.45, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position:
            Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(curve),
        child: child,
      ),
    );
  }
}
