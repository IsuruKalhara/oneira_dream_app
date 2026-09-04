import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart'
    show PricingPhaseWrapper, ReplacementMode;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../core/config.dart';
import 'billing_api.dart';
import 'settings_service.dart';

/// How Dreamlore Plus is billed. The entitlement is identical either way —
/// only the price, the billing period, and (for yearly) the free trial differ.
enum BillingPeriod { monthly, yearly }

/// What actually happened when the user bought something.
enum PurchaseOutcome {
  /// Paid and entitled right now.
  activated,

  /// Accepted by Play but takes effect at the end of the current period — what
  /// a downgrade does, so the user keeps the plan they already paid for.
  scheduled,

  /// Play hasn't finished processing (deferred payment methods, slow cards).
  /// The entitlement arrives on its own later; nothing more to do here.
  pending,
}

/// Outcome of a restore attempt, so the UI can tell "welcome back" apart from
/// "there was nothing to restore" instead of claiming success either way.
class RestoreResult {
  const RestoreResult({required this.entitled});
  final bool entitled;
}

/// Thrown when the user backs out of the native Play sheet — not a real error,
/// callers should treat it as a no-op.
class PurchaseCancelledException implements Exception {
  const PurchaseCancelledException();
}

/// Thrown when Play accepted the purchase but hasn't confirmed payment yet.
class PurchasePendingException implements Exception {
  const PurchasePendingException();
}

/// Any other billing failure, carrying a message safe to log (not to show
/// verbatim — the UI has its own wording).
class BillingException implements Exception {
  const BillingException(this.message);
  final String message;
  @override
  String toString() => 'BillingException: $message';
}

/// Subscriptions via Google Play Billing (Google's official `in_app_purchase`
/// plugin — no third-party billing service). Requires the two subscription
/// products from [Config] to exist in Play Console, and only resolves real
/// products when the app is installed via Play (Internal Testing or higher).
///
/// Entitlements are decided by the server, not here: every purchase token goes
/// to `/billing/verify`, which asks the Play Developer API what it is worth.
/// What's stored on the device is a cache of that answer, always with the
/// paid-through date, so a cancelled or refunded subscription actually ends.
class SubscriptionService {
  SubscriptionService({
    required SettingsService settings,
    required BillingApi billing,
    InAppPurchase? iap,
  })  : _settings = settings,
        _billing = billing,
        _iap = iap ?? InAppPurchase.instance {
    _sub = _iap.purchaseStream.listen(_enqueue, onError: (_) {});
  }

  /// Guard against a completer leaking if Play never answers. Generous,
  /// because the user may sit on the payment sheet for a long time.
  static const _purchaseTimeout = Duration(minutes: 15);
  static const _restoreTimeout = Duration(seconds: 20);

  /// How long a purchase is honoured locally when the verification server
  /// can't be reached. The user has paid; stranding them is worse than a short
  /// provisional grant, and the Worker independently enforces its own quotas
  /// regardless of what the app believes.
  static const _unverifiedGrace = Duration(hours: 24);

  final SettingsService _settings;
  final BillingApi _billing;
  final InAppPurchase _iap;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final _entitlementChanges = StreamController<bool>.broadcast();

  /// Serializes purchase-stream events; the plugin does not await our handler.
  Future<void> _queue = Future<void>.value();

  final Map<String, List<ProductDetails>> _offers = {};
  bool _productsAvailable = false;

  /// The subscription Play says this user currently owns, needed to build a
  /// plan change instead of a second, conflicting purchase.
  GooglePlayPurchaseDetails? _ownedPurchase;

  Completer<PurchaseOutcome>? _pendingPurchase;
  String? _pendingProductId;
  Completer<List<PurchaseDetails>>? _restoreCompleter;

  /// True while the cached entitlement is still paid through.
  bool get isPaid =>
      _settings.tierName == Config.paidTier &&
      _settings.entitlementExpiryMs > DateTime.now().millisecondsSinceEpoch;

  /// Emits whenever the entitlement changes, including changes that arrive on
  /// their own (a startup restore, a deferred purchase clearing while the app
  /// is open). The UI listens to this rather than re-reading a snapshot.
  Stream<bool> get entitlementChanges => _entitlementChanges.stream;

  /// True once the store is reachable and our products resolved.
  bool get productsAvailable => _productsAvailable;

