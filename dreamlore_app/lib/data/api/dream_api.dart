import 'package:dio/dio.dart';
import '../../core/config.dart';
import '../models.dart';

class ExplainResult {
  final Interpretation interpretation;
  final QuotaInfo? quota;
  const ExplainResult(this.interpretation, this.quota);
}

/// Talks to the proxy. Sends the anonymous device token; the proxy holds the
/// real API key and enforces quotas.
class DreamApi {
  final String deviceId;
  final Dio _dio;

  DreamApi({required this.deviceId, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: Config.apiBase,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 60),
              headers: {
                'content-type': 'application/json',
                'x-device-token': deviceId,
              },
              // Let us inspect 4xx bodies (e.g. 429) instead of throwing.
              validateStatus: (s) => s != null && s < 500,
            ));

  Future<ExplainResult> explain(String dream, {int? topK}) async {
    final Map<String, dynamic> payload = {'dream': dream};
    if (topK != null) payload['topK'] = topK;
    final res = await _dio.post('/explain', data: payload);

    if (res.statusCode == 429) {
      final d = (res.data as Map).cast<String, dynamic>();
      final err = (d['error'] ?? '').toString();
      throw QuotaExceededException(
        err.contains('month') ? 'monthly' : 'daily',
        resetsAt: d['resetsAt'] is String ? DateTime.tryParse(d['resetsAt']) : null,
        upgrade: d['upgrade'] == true,
      );
    }
    if (res.statusCode != 200) {
      final msg = res.data is Map ? (res.data['error'] ?? '') : '';
      throw Exception('Interpretation failed (${res.statusCode}) $msg');
    }

    final data = (res.data as Map).cast<String, dynamic>();
    QuotaInfo? quota;
    final q = data['quota'];
    if (q is Map) {
      quota = QuotaInfo(
        tier: (q['tier'] ?? 'free') as String,
        dayUsed: (q['day']?['used'] ?? 0) as int,
        dayLimit: (q['day']?['limit'] ?? 0) as int,
        monthUsed: (q['month']?['used'] ?? 0) as int,
        monthLimit: (q['month']?['limit'] ?? 0) as int,
      );
    }
    return ExplainResult(Interpretation.fromJson(data), quota);
  }

  Future<QuotaInfo?> usage() async {
    try {
      final res = await _dio.get('/usage');
      if (res.statusCode == 200 && res.data is Map) {
        return QuotaInfo.fromUsageJson((res.data as Map).cast<String, dynamic>());
      }
    } catch (_) {}
    return null;
  }
}
