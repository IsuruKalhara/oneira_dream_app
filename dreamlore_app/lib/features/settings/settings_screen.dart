import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/legal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/providers.dart';
import '../../ui/night.dart';
import '../../ui/scaffold.dart';
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
    final paid = tier == 'paid';

    return NightScaffold(
      title: 'Settings',
      padded: false,
      child: ListView(
        // Explicit padding drops the extendBody inset — add the nav-bar
        // clearance back or the disclaimer/device-id footer hides under it.
        padding: EdgeInsets.fromLTRB(
            22, 0, 22, 28 + MediaQuery.paddingOf(context).bottom),
        children: [
          _Group(
            children: [
              _Row(
                icon: Icons.workspace_premium_outlined,
                title: 'Plan',
                subtitle: paid ? 'Dreamlore Plus' : 'Free',
                trailing: paid
                    ? null
                    : TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const PaywallScreen()),
                        ),
                        child: const Text('Upgrade'),
                      ),
              ),
              _Row(
                icon: Icons.alarm,
                title: 'Morning reminder',
                subtitle: 'A gentle nudge to log your dream on waking',
                trailing: Switch(
                  value: _reminder,
                  onChanged: (v) => _setReminder(v),
                ),
              ),
              // Play requires a way to manage and restore a subscription from
              // inside the app. These were on the previous settings screen and
              // are re-added here in this screen's own row style.
              if (paid)
                _Row(
                  icon: Icons.credit_card,
                  title: 'Manage subscription',
                  subtitle: 'Change plan or cancel in Google Play',
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: _openPlaySubscriptions,
                )
              else
                _Row(
                  icon: Icons.restore,
                  title: 'Restore purchases',
                  subtitle: 'Already subscribed on this Google account?',
                  onTap: _restore,
                ),
            ],
          ),
          const SizedBox(height: 14),
          _Group(
            children: [
              _Row(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                trailing: const Icon(Icons.open_in_new,
                    size: 17, color: Ob.muted),
                onTap: () =>
                    openLegalUrl(context, 'Privacy Policy', Config.privacyUrl),
              ),
              _Row(
                icon: Icons.description_outlined,
                title: 'Terms of Use',
                trailing: const Icon(Icons.open_in_new,
                    size: 17, color: Ob.muted),
                onTap: () =>
                    openLegalUrl(context, 'Terms of Use', Config.termsUrl),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Group(
            children: [
              _Row(
                icon: Icons.delete_outline,
                tint: t.colorScheme.error,
                title: 'Clear all dreams',
                subtitle: 'Permanently deletes every entry on this device',
                onTap: () => _clearAll(context),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Dreamlore · reflective dream journal\n'
            'not medical or psychological advice',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.5, color: Ob.muted),
          ),
          const SizedBox(height: 8),
          Text(
            'id ${deviceId.substring(0, 8)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.8,
              color: Ob.muted.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setReminder(bool enable) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _reminder = enable);
    if (enable) {
      final ok =
          await ref.read(notificationServiceProvider).enableDaily();
      if (!mounted) return;
      if (!ok) {
        // Permission denied: the switch must not lie about a reminder that
        // will never fire.
        setState(() => _reminder = false);
        messenger.showSnackBar(SnackBar(
          content:
              const Text('Notifications are turned off for Dreamlore.'),
          action: SnackBarAction(
            label: 'Open settings',
            onPressed: () => openAppSettings(),
          ),
        ));
        return;
      }
      messenger.showSnackBar(const SnackBar(
          content: Text('Reminder set for 7:00 each morning')));
    } else {
      await ref.read(notificationServiceProvider).disable();
    }
    await ref.read(settingsServiceProvider).setReminderEnabled(enable && _reminder);
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

  Future<void> _clearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all dreams?'),
        content: const Text(
            'This permanently deletes every saved dream on this device.'),
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

/// Rounded group — the card equivalent of a Material list section.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.045),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(children: children),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? tint;

  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      button: onTap != null,
      label: subtitle == null ? title : '$title. $subtitle',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: tint ?? Ob.parchment,
                        )),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!,
                          style: const TextStyle(
                              fontSize: 12.5, height: 1.4, color: Ob.muted)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
