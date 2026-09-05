import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../providers/providers.dart';
import '../../services/auth_service.dart';
import '../../ui/cards.dart';
import '../../ui/motion.dart';
import '../../ui/night.dart';
import '../../widgets/google_g.dart';
import '../../widgets/brand_mark.dart';

/// The first screen of a fresh install. One account, one tap — the journal
/// itself stays on the device, so this is about carrying a subscription
/// between devices, not about handing over a diary.
///
/// It is also the first thing anyone sees after the splash, so it is set in
/// the same night as everything after it: the mark, the name in the serif,
/// one line of promise, one warm button.
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
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        final f = Friendly.of(e);
        _notify(
          f.offline
              ? "You're offline. Connect and try again."
              : "Couldn't sign in. Please try again.",
        );
      }
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _skip() async {
    await ref.read(signedInProvider.notifier).continueWithoutAccount();
    if (!mounted) return;
    ref.read(appGateProvider.notifier).recompute();
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.read(authServiceProvider).isConfigured;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Ob.ink,
      body: NightCanvas(
        child: SafeArea(
          bottom: false,
          child: Ob.measure(
            child: Padding(
              padding: EdgeInsets.fromLTRB(28, 24, 28, 24 + bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),
                  const Reveal(child: Center(child: BrandMark(size: 120))),
                  const SizedBox(height: 26),
                  Reveal(
                    index: 1,
                    child: Text(
                      'Dreamlore',
                      textAlign: TextAlign.center,
                      style: Ob.serif(
                        size: 40,
                        weight: FontWeight.w500,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Reveal(
                    index: 2,
                    child: Text(
                      'Speak your dream when you wake.\n'
                      'Get a reading that quotes real books.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Ob.muted,
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  if (!configured)
                    Reveal(
                      index: 3,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: const InfoCard(
                          icon: Icons.info_outline,
                          title: "Sign-in isn't configured in this build",
                          body:
                              'Add the Firebase config — see SHIP.md § Sign-in.',
                        ),
                      ),
                    ),
                  Reveal(
                    index: 4,
                    child: GoogleSignInButton(busy: _busy, onPressed: _signIn),
                  ),
                  const SizedBox(height: 8),
                  const Reveal(
                    index: 4,
                    child: Text(
                      'One tap. Your journal is saved on this phone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, color: Ob.muted),
                    ),
                  ),
                  // Development escape hatch, so a build with no Firebase
                  // project or no OAuth client yet can still reach the app.
                  // Absent from release builds, where sign-in is the real gate.
                  if (kDebugMode)
                    TextButton(
                      onPressed: _busy ? null : _skip,
                      child: const Text(
                        'Skip for now (debug builds only)',
                        style: TextStyle(color: Ob.muted),
                      ),
                    ),
                  const SizedBox(height: 18),
                  const Reveal(
                    index: 5,
                    child: Text(
                      // Accurate, not merely reassuring: the journal is
                      // local, but the dream text IS sent away to write the
                      // reading. Claiming otherwise here contradicts the
                      // privacy policy and is exactly the claim
                      // docs/STORE-LISTING.md warns against making.
                      'Signing in only carries your subscription across '
                      'devices. Your journal is saved on this phone; to write '
                      'a reading your dream text is sent to our AI provider '
                      'and is not kept.\n'
                      'By continuing you agree to the Terms of Use and '
                      'Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: Ob.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
