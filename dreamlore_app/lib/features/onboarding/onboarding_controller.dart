import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../services/settings_service.dart';

/// Outcome of the microphone / speech-recognition request.
enum MicStatus {
  /// Not asked yet.
  unknown,

  /// Speech recognition initialised — the mic is usable.
  granted,

  /// Permission refused, or speech recognition is unavailable on this device.
  denied,

  /// User chose "I'll type instead". Not a failure — a valid way to use the app.
  skipped,
}

class OnboardingState {
  final int page;
  final DreamIntent? intent;
  final MicStatus mic;
  final bool busy;

  const OnboardingState({
    this.page = 0,
    this.intent,
    this.mic = MicStatus.unknown,
    this.busy = false,
  });

  /// `intent` is nullable and legitimately clearable, so it takes an explicit
  /// [clearIntent] flag rather than relying on `??`.
  OnboardingState copyWith({
    int? page,
    DreamIntent? intent,
    bool clearIntent = false,
    MicStatus? mic,
    bool? busy,
  }) => OnboardingState(
    page: page ?? this.page,
    intent: clearIntent ? null : (intent ?? this.intent),
    mic: mic ?? this.mic,
    busy: busy ?? this.busy,
  );
}

class OnboardingController extends Notifier<OnboardingState> {
  /// Welcome · Intent · Sources · Privacy · Microphone.
  static const stepCount = 5;

  @override
  OnboardingState build() => const OnboardingState();

  void goTo(int page) {
    if (page < 0 || page >= stepCount || page == state.page) return;
    state = state.copyWith(page: page);
  }

  void next() => goTo(state.page + 1);
  void back() => goTo(state.page - 1);

  /// Tapping the selected option again clears it — the question is optional and
  /// must not become a trap with no way out of a choice.
  void selectIntent(DreamIntent value) {
    final clearing = state.intent == value;
    state = state.copyWith(
      intent: clearing ? null : value,
      clearIntent: clearing,
    );
  }

  /// Asks for microphone + speech recognition. Returns the resulting status so
  /// the caller can decide what to render; never throws, and `busy` can never
  /// stick — with busy stuck true every control on the mic step is disabled,
  /// including the "I'll type instead" escape hatch.
  Future<MicStatus> requestMic() async {
    if (state.busy) return state.mic;
    state = state.copyWith(busy: true);
    MicStatus result = MicStatus.denied;
    try {
      final ok = await ref.read(sttServiceProvider).init();
      result = ok ? MicStatus.granted : MicStatus.denied;
      await ref.read(settingsServiceProvider).setMicPrompted(true);
    } catch (_) {
      // A platform-channel failure is a denial from the user's point of view:
      // they can still type. Never let it take down onboarding.
    } finally {
      state = state.copyWith(mic: result, busy: false);
    }
    return result;
  }

  /// Clears any selection and moves on — what "Skip" means on the intent step.
  void skipIntent() {
    state = state.copyWith(clearIntent: true);
    next();
  }

  void skipMic() => state = state.copyWith(mic: MicStatus.skipped);

  /// Persists everything onboarding collected. Called once, on finish.
  Future<void> complete() async {
    final settings = ref.read(settingsServiceProvider);
    await settings.setIntent(state.intent);
    await settings.setOnboarded(true);
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );
