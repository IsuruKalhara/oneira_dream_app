import 'package:flutter/material.dart';

/// The app's night palette, shared by onboarding and the main shell.
///
/// `AppTheme` owns the Material colour scheme; this holds the few hand-picked
/// values that scheme can't express — the warm parchment used for display type,
/// and the hairline used for rules and chrome edges. Keeping them here means
/// the nav bar and onboarding stay in step without one importing the other.
class Palette {
  const Palette._();

  /// Matches `AppTheme.scaffoldBackgroundColor`.
  static const ink = Color(0xFF0E0E1A);

  /// A deeper ink for gradient falloff and floating-chrome fills.
  static const inkDeep = Color(0xFF07070F);

  /// Warm, paper-derived. Carries display type and active chrome — the
  /// counterweight that stops the app reading as dark-with-one-bright-accent.
  static const parchment = Color(0xFFE9E1D0);

  /// Secondary text.
  static const muted = Color(0xFF9490AC);

  /// Hairline rules, card edges, inactive chrome.
  static const rule = Color(0xFF2E2A47);
}
