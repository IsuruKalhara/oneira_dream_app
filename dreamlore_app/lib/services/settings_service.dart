import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  final SharedPreferences prefs;
  SettingsService(this.prefs);

  static const _onboarded = 'onboarded';
  static const _reminder = 'reminder_enabled';
  static const _signedIn = 'signed_in';
  static const _userEmail = 'user_email';
  static const _userName = 'user_name';
  static const _paywallSeen = 'paywall_seen';
  static const _entTier = 'entitlement_tier';
  static const _entExpiry = 'entitlement_expiry_ms';
  static const _entToken = 'entitlement_purchase_token';

  bool get onboarded => prefs.getBool(_onboarded) ?? false;
  Future<void> setOnboarded(bool v) => prefs.setBool(_onboarded, v);

  bool get reminderEnabled => prefs.getBool(_reminder) ?? false;
  Future<void> setReminderEnabled(bool v) => prefs.setBool(_reminder, v);

  /// Whether the first-run paywall has already been shown. It is offered once,
  /// after onboarding; declining it must not put the user back in front of it
  /// on every launch.
  bool get paywallSeen => prefs.getBool(_paywallSeen) ?? false;
  Future<void> setPaywallSeen(bool v) => prefs.setBool(_paywallSeen, v);

  // ---- account ----

  bool get signedIn => prefs.getBool(_signedIn) ?? false;
  String get userEmail => prefs.getString(_userEmail) ?? '';
  String get userName => prefs.getString(_userName) ?? '';

  Future<void> setAccount({required String email, String name = ''}) async {
    await prefs.setBool(_signedIn, true);
    await prefs.setString(_userEmail, email);
    await prefs.setString(_userName, name);
  }

  Future<void> clearAccount() async {
    await prefs.remove(_signedIn);
    await prefs.remove(_userEmail);
    await prefs.remove(_userName);
  }

  // ---- entitlement cache ----
  //
  // A cache of what the server last verified with Google Play, never a source
  // of truth on its own. It always carries the paid-through date, so a
  // cancelled or refunded subscription actually lapses on this device instead
  // of living forever.

  String get tierName => prefs.getString(_entTier) ?? 'free';
  int get entitlementExpiryMs => prefs.getInt(_entExpiry) ?? 0;
  String get entitlementPurchaseToken => prefs.getString(_entToken) ?? '';

  Future<void> setEntitlement({
    required String tierName,
    required int expiryMs,
    required String purchaseToken,
  }) async {
    await prefs.setString(_entTier, tierName);
    await prefs.setInt(_entExpiry, expiryMs);
    await prefs.setString(_entToken, purchaseToken);
  }

  Future<void> clearEntitlement() async {
    await prefs.remove(_entTier);
    await prefs.remove(_entExpiry);
    await prefs.remove(_entToken);
  }
}
