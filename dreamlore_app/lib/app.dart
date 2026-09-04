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
      home: const _Gate(),
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
