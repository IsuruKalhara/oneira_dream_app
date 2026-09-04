import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../providers/providers.dart';
import '../paywall/paywall_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late bool _reminder;

  @override
  void initState() {
    super.initState();
    _reminder = ref.read(settingsServiceProvider).reminderEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    // The entitlement the store and the verifier agree on. The quota snapshot
    // is the Worker's own answer, and lags a purchase by a request; this does
    // not, so the plan row is right the moment a purchase lands.
    final isPaid = ref.watch(entitlementProvider);
    final auth = ref.watch(authServiceProvider);
    final deviceId = ref.read(deviceIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Plan'),
            subtitle: Text(isPaid ? 'Dreamlore Plus' : 'Free'),
            trailing: isPaid
                ? null
                : TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PaywallScreen())),
                    child: const Text('Upgrade'),
                  ),
          ),
          if (isPaid)
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: const Text('Manage subscription'),
              subtitle: const Text('Change plan or cancel in Google Play'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: _openPlaySubscriptions,
            )
          else
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restore purchases'),
              subtitle: const Text('Already subscribed on this Google account?'),
              onTap: _restore,
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: const Text('Account'),
            subtitle: Text(auth.email.isEmpty ? 'Signed in' : auth.email),
            trailing: TextButton(
              onPressed: _signOut,
              child: const Text('Sign out'),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.alarm),
            title: const Text('Morning reminder'),
            subtitle: const Text('A gentle nudge to log your dream on waking'),
            value: _reminder,
            onChanged: (v) {
              setState(() => _reminder = v);
              ref.read(settingsServiceProvider).setReminderEnabled(v);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _showLink(context, 'Privacy Policy', Config.privacyUrl),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Use'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _showLink(context, 'Terms of Use', Config.termsUrl),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.delete_outline, color: t.colorScheme.error),
            title: Text('Clear all dreams',
                style: TextStyle(color: t.colorScheme.error)),
            onTap: () => _clearAll(context),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '${Config.appName} · reflective dream journal\nnot medical or psychological advice',
              textAlign: TextAlign.center,
              style: t.textTheme.labelSmall
                  ?.copyWith(color: t.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('id ${deviceId.substring(0, 8)}',
                style: t.textTheme.labelSmall
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _openPlaySubscriptions() async {
    final ok = await launchUrl(
      Uri.parse(Config.manageSubscriptionsUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open Google Play.")),
      );
    }
  }

  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(entitlementProvider.notifier).restore();
      messenger.showSnackBar(SnackBar(
        content: Text(result.entitled
            ? 'Restored — Dreamlore Plus is active.'
            : 'No previous purchases found for this Google account.'),
      ));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't restore purchases.")),
      );
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'Your dreams stay on this device. Your subscription stays with '
            'your Google account and can be restored.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(signedInProvider.notifier).signOut();
    if (!mounted) return;
    ref.read(appGateProvider.notifier).recompute();
  }

  void _showLink(BuildContext context, String title, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SelectableText(url),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _clearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all dreams?'),
        content: const Text('This permanently deletes every saved dream on this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete all')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(dreamRepositoryProvider).clearAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('All dreams cleared')));
      }
    }
  }
}
