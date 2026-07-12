import 'package:flutter/material.dart';

/// Shown instead of an AI interpretation when the on-device safety check
/// detects expressed self-harm intent. The app must not "interpret" a crisis.
class SafetyView extends StatelessWidget {
  final VoidCallback onDismiss;
  const SafetyView({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Icon(Icons.favorite, color: t.colorScheme.primary, size: 40),
          const SizedBox(height: 16),
          Text('You matter more than a dream reading',
              style: t.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            "It sounds like you might be going through something painful. This app "
            "interprets dreams for reflection — it isn't the right help for a crisis, "
            "and you deserve real support from someone who can listen.",
            style: t.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 22),
          _resource(t, 'Call or text 988', 'Suicide & Crisis Lifeline — US, 24/7'),
          _resource(t, 'Samaritans 116 123', 'UK & Ireland, free, 24/7'),
          _resource(t, 'findahelpline.com', 'Free, confidential help in your country'),
          const SizedBox(height: 12),
          Text('If you are in immediate danger, call your local emergency number.',
              style: t.textTheme.bodySmall),
          const SizedBox(height: 28),
          Center(child: TextButton(onPressed: onDismiss, child: const Text('Go back'))),
        ],
      ),
    );
  }

  Widget _resource(ThemeData t, String title, String subtitle) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(title,
                style: t.textTheme.titleMedium?.copyWith(
                    color: t.colorScheme.primary, fontWeight: FontWeight.w600)),
            Text(subtitle, style: t.textTheme.bodySmall),
          ],
        ),
      );
}
