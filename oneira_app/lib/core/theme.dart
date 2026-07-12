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
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF0E0E1A)
          : scheme.surface,
      textTheme: Typography.material2021(platform: TargetPlatform.iOS)
          .black
          .apply(
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
          )
          .let((t) => brightness == Brightness.dark
              ? Typography.material2021().white.apply(
                    bodyColor: scheme.onSurface,
                    displayColor: scheme.onSurface,
                  )
              : t),
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

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
