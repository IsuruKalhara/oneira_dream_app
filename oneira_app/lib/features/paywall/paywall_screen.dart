import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../providers/providers.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});
  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  List<Package> _pkgs = const [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pkgs = await ref.read(purchaseServiceProvider).packages();
    if (mounted) {
      setState(() {
        _pkgs = pkgs;
        _loading = false;
      });
    }
  }

  Future<void> _subscribe(Package pkg) async {
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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final configured = ref.read(purchaseServiceProvider).configured;

    return Scaffold(
      appBar: AppBar(title: const Text('Oneira Plus')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('More dreams, deeper readings', style: t.textTheme.headlineSmall),
            const SizedBox(height: 16),
            _benefit(t, Icons.auto_awesome, 'More interpretations every day'),
            _benefit(t, Icons.psychology_alt, 'Deeper, more nuanced readings'),
            _benefit(t, Icons.insights, 'Full symbol-trend insights'),
            _benefit(t, Icons.favorite, 'Support an independent app'),
            const SizedBox(height: 24),
            if (_loading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator()))
            else if (!configured || _pkgs.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Subscriptions are being set up — check back soon.',
                      style: t.textTheme.bodyMedium),
                ),
              )
            else
              ..._pkgs.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton(
                    onPressed: _busy ? null : () => _subscribe(p),
                    child: Text(
                        '${p.storeProduct.title} — ${p.storeProduct.priceString}'),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        final ok =
                            await ref.read(purchaseServiceProvider).restore();
                        if (!mounted) return;
                        messenger.showSnackBar(SnackBar(
                            content: Text(ok
                                ? 'Purchases restored'
                                : 'Nothing to restore')));
                        if (ok) {
                          ref.invalidate(quotaProvider);
                          navigator.pop();
                        }
                      },
                child: const Text('Restore purchases'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Subscriptions renew automatically until cancelled. Manage or cancel '
              'anytime in your app store account settings.',
              style: t.textTheme.labelSmall
                  ?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefit(ThemeData t, IconData icon, String s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: t.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(child: Text(s, style: t.textTheme.bodyLarge)),
          ],
        ),
      );
}
