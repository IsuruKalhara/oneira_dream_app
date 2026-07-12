/// App-wide configuration. Override the API base at build/run time, e.g.:
///   flutter run --dart-define=ONEIRA_API_BASE=https://oneira-proxy.YOURNAME.workers.dev
class Config {
  /// Backend `/explain` + `/usage` base URL.
  /// Defaults to a local dev server. NOTE: the Android emulator reaches the
  /// host machine at 10.0.2.2, iOS simulator at localhost — pass --dart-define
  /// accordingly when testing against a local proxy.
  static const String apiBase = String.fromEnvironment(
    'ONEIRA_API_BASE',
    defaultValue: 'http://localhost:8787',
  );

  /// RevenueCat public SDK key (leave empty to run without subscriptions;
  /// the paywall then shows a "coming soon" state instead of crashing).
  static const String revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_KEY',
    defaultValue: '',
  );

  /// The entitlement identifier configured in RevenueCat for the paid tier.
  static const String paidEntitlement = 'paid';

  static const String appName = 'Oneira';
  static const String privacyUrl = 'https://tropicalai.net/oneira/privacy';
  static const String termsUrl = 'https://tropicalai.net/oneira/terms';
}
