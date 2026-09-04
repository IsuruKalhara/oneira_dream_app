import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'night.dart';

/// Card-and-pill vocabulary, in the idiom of Moonly's bento onboarding:
/// centred bold sans headlines, rounded cards carrying the imagery, small
/// translucent pill labels floating on top, and a warm-white pill CTA.
///
/// Replaces the hairline-and-eyebrow print vocabulary of the previous pass.

/// Centred, bold, sans. The headline style for every step.
class BigTitle extends StatelessWidget {
  final String text;
  const BigTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 30,
            height: 1.22,
            fontWeight: FontWeight.w700,
            color: Ob.parchment,
            letterSpacing: -0.4,
          ),
        ),
      );
}

/// Centred supporting line under a [BigTitle].
class Sub extends StatelessWidget {
  final String text;
  const Sub(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          height: 1.5,
          color: Ob.muted,
        ),
      );
}

/// Small translucent label that sits on a card, Moonly-style.
class PillLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const PillLabel({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Ob.inkDeep.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Ob.parchment,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded bento tile. [label] floats at the chosen corner over [child].
class BentoCard extends StatelessWidget {
  final double height;
  final Widget child;
  final PillLabel? label;
  final Alignment labelAlignment;
  final String semanticsLabel;

  /// Varies the generated nebula wash behind [child] so no two tiles in a grid
  /// share the same colour character — the job Moonly's photography does.
  final int seed;

  const BentoCard({
    super.key,
    required this.height,
    required this.child,
    required this.semanticsLabel,
    this.label,
    this.labelAlignment = Alignment.topLeft,
    this.seed = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: NebulaFill(seed: seed)),
            Positioned.fill(child: child),
            if (label != null)
              Align(
                alignment: labelAlignment,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: label!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Two-column bento with staggered heights — the composition Moonly uses to
/// keep a four-tile grid from reading as a plain 2×2.
class BentoGrid extends StatelessWidget {
  final Widget topLeft, bottomLeft, topRight, bottomRight;

  const BentoGrid({
    super.key,
    required this.topLeft,
    required this.bottomLeft,
    required this.topRight,
    required this.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    // Tile heights live on each [BentoCard]. The grid deliberately does not
    // re-declare them: when it did, its outer SizedBox silently won and the
    // card's own height was ignored, clipping content that fit on paper.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [topLeft, const SizedBox(height: 12), bottomLeft],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [topRight, const SizedBox(height: 12), bottomRight],
          ),
        ),
      ],
    );
  }
}

/// Selectable option, as a rounded card rather than a ruled row.
class OptionCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const OptionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: selected
              ? primary.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              constraints: const BoxConstraints(minHeight: 62),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? primary.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.07),
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15.5,
                        height: 1.35,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? Ob.parchment : Ob.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? primary : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? primary
                            : Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            size: 15, color: Ob.ink)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact rounded row — the card equivalent of an icon-and-text line.
class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color? tint;

  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: '$title. $body',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Ob.parchment,
                      )),
                  const SizedBox(height: 4),
                  Text(body,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: Ob.muted,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The warm-white pill CTA. Moonly's is pure white; parchment keeps it in the
/// app's palette without going generic.
class PrimaryPill extends StatelessWidget {
  final String label;
  final String? sub;
  final VoidCallback? onPressed;
  final bool busy;

  const PrimaryPill({
    super.key,
    required this.label,
    this.sub,
    this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Ob.parchment,
        foregroundColor: Ob.ink,
        // Disabled reads as an empty card, not as washed-out parchment —
        // a dimmed fill looked like a broken button rather than an inactive one.
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
        disabledForegroundColor: Ob.muted,
        minimumSize: const Size.fromHeight(60),
        shape: const StadiumBorder(),
      ),
      child: busy
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: Ob.ink),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 16.5, fontWeight: FontWeight.w700)),
                if (sub != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    sub!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Ob.ink.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Dark companion pill, used beside [PrimaryPill] as Moonly's Skip / Next pair.
class GhostPill extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const GhostPill({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.06),
        foregroundColor: Ob.muted,
        minimumSize: const Size.fromHeight(60),
        shape: StadiumBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
        ),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Generated card imagery
// ─────────────────────────────────────────────────────────────────────────────

/// Soft blurred colour blobs behind a card's content — generated rather than
/// imported, so every tile gets its own character at no asset weight and any
/// resolution. Deterministic per [seed] so a card never re-rolls on rebuild.
class NebulaFill extends StatelessWidget {
  final int seed;
  const NebulaFill({super.key, this.seed = 0});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _NebulaPainter(seed: seed, primary: primary),
      ),
    );
  }
}

class _NebulaPainter extends CustomPainter {
  final int seed;
  final Color primary;
  const _NebulaPainter({required this.seed, required this.primary});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed * 7919 + 13);
    // Hue-shifted relatives of the brand indigo, so tiles vary without
    // introducing colours that belong to no one.
    final hsl = HSLColor.fromColor(primary);
    final blobs = [
      hsl.withHue((hsl.hue + 18) % 360).toColor(),
      hsl.withHue((hsl.hue - 26) % 360).withLightness(0.42).toColor(),
      hsl.withHue((hsl.hue + 46) % 360).withSaturation(0.5).toColor(),
    ];

    for (var i = 0; i < blobs.length; i++) {
      final cx = (0.15 + rnd.nextDouble() * 0.7) * size.width;
      final cy = (0.10 + rnd.nextDouble() * 0.8) * size.height;
      final r = (0.38 + rnd.nextDouble() * 0.42) * size.shortestSide;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = blobs[i].withValues(alpha: 0.30 - i * 0.06)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.75),
      );
    }

    // Downward vignette so pill labels always sit on a legible ground.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Ob.inkDeep.withValues(alpha: 0.45),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_NebulaPainter old) =>
      old.seed != seed || old.primary != primary;
}

/// Three moons at different phases — the direct analog of Moonly's
/// "Moon's Influence" tile, using the same painter that drives onboarding
/// progress, so the app has one moon rather than two different ones.
class MoonCluster extends StatelessWidget {
  const MoonCluster({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Sizes are fractions of `unit`; the lowest moon bottoms out at 0.60
        // of it. Clamping against height as well as width stops the cluster
        // overflowing when the measure widens on tablets and in landscape.
        final unit = math.min(c.maxWidth, c.maxHeight / 0.60);
        return Stack(
          children: [
            Positioned(
              left: unit * 0.04,
              top: unit * 0.30,
              child: MoonDisc(size: unit * 0.30, phase: 0.22),
            ),
            Positioned(
              left: unit * 0.30,
              top: unit * 0.06,
              child: MoonDisc(size: unit * 0.46, phase: 0.95),
            ),
            Positioned(
              right: unit * 0.02,
              top: unit * 0.34,
              child: MoonDisc(size: unit * 0.26, phase: 0.55),
            ),
          ],
        );
      },
    );
  }
}
