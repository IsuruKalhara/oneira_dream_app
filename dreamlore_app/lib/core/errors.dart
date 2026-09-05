import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// One place that turns whatever went wrong into words a half-awake person
/// can act on. Every error surface in the app (record, pictures, journal,
/// sign-in, startup) asks here rather than printing `e.toString()`.
///
/// The shape is always the same — what happened, what to do — and the tone is
/// calm: an error is a direction, not an alarm. Technical detail is kept out of
/// the copy; Crashlytics gets the stack, the user gets the next step.
class Friendly {
  final String title;
  final String body;
  final IconData icon;

  /// True when trying again is likely to work (network, timeouts, 5xx).
  final bool retryable;

  /// True when the cause is the device being offline.
  final bool offline;

  const Friendly({
    required this.title,
    required this.body,
    required this.icon,
    this.retryable = true,
    this.offline = false,
  });

  static const _offline = Friendly(
    title: "You're offline",
    body:
        'Your dream is still here. Connect to the internet and try again — '
        'nothing you wrote is lost.',
    icon: Icons.wifi_off_rounded,
    offline: true,
  );

  static const _slow = Friendly(
    title: 'The library is slow right now',
    body: 'It took too long to answer. Give it a moment and try again.',
    icon: Icons.hourglass_bottom_rounded,
  );

  static const _server = Friendly(
    title: 'The library is closed for a moment',
    body:
        "Something went wrong on our side, not yours. It's usually back "
        'within a few minutes.',
    icon: Icons.nightlight_round,
  );

  static const _unknown = Friendly(
    title: 'Something went sideways',
    body:
        'Please try again. If it keeps happening, restarting the app '
        'usually clears it.',
    icon: Icons.error_outline_rounded,
  );

  /// Maps any thrown object to a [Friendly].
  static Friendly of(Object? error) {
    if (error is Friendly) return error;
    if (error is SocketException) return _offline;
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionError:
          return _offline;
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return _slow;
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode ?? 0;
          if (code >= 500) return _server;
          return _unknown;
        default:
          final inner = error.error;
          if (inner is SocketException) return _offline;
          return _unknown;
      }
    }
    final s = error.toString();
    // Exceptions the API client raises with the proxy's status in the text.
    if (RegExp(r'\((5\d\d)\)').hasMatch(s)) return _server;
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return _offline;
    }
    if (s.contains('Timeout')) return _slow;
    return _unknown;
  }
}
