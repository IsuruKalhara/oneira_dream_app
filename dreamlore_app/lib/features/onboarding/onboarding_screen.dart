import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../providers/providers.dart';

/// A short paged introduction, shown once, straight after sign-in. It ends by
/// asking for the microphone — at the moment the user has just been told what
/// it's for, rather than as an unexplained system prompt on launch.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  static const _pages = [
    _PageData(
      icon: Icons.mic_none_rounded,
      title: 'Tell it your\ndream.',
      body:
          'Dreams go the moment you reach for them. Speak while it is still '
          'there — Dreamlore listens and writes it down for you.',
    ),
    _PageData(
      icon: Icons.menu_book_rounded,
      title: 'A reading from\nreal books.',
      body:
          'Not invented symbolism. Every reading draws on public-domain dream '
          'literature and quotes it, so you can see where it came from.',
    ),
    _PageData(
      icon: Icons.insights_rounded,
      title: 'Watch the\npatterns surface.',
      body:
          'The same symbols come back. Your journal tracks them over weeks and '
          'months, so you notice what keeps returning.',
    ),
    _PageData(
      icon: Icons.lock_outline_rounded,
      title: 'Yours, and\nonly yours.',
      body:
          'Your voice is transcribed on this device and never uploaded. Your '
          'journal is stored here too.',
      note:
          'Dreamlore is for reflection and journaling. It is not medical, '
          'psychological, or predictive advice, and is not a substitute for '
          'professional care.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    // Hold the services rather than `ref`: the permission dialog is the most
    // likely moment in the whole app for someone to walk away, which detaches
    // the element, and reading `ref` after that throws.
    final settings = ref.read(settingsServiceProvider);
    final stt = ref.read(sttServiceProvider);
    final gate = ref.read(appGateProvider.notifier);

    try {
      await stt.init();
    } catch (_) {
      // Declined, or a detached activity made the channel throw. Onboarding
      // still finishes: the microphone is re-requested at the point of use,
      // and a dream can always be typed instead.
    }
    // Runs even if the user walked away mid-dialog, so they are not shown
    // onboarding again on the next launch.
    await settings.setOnboarded(true);
    gate.recompute();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: isLast ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: TextButton(
                  onPressed: isLast || _finishing
                      ? null
                      : () => _controller.animateToPage(
                            _pages.length - 1,
                            duration: const Duration(milliseconds: 380),
                            curve: Curves.easeOutCubic,
                          ),
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _Page(data: _pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _page ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? t.colorScheme.primary
                                : t.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_finishing)
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
                      onPressed: _next,
                      child: Text(isLast
                          ? 'Allow microphone & continue'
                          : 'Continue'),
                    ),
                  if (isLast) ...[
                    const SizedBox(height: 6),
                    Text(
                      'You can say no — dreams can be typed instead.',
                      style: t.textTheme.labelSmall
                          ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageData {
  const _PageData({
    required this.icon,
    required this.title,
    required this.body,
    this.note,
  });
  final IconData icon;
  final String title;
  final String body;
  final String? note;
}

class _Page extends StatelessWidget {
  const _Page({required this.data});
  final _PageData data;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.colorScheme.primary.withValues(alpha: 0.16),
            ),
            child: Icon(data.icon, size: 34, color: t.colorScheme.primary),
          ),
          const SizedBox(height: 28),
          Text(data.title,
              style: t.textTheme.displaySmall?.copyWith(height: 1.1)),
          const SizedBox(height: 14),
          Text(
            data.body,
            style: t.textTheme.titleMedium?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const Spacer(flex: 2),
          if (data.note != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(data.note!, style: t.textTheme.bodySmall),
              ),
            ),
          const SizedBox(height: 8),
          if (data.note == null)
            Text(
              Config.appName,
              style: t.textTheme.labelSmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                letterSpacing: 2,
              ),
            ),
        ],
      ),
    );
  }
}
