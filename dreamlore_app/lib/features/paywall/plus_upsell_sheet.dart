import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'paywall_screen.dart';

/// What a free user sees when they tap a Plus feature. The preview behind the
/// glass is the point: a blurred picture that is *almost* there is a stronger
/// pull than any list of benefits — it shows the thing rather than describing
/// it, and leaving it unseen costs something. Everything else is calm: one
/// primary action, one honest "maybe later", no timers, no fake discounts.
class PlusUpsellSheet extends StatelessWidget {
  const PlusUpsellSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => const PlusUpsellSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 4, 24, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BlurredPreview(),
          const SizedBox(height: 20),
          Text('See your dream', style: t.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Plus turns each dream into a picture — painted from your own '
            'words, saved with the entry, yours to keep.',
            style: t.textTheme.bodyMedium
                ?.copyWith(color: t.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _check(t, 'A picture of every dream you log'),
          _check(t, 'More readings every day, and deeper ones'),
          _check(t, 'Full symbol trends across your journal'),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
              );
            },
            child: const Text('Unlock with Plus'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe later'),
          ),
        ],
      ),
    );
  }

  Widget _check(ThemeData t, String s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 18, color: t.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(s, style: t.textTheme.bodyMedium)),
          ],
        ),
      );
}

/// A dream-coloured painting you can't quite make out, with a lock resting on
/// the glass. It breathes: scales in on arrival, then a slow glow pulse.
class _BlurredPreview extends StatefulWidget {
  const _BlurredPreview();
  @override
  State<_BlurredPreview> createState() => _BlurredPreviewState();
}

class _BlurredPreviewState extends State<_BlurredPreview>
    with TickerProviderStateMixin {
  late final _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520))
    ..forward();
  late final _pulse = AnimationController(
      vsync: this, duration: const Duration(seconds: 3))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scale = CurvedAnimation(parent: _enter, curve: Curves.easeOutBack);
    return ScaleTransition(
      scale: Tween(begin: 0.9, end: 1.0).animate(scale),
      child: FadeTransition(
        opacity: _enter,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: t.colorScheme.primary
                      .withValues(alpha: 0.25 + 0.2 * _pulse.value),
                  blurRadius: 28 + 12 * _pulse.value,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // A plausible dream: moon, water, a figure — as shapes only,
                  // so the blur has something to hide.
                  CustomPaint(painter: _DreamPainter(t.colorScheme)),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: ColoredBox(
                      color: t.colorScheme.surface.withValues(alpha: 0.12),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.colorScheme.surface.withValues(alpha: 0.75),
                      ),
                      child: Icon(Icons.lock_outline,
                          color: t.colorScheme.onSurface),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: t.colorScheme.primary,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text('PLUS',
                          style: t.textTheme.labelSmall?.copyWith(
                            color: t.colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          )),
                    ),
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

class _DreamPainter extends CustomPainter {
  _DreamPainter(this.c);
  final ColorScheme c;

  @override
  void paint(Canvas canvas, Size s) {
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF1B1A3A), c.primary.withValues(alpha: 0.6)],
      ).createShader(Offset.zero & s);
    canvas.drawRect(Offset.zero & s, sky);
    // moon
    canvas.drawCircle(Offset(s.width * 0.72, s.height * 0.28), s.height * 0.16,
        Paint()..color = const Color(0xFFF3E9C6));
    // water
    canvas.drawRect(
        Rect.fromLTWH(0, s.height * 0.62, s.width, s.height * 0.38),
        Paint()..color = c.tertiary.withValues(alpha: 0.55));
    // hills
    final hill = Path()
      ..moveTo(0, s.height * 0.66)
      ..quadraticBezierTo(s.width * 0.3, s.height * 0.42, s.width * 0.55, s.height * 0.62)
      ..lineTo(0, s.height * 0.62)
      ..close();
    canvas.drawPath(hill, Paint()..color = const Color(0xFF2A2757));
    // figure
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(s.width * 0.42, s.height * 0.66),
            width: s.height * 0.1,
            height: s.height * 0.3),
        Paint()..color = const Color(0xFF15142B));
    // stars
    final star = Paint()..color = Colors.white.withValues(alpha: 0.8);
    final r = math.Random(7);
    for (var i = 0; i < 18; i++) {
      canvas.drawCircle(
          Offset(r.nextDouble() * s.width, r.nextDouble() * s.height * 0.5),
          1.2 + r.nextDouble() * 1.4,
          star);
    }
  }

  @override
  bool shouldRepaint(_DreamPainter old) => old.c != c;
}
