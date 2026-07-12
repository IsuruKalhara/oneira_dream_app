import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// A stable, anonymous per-install identifier sent to the proxy as the
/// X-Device-Token (used for quota + subscription entitlement lookup). Not PII.
Future<String> getOrCreateDeviceId(SharedPreferences prefs) async {
  const key = 'device_id';
  final existing = prefs.getString(key);
  if (existing != null && existing.isNotEmpty) return existing;
  final id = const Uuid().v4();
  await prefs.setString(key, id);
  return id;
}
