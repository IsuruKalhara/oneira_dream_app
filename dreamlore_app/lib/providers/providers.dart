import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db/database.dart';
import '../data/repositories/dream_repository.dart';
import '../data/api/dream_api.dart';
import '../services/auth_service.dart';
import '../services/billing_api.dart';
import '../services/stt_service.dart';
import '../services/settings_service.dart';
import '../services/subscription_service.dart';

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

final authServiceProvider = Provider<AuthService>(
    (ref) => AuthService(ref.watch(settingsServiceProvider)));

final billingApiProvider = Provider<BillingApi>(
    (ref) => BillingApi(deviceToken: ref.watch(deviceIdProvider)));

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final s = SubscriptionService(
    settings: ref.watch(settingsServiceProvider),
    billing: ref.watch(billingApiProvider),
  );
  ref.onDispose(s.dispose);
  return s;
});

/// Whether this device has an account attached. Gates the first screen.
class SignedInController extends Notifier<bool> {
  @override
  bool build() => ref.watch(authServiceProvider).isSignedIn;

  Future<void> signInWithGoogle() async {
    await ref.read(authServiceProvider).signInWithGoogle();
    state = true;
  }

  Future<void> continueWithoutAccount() async {
    await ref.read(authServiceProvider).continueWithoutAccount();
    state = true;
  }

  Future<void> signOut() async {
    await ref.read(authServiceProvider).signOut();
    state = false;
  }

  /// Re-reads the flag after a startup reconciliation with Firebase.
  void resync() => state = ref.read(authServiceProvider).isSignedIn;
}

final signedInProvider =
    NotifierProvider<SignedInController, bool>(SignedInController.new);

/// Whether Dreamlore Plus is active, kept in step with purchases that land
/// outside a paywall tap (a startup restore, a deferred payment clearing).
class EntitlementController extends Notifier<bool> {
  @override
  bool build() {
    final service = ref.watch(subscriptionServiceProvider);
    final sub = service.entitlementChanges.listen((paid) => state = paid);
    ref.onDispose(sub.cancel);
    return service.isPaid;
  }

  Future<PurchaseOutcome> purchase(BillingPeriod period) async {
    final outcome =
        await ref.read(subscriptionServiceProvider).purchase(period);
    _sync();
    return outcome;
  }

  Future<RestoreResult> restore() async {
    final result = await ref.read(subscriptionServiceProvider).restore();
    _sync();
    return result;
  }

  Future<void> refresh() async {
    await ref.read(subscriptionServiceProvider).refresh();
    _sync();
  }

  /// The service emits on real changes; this covers the first read after an
  /// action, when the value may already have settled.
  void _sync() {
    final paid = ref.read(subscriptionServiceProvider).isPaid;
    if (state != paid) state = paid;
    // Quotas are the Worker's answer, not ours — re-ask once the entitlement
    // has moved so the record screen's banner reflects the new plan.
    ref.invalidate(quotaProvider);
  }
}

final entitlementProvider =
    NotifierProvider<EntitlementController, bool>(EntitlementController.new);

/// Live stream of saved dreams (local DB).
final dreamsStreamProvider = StreamProvider((ref) =>
    ref.watch(dreamRepositoryProvider).watchAll());

/// Current quota snapshot (for the record screen banner). Refresh after each
/// interpretation.
final quotaProvider = FutureProvider((ref) => ref.watch(dreamApiProvider).usage());

/// Which of the first-run screens the app should be showing.
enum AppStage { signIn, onboarding, paywall, main }

/// The launch gate. Each first-run screen writes its flag through
/// [SettingsService] and then calls [AppGate.recompute], rather than pushing
/// the next screen itself — so the sequence lives in one place and a user who
/// kills the app mid-flow resumes exactly where they left off.
class AppGate extends Notifier<AppStage> {
  @override
  AppStage build() {
    // Watched, so signing out or a purchase landing moves the gate on its own.
    final signedIn = ref.watch(signedInProvider);
    final paid = ref.watch(entitlementProvider);
    return _stage(signedIn: signedIn, paid: paid);
  }

  void recompute() {
    state = _stage(
      signedIn: ref.read(signedInProvider),
      paid: ref.read(entitlementProvider),
    );
  }

  AppStage _stage({required bool signedIn, required bool paid}) {
    final settings = ref.read(settingsServiceProvider);
    if (!signedIn) return AppStage.signIn;
    if (!settings.onboarded) return AppStage.onboarding;
    // Offered once, and never to someone who has already paid. Declining it
    // is a normal outcome — the free tier is a real tier.
    if (!settings.paywallSeen && !paid) return AppStage.paywall;
    return AppStage.main;
  }
}

final appGateProvider = NotifierProvider<AppGate, AppStage>(AppGate.new);