  /// Loads store products so prices can be shown. Safe to call repeatedly.
  Future<void> loadProducts() async {
    if (_productsAvailable && _offers.isNotEmpty) return;
    if (!await _iap.isAvailable()) {
      _productsAvailable = false;
      return;
    }

    final response = await _iap.queryProductDetails({
      Config.monthlyProductId,
      Config.yearlyProductId,
    });

    _offers.clear();
    for (final product in response.productDetails) {
      _offers.putIfAbsent(product.id, () => []).add(product);
    }
    _productsAvailable = _offers.isNotEmpty;
  }

  /// The store's own localized, formatted *recurring* price (e.g. "£2.99",
  /// "₹249.00"), or null before products have loaded. Never substitute a
  /// constant: the user is billed in their own currency, and quoting a
  /// hardcoded figure would be both wrong and against Play's rules.
  ///
  /// This is deliberately not `ProductDetails.price`. For a subscription the
  /// plugin takes that from the offer's *first* pricing phase, which on the
  /// trial offer is the free phase — so `price` reads "Free" or "US$0.00" and
  /// quoting it would tell the user a year costs nothing.
  String? priceLabel(BillingPeriod period) {
    final offer = _offerFor(period);
    if (offer == null) return null;
    return _recurringPhase(offer)?.formattedPrice ?? offer.price;
  }

  /// The store's raw decimal price and currency symbol for the recurring
  /// phase, for derived figures only (a per-month equivalent, a savings
  /// percentage). Never shown as a price by itself — [priceLabel] is the
  /// store's own formatting and stays the only thing quoted as a price.
  ({double amount, String symbol})? priceParts(BillingPeriod period) {
    final offer = _offerFor(period);
    if (offer == null) return null;
    final phase = _recurringPhase(offer);
    if (phase == null) {
      return (amount: offer.rawPrice, symbol: offer.currencySymbol);
    }
    return (
      amount: phase.priceAmountMicros / 1000000.0,
      symbol: _symbolOf(phase.formattedPrice) ?? phase.priceCurrencyCode,
    );
  }

  /// How many days of free trial Play will actually give *this* user on this
  /// plan, or null if there is none.
  ///
  /// Read from the offer rather than assumed, because it is the honest answer
  /// in both directions: it reflects whatever the Play Console offer says, and
  /// it disappears by itself for someone who has already used their trial —
  /// Play simply stops returning the trial offer to them.
  int? trialDays(BillingPeriod period) {
    final offer = _offerFor(period);
    if (offer == null) return null;
    final phase = _trialPhase(offer);
    if (phase == null) return null;
    return _daysInPeriod(phase.billingPeriod);
  }

  /// The phase the user goes on paying, i.e. the last one. A trial or
  /// introductory phase always precedes it.
  PricingPhaseWrapper? _recurringPhase(ProductDetails product) {
    final phases = _phasesOf(product);
    return phases == null || phases.isEmpty ? null : phases.last;
  }

  /// The leading free phase, if this offer opens with one.
  PricingPhaseWrapper? _trialPhase(ProductDetails product) {
    final phases = _phasesOf(product);
    if (phases == null || phases.length < 2) return null;
    final first = phases.first;
    return first.priceAmountMicros == 0 ? first : null;
  }

  List<PricingPhaseWrapper>? _phasesOf(ProductDetails product) {
    if (product is! GooglePlayProductDetails) return null;
    final index = product.subscriptionIndex;
    final offers = product.productDetails.subscriptionOfferDetails;
    if (index == null || offers == null || index >= offers.length) return null;
    return offers[index].pricingPhases;
  }

