import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'providers/providers.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/main_shell.dart';

class OneiraApp extends ConsumerStatefulWidget {
  const OneiraApp({super.key});

  @override
  ConsumerState<OneiraApp> createState() => _OneiraAppState();
}

class _OneiraAppState extends ConsumerState<OneiraApp> {
  @override
  void initState() {
    super.initState();
    // Configure RevenueCat if a key is present (no-op otherwise).
    ref.read(purchaseServiceProvider).init();
  }

  @override
  Widget build(BuildContext context) {
    final onboarded = ref.watch(settingsServiceProvider).onboarded;
    return MaterialApp(
      title: Config.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: onboarded ? const MainShell() : const OnboardingScreen(),
    );
  }
}
