/// App-wide configuration. Override at build/run time, e.g.:
///   flutter run --dart-define=DREAMLORE_API_BASE=https://dreamlore-proxy.YOURNAME.workers.dev
class Config {
  /// Backend `/explain` + `/usage` + `/billing/*` base URL.
  /// Defaults to a local dev server. NOTE: the Android emulator reaches the
  /// host machine at 10.0.2.2, iOS simulator at localhost — pass --dart-define
  /// accordingly when testing against a local proxy.
  static const String apiBase = String.fromEnvironment(
    'DREAMLORE_API_BASE',
    defaultValue: 'http://localhost:8787',
  );

  static const String appName = 'Dreamlore';

  /// Shown in Settings → About. Keep in step with `version:` in pubspec.yaml.
  static const String version = '1.0.0';

  /// Debug builds only: pretend this device is on Plus, so the picture flow
  /// can be exercised against a local proxy on a phone that has Play (whose
  /// startup restore would otherwise clear any entitlement). The real backend
  /// still gates pictures on its own — this cannot obtain one it would refuse.
  ///   flutter run --dart-define=DREAMLORE_DEV_PAID=true
  static const bool devPaid = bool.fromEnvironment(
    'DREAMLORE_DEV_PAID',
    defaultValue: false,
  );
  static const String privacyUrl = 'https://tropicalai.net/dreamlore/privacy';
  static const String termsUrl = 'https://tropicalai.net/dreamlore/terms';

  // ---- Subscriptions (Google Play Billing) ----
  //
  // Two products, one entitlement. Both grant the `paid` tier the Worker
  // enforces quotas against; only the price, the billing period, and the free
  // trial differ. Create them in Play Console with exactly these ids (or
  // override them here at build time) — see SHIP.md § Subscriptions.

  /// Monthly subscription product id.
  static const String monthlyProductId = String.fromEnvironment(
    'PLAY_MONTHLY_ID',
    defaultValue: 'dreamlore_plus_monthly',
  );

  /// Yearly subscription product id. This is the plan that carries the free
  /// trial, configured as an offer on its base plan in Play Console.
  static const String yearlyProductId = String.fromEnvironment(
    'PLAY_YEARLY_ID',
    defaultValue: 'dreamlore_plus_yearly',
  );

  // The free trial's length is deliberately NOT configured here. The paywall
  // reads it from the Play offer itself (SubscriptionService.trialDays), so it
  // always matches what Play Console is set to, and it correctly shows no trial
  // to someone who has already used theirs.

  /// Reference prices, USD. These are what to enter in Play Console (see
  /// SHIP.md §3) and what the paywall shows as "from …" when Play cannot
  /// supply a localized price (sideloads, no Play Services). The store's own
  /// price always wins the moment it is available, and the purchase sheet
  /// only ever quotes the store. Research, Sep 2026: DreamApp $7.99/$47.99,
  /// Dream Book $6.99/$34.99, Dream Interpreter AI $4.99/mo — Plus sits under
  /// all three, and yearly reads as $2.50 a month.
  static const String referenceMonthlyPrice = r'$4.99';
  static const String referenceYearlyPrice = r'$29.99';
  static const String referenceYearlyPerMonth = r'$2.50';

  /// The tier name the Worker grants a subscriber (see worker/src/index.js).
  static const String paidTier = 'paid';

  /// Where "Manage subscription" sends the user. Play's own subscription
  /// centre is the only place a Play subscription can be cancelled.
  static const String manageSubscriptionsUrl =
      'https://play.google.com/store/account/subscriptions';

  // ---- Sign-in (Firebase Auth + Google Sign-In) ----

  /// Web (type 3) OAuth client id from the Firebase project — required on
  /// Android so Google Sign-In returns an `idToken` that Firebase Auth can
  /// verify. Without it, release builds typically fail right after the account
  /// picker. Found in Firebase console → Project settings → Web client.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
}
