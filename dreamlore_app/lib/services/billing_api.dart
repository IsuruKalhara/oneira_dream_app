import 'package:dio/dio.dart';

import '../core/config.dart';

/// A verified entitlement as decided by the server, never by the client.
class VerifiedEntitlement {
  const VerifiedEntitlement({
    required this.tierName,
    required this.expiryMs,
    this.state = '',
  });

  const VerifiedEntitlement.free()
      : tierName = 'free',
        expiryMs = 0,
        state = '';

  final String tierName;

  /// Epoch millis this entitlement is paid through; 0 when there is none.
  final int expiryMs;

  /// Play's own subscription state, for diagnostics
  /// (e.g. `SUBSCRIPTION_STATE_IN_GRACE_PERIOD`).
  final String state;

  bool get isEntitled => tierName != 'free';

  factory VerifiedEntitlement.fromJson(Map<dynamic, dynamic> json) =>
      VerifiedEntitlement(
        tierName: json['tier'] as String? ?? 'free',
        expiryMs: (json['expiryMs'] as num?)?.toInt() ?? 0,
        state: json['state'] as String? ?? '',
      );
}

/// Thrown when the server could not be reached or could not decide. Callers
/// must not read this as "no entitlement" — someone offline keeps what they
/// already paid for until their cached expiry passes.
class BillingVerificationUnavailable implements Exception {
  const BillingVerificationUnavailable(this.message);
  final String message;
  @override
  String toString() => 'BillingVerificationUnavailable: $message';
}

/// Client for the proxy's `/billing/*` routes, which check purchases against
/// the Google Play Developer API. Purchases are verified server-side so a
/// tampered app can lie to its own UI but not to our model budget.
class BillingApi {
  BillingApi({required this.deviceToken, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: Config.apiBase,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'content-type': 'application/json',
                'x-device-token': deviceToken,
              },
            ));

  final Dio _dio;
  final String deviceToken;

  /// Verifies a Play purchase token and returns the entitlement it grants.
  Future<VerifiedEntitlement> verify({
    required String productId,
    required String purchaseToken,
  }) =>
      _post('/billing/verify', {
        'productId': productId,
        'purchaseToken': purchaseToken,
      });

  /// Re-reads the entitlement the server last verified for this device, so a
  /// lapsed subscription is noticed even with no purchase token to hand.
  Future<VerifiedEntitlement> state() => _post('/billing/state', const {});

  Future<VerifiedEntitlement> _post(
      String path, Map<String, Object?> body) async {
    try {
      final res = await _dio.post(path, data: body);
      final data = res.data;
      if (data is! Map) {
        throw const BillingVerificationUnavailable('Malformed server response');
      }
      return VerifiedEntitlement.fromJson(data);
    } on DioException catch (e) {
      final data = e.response?.data;
      throw BillingVerificationUnavailable(
        data is Map ? '${data['error'] ?? e.message}' : '${e.message}',
      );
    }
  }
}
