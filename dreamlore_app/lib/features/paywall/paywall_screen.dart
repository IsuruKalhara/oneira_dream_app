import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../services/subscription_service.dart';
import 'purchase_success_screen.dart';

/// Choose a plan → confirm → Play's own sheet → success.
///
/// Prices come from the store, never from a constant: the user is billed in
/// their own currency, and quoting a hardcoded figure would be both wrong and
/// against Play's rules. Nothing here pressures — the free tier is a real
/// tier, and declining is one tap.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.firstRun = false});

  /// True when this is the once-only offer straight after onboarding, where
  /// dismissing means "continue on the free plan" rather than popping a route.
  final bool firstRun;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  // Yearly-first: it carries the free trial, so it is the option that costs
  // the user nothing to try.
  BillingPeriod _period = BillingPeriod.yearly;
  bool _busy = false;
  bool _loadingPrices = true;
  bool _storeAvailable = false;

  /// The trial length Play will actually honour for this user on the yearly
  /// plan, resolved from the offer once prices load. Null means no trial —
  /// which is the truth for someone who has already used theirs, and the copy
  /// must not keep promising one. Nothing here hardcodes a number, so the
  /// paywall can never advertise a trial Play won't give.
  int? _trialDays;
  bool get _hasTrial => _trialDays != null;

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    final service = ref.read(subscriptionServiceProvider);
    try {
      await service.loadProducts();
    } catch (_) {
      // Fall through: _storeAvailable stays false and the UI says so.
    }
    if (!mounted) return;
    setState(() {
      _loadingPrices = false;
      _storeAvailable = service.productsAvailable;
      _trialDays = service.trialDays(BillingPeriod.yearly);
      // Yearly-first by default — but if that plan can't be sold (its product
      // isn't set up in Play yet), fall back to monthly rather than
      // pre-selecting a dead option.
      if (_price(BillingPeriod.yearly) == null &&
          _price(BillingPeriod.monthly) != null) {
        _period = BillingPeriod.monthly;
      }
    });
  }

  String? _price(BillingPeriod period) =>
      ref.read(subscriptionServiceProvider).priceLabel(period);

  /// Derived figures for the yearly card: a per-month equivalent and, when
  /// both real recurring prices are known, the saving against paying monthly.
  /// A non-positive amount (the trial offer's zero headline) yields nothing
  /// rather than a fake "save 100%".
  ({String perMonth, int savePercent})? get _yearlyMath {
    final s = ref.read(subscriptionServiceProvider);
    final yearly = s.priceParts(BillingPeriod.yearly);
    if (yearly == null || yearly.amount <= 0) return null;
    final perMonth =
        '${yearly.symbol}${(yearly.amount / 12).toStringAsFixed(2)}';
    final monthly = s.priceParts(BillingPeriod.monthly);
    var save = 0;
    if (monthly != null && monthly.amount > 0) {
      final pct = (1 - yearly.amount / (monthly.amount * 12)) * 100;
      if (pct >= 5 && pct <= 90) save = pct.round();
    }
    return (perMonth: perMonth, savePercent: save);
  }

  /// Nothing to buy until the selected plan has a price. It is null while the
  /// store is still answering, and when that product isn't set up in Play —
  /// either way, don't let the user tap into a purchase that can only fail.
  bool get _canBuy =>
      _storeAvailable && !_loadingPrices && _price(_period) != null;

  /// Leaves the paywall. On first run that means "the free plan is fine",
  /// which is recorded so the offer isn't repeated on every launch.
  Future<void> _dismiss() async {
    if (widget.firstRun) {
      await ref.read(settingsServiceProvider).setPaywallSeen(true);
      if (!mounted) return;
      ref.read(appGateProvider.notifier).recompute();
      return;
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _continue() async {
    if (ref.read(entitlementProvider)) return;
    if (_price(_period) == null) {
      _notify(
        "This plan isn't available right now. Try the other plan, or "
        'check back shortly.',
      );
      return;
    }
    final confirmed = await _confirmSheet(_period);
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    unawaited(HapticFeedback.mediumImpact());
    try {
      final outcome = await ref
          .read(entitlementProvider.notifier)
          .purchase(_period);
      if (!mounted) return;
      switch (outcome) {
        case PurchaseOutcome.activated:
          await ref.read(settingsServiceProvider).setPaywallSeen(true);
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  PurchaseSuccessScreen(period: _period, trialDays: _trialDays),
            ),
          );
          if (!mounted) return;
          // Back from the success screen: on first run the gate now resolves
          // to the app itself; elsewhere this simply closes the paywall.
          if (widget.firstRun) {
            ref.read(appGateProvider.notifier).recompute();
          } else {
            Navigator.of(context).maybePop();
          }
        case PurchaseOutcome.scheduled:
          setState(() => _busy = false);
          _notify(
            'Your plan will change when the current period ends. '
            'Nothing to do until then.',
          );
        case PurchaseOutcome.pending:
          setState(() => _busy = false);
          _notify(_pendingMessage);
      }
    } on PurchaseCancelledException {
      // Backed out of Play's own sheet — not an error.
      if (mounted) setState(() => _busy = false);
    } on PurchasePendingException {
      if (!mounted) return;
      setState(() => _busy = false);
      _notify(_pendingMessage);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _notify("Purchase didn't go through. Please try again.");
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(entitlementProvider.notifier).restore();
      if (!mounted) return;
      setState(() => _busy = false);
      _notify(
        result.entitled
            ? 'Restored — Dreamlore Plus is active.'
            : 'No previous purchases found for this Google account.',
      );
      if (result.entitled) {
        await ref.read(settingsServiceProvider).setPaywallSeen(true);
        if (!mounted) return;
        if (widget.firstRun) {
          ref.read(appGateProvider.notifier).recompute();
        } else {
          Navigator.of(context).maybePop();
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _notify("Couldn't restore purchases. Please try again.");
    }
  }

  static const _pendingMessage =
      'Google Play is still confirming your payment. Dreamlore Plus unlocks as '
      'soon as it goes through — you can close this screen.';

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
    );
  }

  String _ctaLabel(bool isPaid) {
    if (isPaid) return 'Your current plan';
    if (_loadingPrices) return 'Loading plans…';
    if (!_storeAvailable) return 'Available on Google Play';
    if (_price(_period) == null) return "This plan isn't available yet";
    if (_period == BillingPeriod.monthly) {
      return 'Continue · ${_price(_period)}/mo';
    }
    return _hasTrial
        ? 'Start $_trialDays-day free trial'
        : 'Continue · ${_price(_period)}/yr';
  }

  Future<bool?> _confirmSheet(BillingPeriod period) {
    final t = Theme.of(context);
    final price = _price(period);
    final isYearly = period == BillingPeriod.yearly;
    final withTrial = isYearly && _hasTrial;
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              withTrial ? 'Start your free trial' : 'Confirm subscription',
              style: t.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              withTrial
                  ? 'Dreamlore Plus — free for $_trialDays days, then '
                        '${price ?? ''} a year, billed by Google Play. Cancel any '
                        'time before the trial ends and you are not charged.'
                  : 'Dreamlore Plus — ${price ?? ''} a '
                        '${isYearly ? 'year' : 'month'}, billed by Google Play. '
                        'Cancel any time.',
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              child: Text(
                withTrial
                    ? 'Start free trial'
                    : (price == null
                          ? 'Confirm'
                          : 'Confirm · $price/${isYearly ? 'yr' : 'mo'}'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext, false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isPaid = ref.watch(entitlementProvider);
    final math = _yearlyMath;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: widget.firstRun ? 'Not now' : 'Close',
                    onPressed: _busy ? null : _dismiss,
                    icon: const Icon(Icons.close),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _busy ? null : _restore,
                    child: const Text('Restore'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                children: [
                  Text(
                    'Dream more,\nread deeper.',
                    style: t.textTheme.displaySmall?.copyWith(height: 1.1),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Recording, transcription and your journal stay free. Plus '
                    'buys room for more readings, and longer ones.',
                    style: t.textTheme.bodyMedium?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _benefit(
                    t,
                    Icons.auto_awesome,
                    'More interpretations every day and every month',
                  ),
                  _benefit(
                    t,
                    Icons.psychology_alt,
                    'Deeper readings, with more of the source behind them',
                  ),
                  _benefit(
                    t,
                    Icons.insights,
                    'Full symbol-trend insights across your whole journal',
                  ),
                  _benefit(
                    t,
                    Icons.favorite_border,
                    'Supports an independent, ad-free app',
                  ),
                  const SizedBox(height: 28),
                  _PlanCard(
                    title: 'Yearly',
                    tagline: math == null
                        ? (_price(BillingPeriod.yearly) == null &&
                                  !_loadingPrices
                              ? '≈ ${Config.referenceYearlyPerMonth} a month, billed yearly'
                              : 'Best value')
                        : '≈ ${math.perMonth} a month, billed yearly',
                    badge: (math?.savePercent ?? 0) > 0
                        ? 'Save ${math!.savePercent}%'
                        : 'Best value',
                    ribbon: _hasTrial ? '$_trialDays-day free trial' : null,
                    price:
                        _price(BillingPeriod.yearly) ??
                        (_loadingPrices
                            ? null
                            : 'from ${Config.referenceYearlyPrice}'),
                    priceSuffix: '/yr',
                    loadingPrice: _loadingPrices,
                    selected: _period == BillingPeriod.yearly,
                    onTap: _busy
                        ? null
                        : () => setState(() => _period = BillingPeriod.yearly),
                  ),
                  const SizedBox(height: 12),
                  _PlanCard(
                    title: 'Monthly',
                    tagline: 'Cancel any time',
                    price:
                        _price(BillingPeriod.monthly) ??
                        (_loadingPrices
                            ? null
                            : 'from ${Config.referenceMonthlyPrice}'),
                    priceSuffix: '/mo',
                    loadingPrice: _loadingPrices,
                    selected: _period == BillingPeriod.monthly,
                    onTap: _busy
                        ? null
                        : () => setState(() => _period = BillingPeriod.monthly),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _period == BillingPeriod.yearly && _hasTrial
                        ? Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: _TrialTimeline(
                              trialDays: _trialDays!,
                              yearlyPrice: _price(BillingPeriod.yearly),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  if (!_loadingPrices && !_storeAvailable) ...[
                    const SizedBox(height: 16),
                    Text(
                      "Plans can't be loaded right now. Check your connection, "
                      "and that you're signed in to Google Play.",
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Column(
                children: [
                  if (_busy)
                    const SizedBox(
                      height: 52,
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    FilledButton(
                      onPressed: isPaid || !_canBuy ? null : _continue,
                      child: Text(_ctaLabel(isPaid)),
                    ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _busy ? null : _dismiss,
                    child: Text(
                      widget.firstRun
                          ? 'Continue with the free plan'
                          : 'Not now',
                    ),
                  ),
                  Text(
                    _period == BillingPeriod.monthly
                        ? 'Renews monthly until cancelled. Cancel any time in '
                              'Google Play. Terms & Privacy apply.'
                        : _hasTrial
                        ? 'Free for $_trialDays days, then renews yearly '
                              'until cancelled. Cancel any time in Google '
                              'Play. Terms & Privacy apply.'
                        : 'Renews yearly until cancelled. Cancel any time '
                              'in Google Play. Terms & Privacy apply.',
                    textAlign: TextAlign.center,
                    style: t.textTheme.labelSmall?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefit(ThemeData t, IconData icon, String s) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: t.colorScheme.primary),
        const SizedBox(width: 14),
        Expanded(child: Text(s, style: t.textTheme.bodyLarge)),
      ],
    ),
  );
}

/// One selectable plan. The trial reads as a property of the yearly plan —
/// a band attached to its card — rather than a floating claim.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.tagline,
    required this.selected,
    required this.onTap,
    required this.price,
    required this.priceSuffix,
    required this.loadingPrice,
    this.badge,
    this.ribbon,
  });

  final String title;
  final String tagline;
  final bool selected;
  final VoidCallback? onTap;

  /// The store's localized price, or null if it isn't known yet.
  final String? price;
  final String priceSuffix;
  final bool loadingPrice;
  final String? badge;
  final String? ribbon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final radius = BorderRadius.circular(18);
    return Material(
      color: selected
          ? t.colorScheme.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? t.colorScheme.primary
                  : t.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _body(context, t),
                ),
                if (ribbon != null)
                  Container(
                    color: selected
                        ? t.colorScheme.primary
                        : t.colorScheme.primary.withValues(alpha: 0.30),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      ribbon!,
                      textAlign: TextAlign.center,
                      style: t.textTheme.labelMedium?.copyWith(
                        color: selected
                            ? t.colorScheme.onPrimary
                            : t.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ThemeData t) {
    // No price rather than a wrong one: the store quotes each user in their
    // own currency, and we never guess on its behalf. Long localized prices
    // ("LKR 1,000.00") scale down instead of crushing the text column.
    final priceText = price != null
        ? Text.rich(
            TextSpan(
              children: [
                TextSpan(text: price, style: t.textTheme.titleLarge),
                TextSpan(text: ' $priceSuffix', style: t.textTheme.labelMedium),
              ],
            ),
            maxLines: 1,
          )
        : Text(
            loadingPrice ? '…' : '—',
            style: t.textTheme.titleLarge?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 22,
              color: selected
                  ? t.colorScheme.primary
                  : t.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(title, style: t.textTheme.titleMedium),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: t.colorScheme.primary,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  badge!,
                  style: t.textTheme.labelSmall?.copyWith(
                    color: t.colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
            const Spacer(),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(fit: BoxFit.scaleDown, child: priceText),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 34),
          child: Text(
            tagline,
            style: t.textTheme.bodySmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// "How the free trial works" — the moments that matter, in order. Shown only
/// for the plan that actually carries the trial, and it promises nothing the
/// code doesn't do: Play, not Dreamlore, is where the cancelling happens.
class _TrialTimeline extends StatelessWidget {
  const _TrialTimeline({required this.trialDays, required this.yearlyPrice});

  /// The trial length Play reported for this offer.
  final int trialDays;

  /// The store's localized recurring yearly price, or null if unknown.
  final String? yearlyPrice;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final steps = <(IconData, String, String)>[
      (
        Icons.lock_open,
        'Today',
        'Everything in Plus unlocks. You are not charged.',
      ),
      (
        Icons.notifications_none,
        'Day ${trialDays - 1}',
        'Google Play emails you before the trial ends.',
      ),
      (
        Icons.event_available,
        'Day $trialDays',
        yearlyPrice == null
            ? 'Your subscription starts, unless you cancelled.'
            : 'Your year starts at $yearlyPrice, unless you cancelled.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How the free trial works', style: t.textTheme.titleSmall),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(steps[i].$1, size: 18, color: t.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(steps[i].$2, style: t.textTheme.labelLarge),
                      const SizedBox(height: 2),
                      Text(
                        steps[i].$3,
                        style: t.textTheme.bodySmall?.copyWith(
                          color: t.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (i != steps.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
