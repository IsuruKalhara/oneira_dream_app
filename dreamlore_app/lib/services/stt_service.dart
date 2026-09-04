import 'package:speech_to_text/speech_to_text.dart';

/// On-device speech-to-text. No audio leaves the phone; we only keep the
/// transcript. Free, private, and works offline on most modern devices.
class SttService {
  final SpeechToText _speech = SpeechToText();
  bool _available = false;

  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  Future<bool> init() async {
    if (_available) return true;
    _available = await _speech.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
    return _available;
  }

  Future<void> start({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    if (!_available) await init();
    await _speech.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> stop() => _speech.stop();

  void dispose() => _speech.cancel();
}
