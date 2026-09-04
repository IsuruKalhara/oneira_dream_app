import 'package:purchases_flutter/purchases_flutter.dart';
import '../core/config.dart';

/// Thin RevenueCat wrapper. Degrades gracefully when no key is configured, so
/// the app runs end-to-end before subscriptions are set up.
class PurchaseService {
  bool _configured = false;
  bool get configured => _configured;

  Future<void> init() async {
    if (Config.revenueCatApiKey.isEmpty) return;
    try {
      await Purchases.configure(
        PurchasesConfiguration(Config.revenueCatApiKey),
      );
      _configured = true;
    } catch (_) {
      _configured = false;
    }
  }

  Future<bool> isPaid() async {
    if (!_configured) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(Config.paidEntitlement);
    } catch (_) {
      return false;
    }
  }

  Future<List<Package>> packages() async {
    if (!_configured) return const [];
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.availablePackages ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<bool> purchase(Package package) async {
    if (!_configured) return false;
    try {
      // ignore: deprecated_member_use
      final result = await Purchases.purchasePackage(package);
      return result.customerInfo.entitlements.active
          .containsKey(Config.paidEntitlement);
    } catch (_) {
      return false;
    }
  }

  Future<bool> restore() async {
    if (!_configured) return false;
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(Config.paidEntitlement);
    } catch (_) {
      return false;
    }
  }
}
