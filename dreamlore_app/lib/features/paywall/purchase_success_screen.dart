import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../services/subscription_service.dart';

/// Shown once, immediately after a purchase activates. It states plainly what
/// was bought and when the first charge lands — the two things a person wants
/// confirmed the moment they have handed over money.
class PurchaseSuccessScreen extends StatelessWidget {
  const PurchaseSuccessScreen({super.key, required this.period});

  final BillingPeriod period;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isYearly = period == BillingPeriod.yearly;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Icon(Icons.check_circle_outline,
                  size: 64, color: t.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                isYearly ? 'Your trial has started' : 'Welcome to Plus',
                style: t.textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isYearly
                    ? 'Dreamlore Plus is yours for the next ${Config.trialDays} '
                        'days, free. Google Play will email you before it '
                        'renews — cancel before then and you are not charged.'
                    : 'Dreamlore Plus is active. Manage or cancel it any time '
                        'in Google Play.',
                textAlign: TextAlign.center,
                style: t.textTheme.titleMedium
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              const Spacer(flex: 3),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Start dreaming'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
