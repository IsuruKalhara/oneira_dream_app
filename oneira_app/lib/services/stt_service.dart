import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// On-device speech-to-text. No audio leaves the phone; we only keep the
/// transcript. Free, private, and works offline on most modern devices.
class SttService {
  final SpeechToText _speech = SpeechToText();
  bool _available = false;

  /// Live mic loudness, smoothed and normalised to 0–1.
  ///
  /// Exposed as a [ValueNotifier] rather than as controller state on purpose:
  /// it changes many times a second, and routing it through the state machine
  /// would rebuild the whole Record screen on every frame. Only the widget
  /// that draws the orb listens.
  final ValueNotifier<double> level = ValueNotifier(0);

  /// Session-end callback for the CURRENT listen. The plugin stops itself in
  /// three ways the UI must know about — `pauseFor` silence, the `listenFor`
  /// cap, and platform errors — or the recorder gets stuck showing
  /// "Listening…" while the mic is actually off and speech is silently lost.
  /// initialize() only accepts its callbacks once, so they route through this
  /// mutable field.
  void Function()? _onSessionEnd;
  bool _listening = false;

  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  Future<bool> init() async {
    if (_available) return true;
    _available = await _speech.initialize(
      onError: (_) => _endSession(),
      onStatus: (status) {
        // 'notListening'/'done' arrive when the plugin stops on its own.
        if (status == 'notListening' || status == 'done') _endSession();
      },
    );
    return _available;
  }

  void _endSession() {
    if (!_listening) return;
    _listening = false;
    level.value = 0;
    final cb = _onSessionEnd;
    _onSessionEnd = null;
    cb?.call();
  }

  Future<void> start({
    required void Function(String text, bool isFinal) onResult,
    void Function()? onSessionEnd,
  }) async {
    if (!_available) await init();
    _onSessionEnd = onSessionEnd;
    _listening = true;
    await _speech.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      onSoundLevelChange: (raw) {
        // Platforms report different ranges: Android ~0..10, iOS negative
        // decibels (~-60..0). Normalise each, then ease toward the target so
        // the orb breathes instead of flickering.
        final target = raw < 0
            ? ((raw + 50) / 50).clamp(0.0, 1.0)
            : (raw / 10).clamp(0.0, 1.0);
        level.value = level.value + (target - level.value) * 0.35;
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(minutes: 2),
        // Recalling a dream involves long pauses — 6s cut people off mid-recall.
        pauseFor: const Duration(seconds: 12),
      ),
    );
  }

  Future<void> stop() async {
    // A user-initiated stop is not a surprise ending — don't fire the callback.
    _onSessionEnd = null;
    _listening = false;
    await _speech.stop();
    level.value = 0;
  }

  void dispose() {
    _onSessionEnd = null;
    _speech.cancel();
    level.dispose();
  }
}
