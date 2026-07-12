import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final tier = ref.watch(quotaProvider).asData?.value?.tier ?? 'free';
    final deviceId = ref.read(deviceIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Plan'),
            subtitle: Text(tier == 'paid' ? 'Oneira Plus' : 'Free'),
            trailing: tier == 'paid'
                ? null
                : TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PaywallScreen())),
                    child: const Text('Upgrade'),
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
