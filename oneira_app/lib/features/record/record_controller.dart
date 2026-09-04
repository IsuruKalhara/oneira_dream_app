import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models.dart';
import '../../data/safety.dart';
import '../../services/stt_service.dart';
import '../../providers/providers.dart';

enum RecordStatus { idle, listening, ready, interpreting, done, safety, error }

/// What went wrong, so the error screen can offer the right recovery:
/// retrying interpretation is useless against a denied microphone.
enum RecordErrorSource { mic, interpretation }

class RecordState {
  final RecordStatus status;
  final String transcript;
  final Interpretation? interpretation;
  final QuotaInfo? quota;
  final QuotaExceededException? quotaError;
  final String? error;
  final RecordErrorSource? errorSource;
  final String? savedId;

  const RecordState({
    this.status = RecordStatus.idle,
    this.transcript = '',
    this.interpretation,
    this.quota,
    this.quotaError,
    this.error,
    this.errorSource,
    this.savedId,
  });

  RecordState copyWith({
    RecordStatus? status,
    String? transcript,
    Interpretation? interpretation,
    QuotaInfo? quota,
    String? savedId,
    bool clearSavedId = false,
    QuotaExceededException? quotaError, // transient: cleared unless passed
    String? error, // transient: cleared unless passed
    RecordErrorSource? errorSource, // transient: cleared unless passed
  }) =>
      RecordState(
        status: status ?? this.status,
        transcript: transcript ?? this.transcript,
        interpretation: interpretation ?? this.interpretation,
        quota: quota ?? this.quota,
        savedId: clearSavedId ? null : (savedId ?? this.savedId),
        quotaError: quotaError,
        error: error,
        errorSource: errorSource,
      );
}

class RecordController extends Notifier<RecordState> {
  @override
  RecordState build() => const RecordState();

  SttService get _stt => ref.read(sttServiceProvider);

  /// Text present before the current listen started. New recognition results
  /// are appended to it, so re-tapping the mic ADDS a forgotten detail rather
  /// than destroying the dream — wiping on restart was unrecoverable data loss
  /// in the app's core flow.
  String _base = '';

  Future<void> toggleListening() async {
    if (state.status == RecordStatus.listening) {
      await stop();
      return;
    }
    final ok = await _stt.init();
    if (!ok) {
      state = state.copyWith(
        status: RecordStatus.error,
        errorSource: RecordErrorSource.mic,
        error: 'Microphone or speech recognition is unavailable.',
      );
      return;
    }
    final existing = state.transcript.trim();
    _base = existing.isEmpty ? '' : '$existing ';
    state = state.copyWith(status: RecordStatus.listening);
    await _stt.start(
      onResult: (text, _) {
        if (state.status == RecordStatus.listening) {
          state = state.copyWith(transcript: '$_base$text');
        }
      },
      // The plugin stops itself after 12s of silence, at the 2-minute cap, or
      // on a platform error. Without this the UI stayed on "Listening…" with
      // the mic actually off, silently discarding everything said next.
      onSessionEnd: _settleAfterListening,
    );
  }

  void _settleAfterListening() {
    if (state.status != RecordStatus.listening) return;
    state = state.copyWith(
      status: state.transcript.trim().isEmpty
          ? RecordStatus.idle
          : RecordStatus.ready,
    );
  }

  Future<void> stop() async {
    await _stt.stop();
    _settleAfterListening();
  }

  void editTranscript(String t) {
    // Touching the text field while recording must actually stop the mic —
    // otherwise it keeps running (OS indicator lit) with results discarded,
    // and the next mic tap double-starts the plugin.
    if (state.status == RecordStatus.listening) {
      _stt.stop();
    }
    state = state.copyWith(
      transcript: t,
      status: t.trim().isEmpty ? RecordStatus.idle : RecordStatus.ready,
    );
  }

  Future<void> interpret() async {
    final text = state.transcript.trim();
    if (text.isEmpty) return;

    if (SafetyCheck.isConcerning(text)) {
      state = state.copyWith(status: RecordStatus.safety);
      return;
    }

    state = state.copyWith(status: RecordStatus.interpreting);
    try {
      final res = await ref.read(dreamApiProvider).explain(text);
      state = state.copyWith(
        status: RecordStatus.done,
        interpretation: res.interpretation,
        quota: res.quota,
      );
      ref.invalidate(quotaProvider);
      // Auto-save: on the free tier this reading may be the only one the user
      // gets today — it must never be losable to a mistap or an app switch.
      await save();
    } on QuotaExceededException catch (e) {
      state = state.copyWith(status: RecordStatus.error, quotaError: e);
    } catch (e) {
      state = state.copyWith(
        status: RecordStatus.error,
        error: 'The reading could not be completed. Check your connection '
            'and try again — your dream is still here.',
        errorSource: RecordErrorSource.interpretation,
      );
      // Keep the real error out of the UI but not out of reach.
      // ignore: avoid_print
      print('interpret failed: $e');
    }
  }

  /// Idempotent: repeated calls (double-tap, auto-save then manual) reuse the
  /// same id, so the journal can never receive duplicates.
  Future<String?> save() async {
    final interp = state.interpretation;
    if (interp == null) return null;
    final id = state.savedId ?? const Uuid().v4();
    await ref.read(dreamRepositoryProvider).save(
          id: id,
          createdAt: DateTime.now(),
          transcript: state.transcript.trim(),
          interp: interp,
        );
    state = state.copyWith(savedId: id);
    return id;
  }

  void reset() {
    _base = '';
    state = const RecordState();
  }
}

final recordControllerProvider =
    NotifierProvider<RecordController, RecordState>(RecordController.new);
