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
