import 'package:flutter/material.dart';

import '../../services/subscription_service.dart';

/// Shown once, immediately after a purchase activates. It states plainly what
/// was bought and when the first charge lands — the two things a person wants
/// confirmed the moment they have handed over money.
class PurchaseSuccessScreen extends StatelessWidget {
  const PurchaseSuccessScreen({
    super.key,
    required this.period,
    this.trialDays,
  });

  final BillingPeriod period;

  /// The trial Play actually granted, or null if this purchase started billing
  /// straight away — someone who has used their trial before still buys the
  /// yearly plan, and must not be told a trial has started.
  final int? trialDays;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final days = trialDays;
    final onTrial = period == BillingPeriod.yearly && days != null;

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
                onTrial ? 'Your trial has started' : 'Welcome to Plus',
                style: t.textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                onTrial
                    ? 'Dreamlore Plus is yours for the next $days days, free. '
                        'Google Play will email you before it renews — cancel '
                        'before then and you are not charged.'
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
