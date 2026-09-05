import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'providers/providers.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/paywall/paywall_screen.dart';
import 'features/shell/main_shell.dart';
import 'ui/motion.dart';
import 'ui/night.dart';
import 'widgets/brand_mark.dart';

class DreamloreApp extends ConsumerStatefulWidget {
  const DreamloreApp({super.key});

  @override
  ConsumerState<DreamloreApp> createState() => _DreamloreAppState();
}

class _DreamloreAppState extends ConsumerState<DreamloreApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A cold start killed before its first frame still runs this callback,
      // and `ref` throws once the element is gone.
      if (!mounted) return;
      _reconcileAccount();
      _refreshEntitlement();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    // Subscriptions are cancelled and renewed outside the app — in the Play
    // subscription centre, or by a renewal that simply didn't happen — so
    // re-check on the way back in rather than only at cold start.
    if (state == AppLifecycleState.resumed) _refreshEntitlement();
  }

  /// Drops a stale local sign-in flag if Firebase's own session is gone.
  Future<void> _reconcileAccount() async {
    await ref.read(authServiceProvider).syncFromFirebase();
    if (!mounted) return;
    ref.read(signedInProvider.notifier).resync();
  }

  void _refreshEntitlement() {
    unawaited(ref.read(entitlementProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Config.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const _Launch(child: _Gate()),
    );
  }
}

/// The first Flutter frame: the same mark on the same ink as the native
/// splash, held for a beat and then dissolved into whichever screen the gate
/// chose. The native splash hands off to this with no visible seam, and this
/// hands off to the app with a fade instead of a cut.
class _Launch extends StatefulWidget {
  final Widget child;
  const _Launch({required this.child});

  @override
  State<_Launch> createState() => _LaunchState();
}

class _LaunchState extends State<_Launch> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          ignoring: _done,
          child: AnimatedOpacity(
            opacity: _done ? 0 : 1,
            duration: Motion.slow,
            curve: Curves.easeOut,
            child: const ColoredBox(
              color: Ob.ink,
              child: Center(child: BrandMark(size: 108, withName: true)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sign in → onboarding → paywall → the app. Each step writes its own flag and
/// asks the gate to recompute, so quitting mid-flow resumes in the same place.
class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(appGateProvider)) {
      AppStage.signIn => const SignInScreen(),
      AppStage.onboarding => const OnboardingScreen(),
      AppStage.paywall => const PaywallScreen(firstRun: true),
      AppStage.main => const MainShell(),
    };
  }
}
