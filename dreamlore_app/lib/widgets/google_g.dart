import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Google's four-colour "G", drawn rather than shipped as an asset so it stays
/// crisp at any size and needs no image. Proportions follow Google's own mark.
/// Used only on the "Continue with Google" button, per their branding rules.
class GoogleG extends StatelessWidget {
  final double size;
  const GoogleG({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _GPainter()),
  );
}

class _GPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2;
    final stroke = s.width * 0.22;
    final radius = r - stroke / 2;
    final rect = Rect.fromCircle(center: c, radius: radius);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    double d(double deg) => deg * math.pi / 180;
    // Four arcs around the ring, in Google's colour order.
    canvas.drawArc(rect, d(-20), d(74), false, p..color = _blue);
    canvas.drawArc(rect, d(56), d(70), false, p..color = _green);
    canvas.drawArc(rect, d(128), d(88), false, p..color = _yellow);
    canvas.drawArc(rect, d(218), d(85), false, p..color = _red);

    // The blue crossbar into the centre — the defining stroke of the G.
    final barPaint = Paint()
      ..color = _blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawLine(
      Offset(c.dx, c.dy),
      Offset(c.dx + radius + stroke / 2, c.dy),
      barPaint,
    );
    // Cap the bar's inner end flush with the ring's opening.
    canvas.drawRect(
      Rect.fromLTWH(c.dx, c.dy - stroke / 2, radius * 0.55, stroke),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

/// The "Continue with Google" button, in Google's neutral (dark) style so it
/// reads as a real sign-in control against the night ground: a near-white
/// surface would fight the palette, so this uses the dark scheme they permit —
/// a `#131314` pill with the full-colour G and Roboto-weight label.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool busy;
  const GoogleSignInButton({super.key, this.onPressed, this.busy = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF131314),
          disabledBackgroundColor: const Color(0xFF131314),
          foregroundColor: const Color(0xFFE3E3E3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFE3E3E3),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GoogleG(size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFE3E3E3),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
