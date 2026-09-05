import 'package:flutter/material.dart';

import '../ui/night.dart';

/// The Dreamlore mark — a crescent moon whose inner curve opens like a book —
/// as one widget, so the splash, sign-in, onboarding, and error screens all
/// show exactly the same thing. The asset is a transparent PNG rendered from
/// the vector source in `assets/brand/`; if it ever fails to load, the moon
/// disc the app already draws stands in, so the brand never disappears.
class BrandMark extends StatelessWidget {
  final double size;

  /// Optional wordmark under the mark.
  final bool withName;

  const BrandMark({super.key, this.size = 96, this.withName = false});

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      'assets/brand/mark.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => MoonDisc(size: size, phase: 0.72),
    );
    if (!withName) return mark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(height: size * 0.18),
        Text(
          'Dreamlore',
          style: Ob.serif(
            size: size * 0.3,
            weight: FontWeight.w500,
            letterSpacing: size * 0.01,
          ),
        ),
      ],
    );
  }
}
