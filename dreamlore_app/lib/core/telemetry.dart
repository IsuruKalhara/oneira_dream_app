import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'errors.dart';

/// One place that decides what leaves the device.
///
/// Two rules, and they are the reason this is a wrapper rather than calls
/// scattered through the app:
///
/// 1. **No dream content, ever.** Not the text, not the transcript, not a
///    symbol, not a title. A dream journal that leaked its contents into an
///    analytics dashboard would deserve everything that followed. Only counts,
///    durations and enum-like labels go out.
/// 2. **Silence in debug.** Collection is disabled in debug builds anyway;
///    every call here is additionally a no-op so a test run can never land in
///    the production dashboards.
class Telemetry {
  Telemetry._();

  static bool _on = !kDebugMode;

  /// Called once Firebase is up. When Firebase failed to start, everything
  /// below stays a no-op rather than throwing on a null instance.
  static void enable({required bool ready}) => _on = ready && !kDebugMode;

  static FirebaseAnalytics get _a => FirebaseAnalytics.instance;
  static FirebaseCrashlytics get _c => FirebaseCrashlytics.instance;

  // ---- analytics ----------------------------------------------------------

  static Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (!_on) return;
    try {
      await _a.logEvent(name: name, parameters: params);
    } catch (_) {
      // Telemetry must never be the reason a user-facing action fails.
    }
  }

  /// A reading completed. `elapsedMs` is what tells you whether the backend is
  /// slow for real users on real networks, which no local test will.
  static Future<void> dreamInterpreted({
    required int elapsedMs,
    required int dreamChars,
    required String tier,
  }) => _log('dream_interpreted', {
        'elapsed_ms': elapsedMs,
        // Bucketed, not exact: a length is a weak fingerprint, and knowing
        // "short/medium/long" answers every product question an exact count
        // would.
        'length_bucket': dreamChars < 200
            ? 'short'
            : dreamChars < 800
                ? 'medium'
                : 'long',
        'tier': tier,
      });

  static Future<void> dreamSaved() => _log('dream_saved');

  static Future<void> pictureGenerated({required int elapsedMs}) =>
      _log('picture_generated', {'elapsed_ms': elapsedMs});

  static Future<void> paywallShown({required String from}) =>
      _log('paywall_shown', {'from': from});

  static Future<void> quotaHit({required String period}) =>
      _log('quota_hit', {'period': period});

  static Future<void> signedIn({required String method}) =>
      _log('signed_in', {'method': method});

  static Future<void> accountDeleted() => _log('account_deleted');

  /// Screen views, so funnels are answerable without inventing custom events.
  static Future<void> screen(String name) async {
    if (!_on) return;
    try {
      await _a.logScreenView(screenName: name);
    } catch (_) {}
  }

  // ---- crash context ------------------------------------------------------

  /// Attaches the account to crash reports. Firebase's uid, never the email —
  /// enough to recognise "this user crashes every time", not enough to
  /// identify them from the dashboard.
  static Future<void> setUser(String? uid) async {
    if (!_on) return;
    try {
      await _c.setUserIdentifier(uid ?? '');
    } catch (_) {}
  }

  /// Keys ride along on every subsequent crash. Without them a stack trace
  /// says where the app broke but not what the user was doing or paying.
  static Future<void> setKey(String key, Object value) async {
    if (!_on) return;
    try {
      await _c.setCustomKey(key, value);
    } catch (_) {}
  }

  /// A failure the user survived — a timeout, a 502, a refused picture. These
  /// never crash the app, so without recording them the crash dashboard looks
  /// healthy while the product quietly fails on bad connections.
  static Future<void> recordFailure(
    Object error,
    StackTrace? stack, {
    required String during,
  }) async {
    if (!_on) return;
    try {
      final f = Friendly.of(error);
      await _c.recordError(
        error,
        stack,
        reason: '$during — ${f.title}',
        information: [
          DiagnosticsProperty<String>('during', during),
          DiagnosticsProperty<bool>('offline', f.offline),
          DiagnosticsProperty<bool>('retryable', f.retryable),
        ],
        fatal: false,
      );
    } catch (_) {}
  }
}
