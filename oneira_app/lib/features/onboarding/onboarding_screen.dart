import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../providers/providers.dart';
import '../shell/main_shell.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Icon(Icons.nightlight_round, size: 44, color: t.colorScheme.primary),
              const SizedBox(height: 20),
              Text(Config.appName, style: t.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text('Speak your dream when you wake. Get a grounded reading.',
                  style: t.textTheme.titleMedium
                      ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 32),
              _point(t, Icons.mic, 'Tell it your dream',
                  'Transcribed on your device — the audio never leaves your phone.'),
              _point(t, Icons.menu_book, 'A reading grounded in real books',
                  'Drawing on public-domain dream literature, with quotes.'),
              _point(t, Icons.lock_outline, 'Private by default',
                  'Your dream journal is stored only on this device.'),
              const Spacer(),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Oneira is for reflection and journaling. It is not medical, '
                    'psychological, or predictive advice, and is not a substitute '
                    'for professional care.',
                    style: t.textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  await ref.read(settingsServiceProvider).setOnboarded(true);
                  // Prompt for mic/speech permission up front.
                  await ref.read(sttServiceProvider).init();
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                  );
                },
                child: const Text('Get started'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _point(ThemeData t, IconData icon, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: t.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(body, style: t.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      );
}
