import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';

/// The first screen of a fresh install. One account, one tap — the journal
/// itself stays on the device, so this is about carrying a subscription
/// between devices, not about handing over a diary.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await ref.read(signedInProvider.notifier).signInWithGoogle();
      if (!mounted) return;
      ref.read(appGateProvider.notifier).recompute();
    } on SignInCancelledException {
      // Backed out of the account picker — not an error.
      if (mounted) setState(() => _busy = false);
    } on AuthNotConfiguredException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _notify(e.message);
      }
    } on SignInFailedException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _notify(e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _notify('Sign-in failed. Please try again.');
      }
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final configured = ref.read(authServiceProvider).isConfigured;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Icon(Icons.nightlight_round,
                  size: 56, color: t.colorScheme.primary),
              const SizedBox(height: 24),
              Text(Config.appName,
                  style: t.textTheme.displaySmall, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'Speak your dream when you wake.\nGet a reading grounded in real books.',
                textAlign: TextAlign.center,
                style: t.textTheme.titleMedium
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              const Spacer(flex: 3),
              if (!configured)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        "Sign-in isn't configured in this build yet. Add the "
                        'Firebase config to android/app/google-services.json — '
                        'see SHIP.md § Sign-in.',
                        style: t.textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
              if (_busy)
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
                FilledButton.icon(
                  onPressed: _signIn,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Continue with Google'),
                ),
              // Development escape hatch: without it, a build with no Firebase
              // project can't get past this screen at all. Absent from release
              // builds, where sign-in is the real gate.
              if (!configured && kDebugMode)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await ref
                              .read(signedInProvider.notifier)
                              .continueWithoutAccount();
                          if (!mounted) return;
                          ref.read(appGateProvider.notifier).recompute();
                        },
                  child: const Text('Skip for now (debug builds only)'),
                ),
              const SizedBox(height: 20),
              Text(
                'Your dream journal is stored on this device. Signing in only '
                'carries your subscription across devices.',
                textAlign: TextAlign.center,
                style: t.textTheme.bodySmall
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Text(
                'By continuing you agree to the Terms of Use and Privacy Policy.',
                textAlign: TextAlign.center,
                style: t.textTheme.labelSmall
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
