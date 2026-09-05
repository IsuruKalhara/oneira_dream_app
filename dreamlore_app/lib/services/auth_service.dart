import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/config.dart';
import 'settings_service.dart';

/// Thrown when sign-in is used before its backend is configured — no Firebase
/// project wired up yet, or a missing `google-services.json`. Callers show a
/// friendly message; nothing else in Dreamlore depends on being signed in, so
/// this is never fatal.
class AuthNotConfiguredException implements Exception {
  const AuthNotConfiguredException([
    this.message = "Sign-in isn't set up yet.",
  ]);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when the user dismisses the Google account picker. Not an error —
/// callers treat it as a no-op.
class SignInCancelledException implements Exception {
  const SignInCancelledException();
}

/// Firebase refuses to delete an account whose sign-in is more than a few
/// minutes old. That is a security feature, not a bug — the fix is to sign in
/// again and retry, which is what the UI says.
class ReauthRequiredException implements Exception {
  const ReauthRequiredException();
  @override
  String toString() =>
      'For your security, please sign in again before deleting your account.';
}

/// Any other sign-in failure, with a message safe to show.
class SignInFailedException implements Exception {
  const SignInFailedException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Account layer backed by Firebase Authentication with Google Sign-In.
///
/// Firebase must be initialized in `main()` and configured with a real
/// `google-services.json` (Android) / `GoogleService-Info.plist` (iOS) for any
/// of this to succeed — see SHIP.md § Sign-in. Until then [isConfigured] is
/// false and the sign-in screen says so rather than failing mysteriously.
class AuthService {
  AuthService(this._settings);

  final SettingsService _settings;
  bool _googleReady = false;

  /// True once Firebase has actually initialized. `Firebase.apps` is empty
  /// when `google-services.json` is missing, which is exactly the state a
  /// fresh clone of this repo is in.
  bool get isConfigured => Firebase.apps.isNotEmpty;

  fb.FirebaseAuth get _auth {
    if (!isConfigured) {
      throw const AuthNotConfiguredException(
        "Sign-in isn't set up yet. Add your Firebase config — see SHIP.md.",
      );
    }
    return fb.FirebaseAuth.instance;
  }

  fb.User? get currentUser => isConfigured ? _auth.currentUser : null;

  bool get isSignedIn => _settings.signedIn;
  String get email => _settings.userEmail;
  String get displayName => _settings.userName;

  /// Reconciles the cached sign-in flag with Firebase's own persisted session,
  /// so a session dropped on Firebase's side (password change, account
  /// deletion, token revocation) doesn't leave the app believing it is signed
  /// in forever. Called once at startup.
  Future<void> syncFromFirebase() async {
    if (!isConfigured) return;
    final user = _auth.currentUser;
    if (user == null) {
      if (_settings.signedIn) await _settings.clearAccount();
      return;
    }
    await _settings.setAccount(
      email: user.email ?? '',
      name: user.displayName ?? '',
    );
  }

  /// One-time Google Sign-In setup. The web (type 3) client id is what makes
  /// Android return an `idToken` Firebase can verify; without it the account
  /// picker succeeds and the Firebase exchange then fails.
  Future<void> _ensureGoogleInitialized() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: Config.googleWebClientId.isEmpty
          ? null
          : Config.googleWebClientId,
    );
    _googleReady = true;
  }

  Future<void> signInWithGoogle() async {
    if (!isConfigured) {
      throw const AuthNotConfiguredException(
        "Sign-in isn't set up yet. Add your Firebase config — see SHIP.md.",
      );
    }

    await _ensureGoogleInitialized();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const AuthNotConfiguredException(
        "Google Sign-In isn't available on this platform.",
      );
    }

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email'],
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SignInCancelledException();
      }
      throw SignInFailedException(_describe(e));
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthNotConfiguredException(
        "Google Sign-In didn't return an ID token. Check that the web client "
        'id is set (GOOGLE_WEB_CLIENT_ID) and this build\'s SHA-1 fingerprint '
        'is registered in Firebase.',
      );
    }

    try {
      final result = await _auth.signInWithCredential(
        fb.GoogleAuthProvider.credential(idToken: idToken),
      );
      final user = result.user;
      await _settings.setAccount(
        email: user?.email ?? account.email,
        name: user?.displayName ?? account.displayName ?? '',
      );
    } on fb.FirebaseAuthException catch (e) {
      throw SignInFailedException(e.message ?? 'Sign-in failed.');
    }
  }

  Future<void> signOut() async {
    if (isConfigured) {
      try {
        await _auth.signOut();
      } catch (_) {
        // Already signed out, or Firebase went away; the local flag below is
        // what the app actually gates on.
      }
    }
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Same reasoning.
      }
    }
    await _settings.clearAccount();
  }

  /// Deletes the account itself, not just the session.
  ///
  /// Google Play requires any app that lets a user create an account to also
  /// let them delete it from inside the app. Sign-out is not deletion: it
  /// leaves the Firebase user, and with it the identifier everything else is
  /// keyed to.
  ///
  /// Local dreams are the caller's responsibility — they are deleted first, so
  /// that a failure here can never leave the journal wiped and the account
  /// still alive.
  Future<void> deleteAccount() async {
    if (isConfigured) {
      final user = _auth.currentUser;
      if (user != null) {
        try {
          await user.delete();
        } on fb.FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            throw const ReauthRequiredException();
          }
          throw SignInFailedException(e.message ?? "Couldn't delete the account.");
        }
      }
    }
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // The account is already gone; local state below is what gates the app.
      }
    }
    await _settings.clearAccount();
  }

  /// Marks this device as signed in without an account. Only reachable from
  /// the sign-in screen's debug escape hatch, so development isn't blocked
  /// before Firebase exists.
  Future<void> continueWithoutAccount() =>
      _settings.setAccount(email: '', name: '');

  String _describe(GoogleSignInException e) => switch (e.code) {
    GoogleSignInExceptionCode.clientConfigurationError =>
      'Google Sign-In is misconfigured. Check the web client id and the '
          "app's SHA-1 fingerprints in Firebase.",
    GoogleSignInExceptionCode.providerConfigurationError =>
      'Google Play services is unavailable or out of date on this device.',
    GoogleSignInExceptionCode.uiUnavailable =>
      "Google Sign-In couldn't open. Please try again.",
    _ => e.description ?? 'Sign-in failed. Please try again.',
  };
}
