import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Dark-first, calm night palette — the app is used half-asleep at dawn.
class AppTheme {
  static const _seed = Color(0xFF6C5CE7); // soft indigo

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // DM Sans everywhere by default; Ob.serif reaches for Newsreader where
      // the content is the point (the dream, quotes, display lines).
      fontFamily: 'DM Sans',
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF0E0E1A)
          : scheme.surface,
      // Material's typography names Roboto on every style, which would win
      // over the theme-level family — so the family is applied to the text
      // theme itself.
      textTheme:
          (brightness == Brightness.dark
                  ? Typography.material2021().white
                  : Typography.material2021(platform: TargetPlatform.iOS).black)
              .apply(
                fontFamily: 'DM Sans',
                bodyColor: scheme.onSurface,
                displayColor: scheme.onSurface,
              ),
      // Forward navigation fades and drifts (Material's 2025+ default) rather
      // than the old zoom; iOS keeps its native edge-swipe stack.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkSparkle.splashFactory,
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