  /// ISO-8601 billing periods, as Play writes them: P3D, P1W, P1M, P1Y.
  int? _daysInPeriod(String iso) {
    final m = RegExp(r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$')
        .firstMatch(iso);
    if (m == null) return null;
    final years = int.tryParse(m.group(1) ?? '') ?? 0;
    final months = int.tryParse(m.group(2) ?? '') ?? 0;
    final weeks = int.tryParse(m.group(3) ?? '') ?? 0;
    final days = int.tryParse(m.group(4) ?? '') ?? 0;
    final total = years * 365 + months * 30 + weeks * 7 + days;
    return total > 0 ? total : null;
  }

  /// Pulls the currency symbol out of a formatted price, the same way the
  /// plugin does for the first phase — everything that isn't a digit, a
  /// separator, or whitespace.
  String? _symbolOf(String formattedPrice) {
    final symbol =
        formattedPrice.replaceAll(RegExp(r'[\d.,\s\u00a0]'), '').trim();
    return symbol.isEmpty ? null : symbol;
  }

  /// Picks the offer to actually buy for a [period], deterministically.
  ///
  /// On Android a subscription resolves to one [ProductDetails] per base plan
  /// *and per offer*, so taking `.first` picks whichever the store happened to
  /// list first. We sort by the headline (first-phase) price and take the
  /// cheapest, which is precisely the offer that opens with a free trial when
  /// the user is eligible for one, and the plain base plan when they are not.
  /// What gets *displayed* is the recurring phase — see [priceLabel].
  ProductDetails? _offerFor(BillingPeriod period) {
    final offers = _offers[_productIdFor(period)];
    if (offers == null || offers.isEmpty) return null;
    final sorted = [...offers]..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    return sorted.first;
  }

  String _productIdFor(BillingPeriod period) => period == BillingPeriod.yearly
      ? Config.yearlyProductId
      : Config.monthlyProductId;

  bool _isOurProduct(String productId) =>
      productId == Config.monthlyProductId ||
      productId == Config.yearlyProductId;

  Future<PurchaseOutcome> purchase(BillingPeriod period) async {
    if (_pendingPurchase != null) {
      throw const BillingException('A purchase is already in progress.');
    }

    await loadProducts();
    if (!_productsAvailable) {
      throw const BillingException(
        'Google Play Billing is unavailable. Install the app via Play '
        '(even Internal Testing) to make purchases.',
      );
    }

    final product = _offerFor(period);
    if (product == null) {
      throw BillingException(
        'Product "${_productIdFor(period)}" was not found. Check it exists, '
        'is active, and matches Config in Play Console.',
      );
    }

    // Changing plans is a replacement, not a new purchase — without this Play
    // rejects the flow outright with "item already owned".
    final owned = _ownedPurchase;
    final isChange = owned != null && owned.productID != product.id;
    // Yearly → monthly commits less money, so it waits for the period already
    // paid for to run out rather than charging again now.
    final isDowngrade = isChange &&
        owned.productID == Config.yearlyProductId &&
        product.id == Config.monthlyProductId;

    final param = GooglePlayPurchaseParam(
      productDetails: product,
      // Ties the purchase to the same identity the Worker meters by, so a
      // token can be matched to the device that bought it.
      applicationUserName: _billing.deviceToken,
      changeSubscriptionParam: isChange
          ? ChangeSubscriptionParam(
              oldPurchaseDetails: owned,
              replacementMode: isDowngrade
                  ? ReplacementMode.deferred
                  : ReplacementMode.chargeProratedPrice,
            )
          : null,
    );

    final completer = Completer<PurchaseOutcome>();
    _pendingPurchase = completer;
    _pendingProductId = product.id;
    try {
      final started = await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) {
        throw const BillingException('Could not start the purchase.');
      }

      // A deferred downgrade produces no new purchase event — Play applies it
      // at the next renewal — so waiting here would hang until the timeout.
      if (isDowngrade) return PurchaseOutcome.scheduled;

      return await completer.future.timeout(
        _purchaseTimeout,
        onTimeout: () => throw const PurchasePendingException(),
      );
    } finally {
      _pendingPurchase = null;
      _pendingProductId = null;
    }
  }

  /// Picks up entitlement changes made elsewhere — another device, the Play
  /// subscription centre, or a renewal that simply didn't happen.
  Future<void> refresh() async {
    if (!await _iap.isAvailable()) {
      // Play is out of reach (emulator, sideload, no Play Services). Fall back
      // to the server's record so a lapsed subscription is still noticed.
      await _syncFromServer();
      return;
    }

    final completer = Completer<List<PurchaseDetails>>();
    _restoreCompleter = completer;
    try {
      await _iap.restorePurchases();
      final delivered = await completer.future.timeout(_restoreTimeout);
      final owned = delivered.where(_isOwned).toList();
      if (owned.isEmpty) {
        // Play knows of no active subscription for this account. This is the
        // signal that a cancellation or refund has taken effect.
        _ownedPurchase = null;
        await _settings.clearEntitlement();
        _emit();
      }
    } on TimeoutException {
      // Keep the last known entitlement; it still carries its own expiry.
    } catch (_) {
      // Transient store failure — same reasoning.
    } finally {
      _restoreCompleter = null;
    }
  }

  Future<RestoreResult> restore() async {
    await refresh();
    return RestoreResult(entitled: isPaid);
  }

