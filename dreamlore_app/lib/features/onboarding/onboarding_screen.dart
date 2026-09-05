import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/config.dart';
import '../../core/legal.dart';
import '../../providers/providers.dart';
import '../../ui/cards.dart';
import 'onboarding_controller.dart';
import 'onboarding_steps.dart';
import '../../ui/motion.dart';
import '../../ui/night.dart';
import '../../widgets/ambient_video.dart';

/// Five-step first run: welcome → intent → sources → privacy → microphone.
///
/// Design notes, from the reference flows this was built against:
/// * Progress is a **waxing moon**, new at step one and full at step five —
///   the signature element, adapted from Moonly's moon-phase row. It is the
///   brand mark and the progress indicator at once, drawn in code.
/// * The ground is a luminous night field rather than flat black; the first
///   pass was a black rectangle and read as unfinished.
/// * Two-line CTAs (Moonly) pre-state what happens next, so nobody taps into
///   the unknown. The first one says how long this takes.
/// * A dedicated credibility step naming the actual corpus (ABY Journal's
///   "Scientific research" card) — this app's differentiator is that it cites
///   real books, and that has to be said before trust is asked for.
/// * Microphone priming with an explicit decline path and a no-storage promise
///   (Spotify's "Not now", Duolingo ABC's "we won't store any voice data"), so
///   a refusal lands somewhere useful instead of a broken mic on the Record tab.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _syncPage(int page) {
    if (!_pages.hasClients) return;
    // Guards the swipe → state → controller round trip from re-animating.
    if (_pages.page?.round() == page) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(page);
    } else {
      _pages.animateToPage(
        page,
        duration: Ob.pageDuration,
        curve: Ob.pageCurve,
      );
    }
  }

  Future<void> _finish() async {
    await ref.read(onboardingControllerProvider.notifier).complete();
    if (!mounted) return;
    // Hand back to the gate rather than pushing the shell: the gate is what
    // knows the paywall still owes this user one showing. Pushing MainShell
    // here skipped it entirely on every fresh install.
    ref.read(appGateProvider.notifier).recompute();
  }

  Future<void> _openSettings() async {
    try {
      await openAppSettings();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open Settings → Dreamlore to change permissions.'),
        ),
      );
    }
  }

  void _showLegal() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Privacy & Terms'),
        content: const Text(
          'Both open in your browser. Nothing is agreed to by reading them.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              openLegalUrl(context, 'Privacy Policy', Config.privacyUrl);
            },
            child: const Text('Privacy Policy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              openLegalUrl(context, 'Terms of Use', Config.termsUrl);
            },
            child: const Text('Terms of Use'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final ctl = ref.read(onboardingControllerProvider.notifier);

    ref.listen(onboardingControllerProvider.select((s) => s.page), (_, page) {
      _syncPage(page);
    });

    // Responsive: the moon is the first thing to give up space when the
    // viewport is short or turned on its side.
    final moonSize = Ob.isLandscape(context)
        ? 40.0
        : Ob.isShort(context)
        ? 52.0
        : 68.0;

    return PopScope(
      canPop: state.page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ctl.back();
      },
      child: Scaffold(
        backgroundColor: Ob.ink,
        body: NightCanvas(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The night over the lake, alive behind the first page only —
              // a welcome, not wallpaper for the questions that follow.
              AnimatedOpacity(
                opacity: state.page == 0 ? 1 : 0,
                duration: Motion.slow,
                curve: Motion.curve,
                child: const AmbientVideo(asset: 'assets/video/onboarding.mp4'),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _Header(
                      page: state.page,
                      total: OnboardingController.stepCount,
                      moonSize: moonSize,
                      onBack: ctl.back,
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pages,
                        physics: const ClampingScrollPhysics(),
                        onPageChanged: ctl.goTo,
                        children: [
                          WelcomeStep(
                            onShowLegal: _showLegal,
                            active: state.page == 0,
                          ),
                          IntentStep(
                            selected: state.intent,
                            onSelect: ctl.selectIntent,
                            active: state.page == 1,
                          ),
                          SourcesStep(active: state.page == 2),
                          PrivacyStep(active: state.page == 3),
                          MicStep(
                            status: state.mic,
                            onOpenSettings: _openSettings,
                            active: state.page == 4,
                          ),
                        ],
                      ),
                    ),
                    _Footer(state: state, ctl: ctl, onFinish: _finish),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int page;
  final int total;
  final double moonSize;
  final VoidCallback onBack;

  const _Header({
    required this.page,
    required this.total,
    required this.moonSize,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final first = page == 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 4, 8, Ob.isShort(context) ? 4 : 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Visibility(
              visible: !first,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: IconButton(
                onPressed: first ? null : onBack,
                icon: const Icon(Icons.arrow_back, color: Ob.muted),
                tooltip: 'Back',
              ),
            ),
          ),
          MoonPhaseIndicator(step: page, total: total, size: moonSize),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final OnboardingState state;
  final OnboardingController ctl;
  final Future<void> Function() onFinish;

  const _Footer({
    required this.state,
    required this.ctl,
    required this.onFinish,
  });

  bool get _isMicStep => state.page == OnboardingController.stepCount - 1;
  bool get _isIntentStep => state.page == 1;

  /// Label, sub-label, action. The sub-label says what happens next so nobody
  /// taps into the unknown — the cheapest comfort win in the flow.
  ({String label, String? sub, VoidCallback? onPressed}) _primary() {
    if (!_isMicStep) {
      const subs = <int, String>{
        0: 'Five quick screens',
        2: 'Next: how your data is handled',
        3: 'One last thing',
      };
      return (
        label: _isIntentStep ? 'Next' : 'Continue',
        sub: subs[state.page],
        onPressed: ctl.next,
      );
    }
    return switch (state.mic) {
      MicStatus.granted => (
        label: 'Start journaling',
        sub: 'Takes you into the app',
        onPressed: () => onFinish(),
      ),
      MicStatus.denied => (
        label: 'Continue',
        sub: 'You can type your dreams instead',
        onPressed: () => onFinish(),
      ),
      _ => (
        label: 'Allow microphone',
        sub: 'You can change this later',
        onPressed: state.busy ? null : () => ctl.requestMic(),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = _primary();
    final micUndecided =
        _isMicStep &&
        (state.mic == MicStatus.unknown || state.mic == MicStatus.skipped);

    final primary = PrimaryPill(
      label: p.label,
      sub: p.sub,
      onPressed: p.onPressed,
      busy: state.busy,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(22, 6, 22, Ob.isShort(context) ? 8 : 16),
      child: Ob.measure(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Moonly's Skip / Next pair: an optional question gets a visible
            // way out rather than a lone button that implies it is required.
            if (_isIntentStep)
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: GhostPill(
                      label: 'Skip',
                      onPressed: state.busy ? null : ctl.skipIntent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(flex: 6, child: primary),
                ],
              )
            else
              primary,
            if (micUndecided)
              TextButton(
                onPressed: state.busy
                    ? null
                    : () {
                        ctl.skipMic();
                        onFinish();
                      },
                child: const Text(
                  "I'll type instead",
                  style: TextStyle(color: Ob.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
