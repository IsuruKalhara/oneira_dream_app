import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/config.dart';
import '../../core/legal.dart';
import '../../providers/providers.dart';
import '../../ui/cards.dart';
import '../../ui/night.dart';

/// Oneira Plus.
///
/// Built from the conversion-path research rather than from taste:
/// * **Anchoring** — the monthly card prints its own annualised cost, the way
///   stoic. does. A single price has nothing to be compared against except £0,
///   and £0 always wins.
/// * **Default bias + von Restorff** — one plan arrives selected and badged;
///   the other recedes. Nothing was selected before, so neither was chosen.
/// * **Hick's Law** — one CTA. Previously every RevenueCat package rendered as
///   its own equal-weight button, making the user build the comparison at the
///   highest-friction moment in the app.
/// * **Loss aversion** — the header names what stops, not what was consumed.
/// * **Provenance instead of popularity** — the app is pre-launch, so review
///   counts and press logos would be invented. The library is real and is the
///   thing the category actually fails at.
///
/// Guideline 3.1.2 requires the subscription's title, length and price, plus
/// functional Privacy and Terms links, before the customer is asked to
/// subscribe — hence the footer, which is not decorative.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});
  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  List<Package> _pkgs = const [];
  Package? _selected;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pkgs = await ref.read(purchaseServiceProvider).packages();
    if (!mounted) return;
    // Annual first — it is the plan that arrives selected.
    final sorted = [...pkgs]..sort((a, b) {
        int rank(Package p) => p.packageType == PackageType.annual ? 0 : 1;
        return rank(a).compareTo(rank(b));
      });
    setState(() {
      _pkgs = sorted;
      _selected = sorted.isEmpty ? null : sorted.first;
      _loading = false;
    });
  }

  Future<void> _subscribe() async {
    final pkg = _selected;
    if (pkg == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final ok = await ref.read(purchaseServiceProvider).purchase(pkg);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.invalidate(quotaProvider);
      messenger.showSnackBar(
          const SnackBar(content: Text("You're subscribed — thank you!")));
      navigator.pop();
    } else {
      messenger.showSnackBar(
          const SnackBar(content: Text("Purchase didn't complete.")));
    }
  }

  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final ok = await ref.read(purchaseServiceProvider).restore();
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(
        content: Text(ok ? 'Purchases restored' : 'Nothing to restore')));
    if (ok) {
      ref.invalidate(quotaProvider);
      navigator.pop();
    }
  }

  void _showLink(String title, String url) =>
      openLegalUrl(context, title, url);

  /// Percentage the annual plan saves against paying monthly for a year.
  int? _savingsPercent() {
    final annual = _pkgs.where((p) => p.packageType == PackageType.annual);
    final monthly = _pkgs.where((p) => p.packageType == PackageType.monthly);
    if (annual.isEmpty || monthly.isEmpty) return null;
    final a = annual.first.storeProduct.price;
    final m = monthly.first.storeProduct.price * 12;
    if (m <= 0 || a <= 0 || a >= m) return null;
    return (((m - a) / m) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.read(purchaseServiceProvider).configured;
    final savings = _savingsPercent();

    return Scaffold(
      backgroundColor: Ob.ink,
      body: NightCanvas(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Ob.muted),
                  tooltip: 'Close',
                ),
              ),
              Expanded(
                child: Ob.measure(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                    children: [
                      // Provenance, not popularity — this is verifiable.
                      const _ProvenanceStrip(),
                      const SizedBox(height: 22),
                      const BigTitle('Keep reading\nevery dream'),
                      const SizedBox(height: 12),
                      const Sub(
                        'The free tier gives you a taste. Plus is for the '
                        'mornings you actually remember something.',
                      ),
                      const SizedBox(height: 26),
                      const _Comparison(),
                      const SizedBox(height: 22),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (!configured || _pkgs.isEmpty)
                        const InfoCard(
                          icon: Icons.schedule,
                          title: 'Plus is nearly ready',
                          body: 'Subscriptions are still being set up. Your '
                              'free readings keep working in the meantime.',
                        )
                      else
                        for (final p in _pkgs)
                          _PlanCard(
                            package: p,
                            selected: identical(p, _selected),
                            savings: p.packageType == PackageType.annual
                                ? savings
                                : null,
                            onTap: () => setState(() => _selected = p),
                          ),
                    ],
                  ),
                ),
              ),
              _Footer(
                busy: _busy,
                canBuy: _selected != null,
                onBuy: _subscribe,
                onRestore: _restore,
                onLink: _showLink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one trust signal a pre-launch app can honestly show.
class _ProvenanceStrip extends StatelessWidget {
  const _ProvenanceStrip();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.menu_book_outlined, size: 15, color: primary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'EVERY READING QUOTES ONE OF THREE REAL BOOKS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Headway's before/after card, rebuilt as a factual product comparison. The
/// original promises life change; that register is on this app's own
/// words-to-avoid list, and a pre-launch app cannot evidence it. What it *can*
/// evidence is the difference the category's top complaint is about.
class _Comparison extends StatelessWidget {
  const _Comparison();

  static const _rows = [
    ('Invents an answer that sounds plausible', 'Quotes a real page, verbatim'),
    ('Different answer for the same dream', 'Names the book, author and year'),
    ('Says something when it has nothing', 'Tells you plainly when it doesn’t'),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('MOST DREAM APPS',
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: Ob.muted,
                    )),
              ),
              Expanded(
                child: Text('ONEIRA',
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (before, after) in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.close_rounded,
                            size: 14, color: Ob.muted),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(before,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  color: Ob.muted)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_rounded, size: 14, color: primary),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(after,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  color: Ob.parchment)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Package package;
  final bool selected;
  final int? savings;
  final VoidCallback onTap;

  const _PlanCard({
    required this.package,
    required this.selected,
    required this.savings,
    required this.onTap,
  });

  bool get _annual => package.packageType == PackageType.annual;
  String get _title => _annual ? 'Yearly' : 'Monthly';

  /// The anchor. A monthly price only looks expensive next to what it costs
  /// over a year, so the card does that arithmetic for the reader.
  String _detail() {
    final p = package.storeProduct;
    if (_annual) return '${p.priceString} billed once a year';
    final f =
        NumberFormat.simpleCurrency(name: p.currencyCode, decimalDigits: 2);
    return '${p.priceString} a month · ${f.format(p.price * 12)} a year';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        selected: selected,
        label: '$_title. ${_detail()}',
        excludeSemantics: true,
        child: Material(
          color: selected
              ? primary.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? primary.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.07),
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(_title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Ob.parchment,
                                )),
                            if (savings != null) ...[
                              const SizedBox(width: 9),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('SAVE $savings%',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      letterSpacing: 0.8,
                                      fontWeight: FontWeight.w800,
                                      color: Ob.ink,
                                    )),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(_detail(),
                            style: const TextStyle(
                                fontSize: 12.5, height: 1.35, color: Ob.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? primary : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? primary
                            : Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded,
                            size: 15, color: Ob.ink)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final bool busy;
  final bool canBuy;
  final VoidCallback onBuy;
  final VoidCallback onRestore;
  final void Function(String, String) onLink;

  const _Footer({
    required this.busy,
    required this.canBuy,
    required this.onBuy,
    required this.onRestore,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
      child: Ob.measure(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryPill(
              label: 'Continue',
              sub: canBuy ? 'Cancel anytime' : null,
              busy: busy,
              onPressed: canBuy ? onBuy : null,
            ),
            const SizedBox(height: 8),
            // Headway surfaces this at the moment of hesitation; it measurably
            // lowers the fear of forgetting to cancel.
            const Text(
              'Renews automatically. Your store reminds you before each renewal, '
              'and you can cancel any time from your account settings.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10.5, height: 1.45, color: Ob.muted),
            ),
            const SizedBox(height: 4),
            // Required on the purchase screen by App Store Guideline 3.1.2.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Link('Restore', busy ? null : onRestore),
                const _Dot(),
                _Link('Terms',
                    () => onLink('Terms of Use', Config.termsUrl)),
                const _Dot(),
                _Link('Privacy',
                    () => onLink('Privacy Policy', Config.privacyUrl)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) => const Text('·',
      style: TextStyle(color: Ob.muted, fontSize: 12));
}

class _Link extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _Link(this.label, this.onTap);

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
          foregroundColor: Ob.muted,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      );
}