  /// Re-reads the entitlement the server last verified, used when Play itself
  /// can't be queried. Never upgrades on its own beyond what was verified.
  Future<void> _syncFromServer() async {
    try {
      final verified = await _billing.state();
      if (verified.isEntitled) {
        await _settings.setEntitlement(
          tierName: verified.tierName,
          expiryMs: verified.expiryMs,
          purchaseToken: _settings.entitlementPurchaseToken,
        );
      } else {
        await _settings.clearEntitlement();
      }
      _emit();
    } on BillingVerificationUnavailable {
      // Offline: the cached entitlement stands until its expiry passes.
    }
  }

  bool _isOwned(PurchaseDetails p) =>
      p.status == PurchaseStatus.purchased ||
      p.status == PurchaseStatus.restored;

  /// The plugin doesn't await our listener, so events are chained onto a queue
  /// — otherwise two updates could interleave mid-verification.
  void _enqueue(List<PurchaseDetails> purchases) {
    _queue = _queue.then((_) => _process(purchases)).catchError((_) {});
  }

  Future<void> _process(List<PurchaseDetails> purchases) async {
    try {
      for (final purchase in purchases) {
        await _handle(purchase);
      }
    } finally {
      final restore = _restoreCompleter;
      if (restore != null && !restore.isCompleted) {
        _restoreCompleter = null;
        restore.complete(purchases);
      }
    }
  }

  Future<void> _handle(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        // Payment is still clearing. Do not finish the transaction — Play
        // sends another update once it resolves either way.
        _failPending(purchase, const PurchasePendingException());

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await _verifyAndApply(purchase);
        await _finish(purchase);
        _resolvePending(purchase, PurchaseOutcome.activated);

      case PurchaseStatus.canceled:
        await _finish(purchase);
        _failPending(purchase, const PurchaseCancelledException());

      case PurchaseStatus.error:
        await _finish(purchase);
        _failPending(
          purchase,
          BillingException(purchase.error?.message ?? 'The purchase failed.'),
        );
    }
  }

  /// Acknowledges the transaction with the store. Play auto-refunds anything
  /// left unacknowledged for three days, so this runs for failed and cancelled
  /// transactions too — leaving those unfinished wedges the queue and blocks
  /// every later purchase.
  Future<void> _finish(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _iap.completePurchase(purchase);
    } catch (_) {
      // Retried automatically the next time Play redelivers the purchase.
    }
  }

  Future<void> _verifyAndApply(PurchaseDetails purchase) async {
    if (purchase is GooglePlayPurchaseDetails) _ownedPurchase = purchase;
    final token = purchase.verificationData.serverVerificationData;

    try {
      final verified = await _billing.verify(
        productId: purchase.productID,
        purchaseToken: token,
      );
      if (verified.isEntitled) {
        await _settings.setEntitlement(
          tierName: verified.tierName,
          expiryMs: verified.expiryMs,
          purchaseToken: token,
        );
      } else {
        await _settings.clearEntitlement();
      }
    } on BillingVerificationUnavailable {
      // Couldn't reach the verifier. Honour the purchase provisionally rather
      // than taking money and showing "Free"; it re-verifies within a day.
      if (_isOurProduct(purchase.productID)) {
        await _settings.setEntitlement(
          tierName: Config.paidTier,
          expiryMs:
              DateTime.now().add(_unverifiedGrace).millisecondsSinceEpoch,
          purchaseToken: token,
        );
      }
    }
    _emit();
  }

  void _resolvePending(PurchaseDetails purchase, PurchaseOutcome outcome) {
    final completer = _pendingPurchase;
    if (completer == null || completer.isCompleted) return;
    if (_pendingProductId != null && _pendingProductId != purchase.productID) {
      // An unrelated purchase (e.g. one redelivered at startup) must not
      // resolve the flow the user is actually waiting on.
      return;
    }
    completer.complete(outcome);
  }

  void _failPending(PurchaseDetails purchase, Object error) {
    final completer = _pendingPurchase;
    if (completer == null || completer.isCompleted) return;
    if (_pendingProductId != null && _pendingProductId != purchase.productID) {
      return;
    }
    completer.completeError(error);
  }

  bool? _lastEmitted;
  void _emit() {
    final paid = isPaid;
    if (paid == _lastEmitted) return;
    _lastEmitted = paid;
    if (!_entitlementChanges.isClosed) _entitlementChanges.add(paid);
  }

  void dispose() {
    _sub?.cancel();
    _entitlementChanges.close();
  }
}
