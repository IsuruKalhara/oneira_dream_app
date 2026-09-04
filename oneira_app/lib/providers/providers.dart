import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db/database.dart';
import '../data/repositories/dream_repository.dart';
import '../data/api/dream_api.dart';
import '../services/stt_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../services/purchase_service.dart';

/// Overridden in main() after async init.
final sharedPreferencesProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());
final deviceIdProvider = Provider<String>((ref) => throw UnimplementedError());

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final dreamRepositoryProvider = Provider<DreamRepository>(
    (ref) => DreamRepository(ref.watch(databaseProvider)));

final dreamApiProvider = Provider<DreamApi>(
    (ref) => DreamApi(deviceId: ref.watch(deviceIdProvider)));

final sttServiceProvider = Provider<SttService>((ref) {
  final s = SttService();
  ref.onDispose(s.dispose);
  return s;
});

final settingsServiceProvider = Provider<SettingsService>(
    (ref) => SettingsService(ref.watch(sharedPreferencesProvider)));

final purchaseServiceProvider =
    Provider<PurchaseService>((ref) => PurchaseService());

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

/// Live stream of saved dreams (local DB).
final dreamsStreamProvider = StreamProvider((ref) =>
    ref.watch(dreamRepositoryProvider).watchAll());

/// Current quota snapshot (for the record screen banner). Refresh after each
/// interpretation.
final quotaProvider = FutureProvider((ref) => ref.watch(dreamApiProvider).usage());
