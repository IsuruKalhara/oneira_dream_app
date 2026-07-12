import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models.dart';
import '../../data/safety.dart';
import '../../services/stt_service.dart';
import '../../providers/providers.dart';

enum RecordStatus { idle, listening, ready, interpreting, done, safety, error }

class RecordState {
  final RecordStatus status;
  final String transcript;
  final Interpretation? interpretation;
  final QuotaInfo? quota;
  final QuotaExceededException? quotaError;
  final String? error;
  final String? savedId;

  const RecordState({
    this.status = RecordStatus.idle,
    this.transcript = '',
    this.interpretation,
    this.quota,
    this.quotaError,
    this.error,
    this.savedId,
  });

  RecordState copyWith({
    RecordStatus? status,
    String? transcript,
    Interpretation? interpretation,
    QuotaInfo? quota,
    String? savedId,
    QuotaExceededException? quotaError, // transient: cleared unless passed
    String? error, // transient: cleared unless passed
  }) =>
      RecordState(
        status: status ?? this.status,
        transcript: transcript ?? this.transcript,
        interpretation: interpretation ?? this.interpretation,
        quota: quota ?? this.quota,
        savedId: savedId ?? this.savedId,
        quotaError: quotaError,
        error: error,
      );
}

class RecordController extends Notifier<RecordState> {
  @override
  RecordState build() => const RecordState();

  SttService get _stt => ref.read(sttServiceProvider);

  Future<void> toggleListening() async {
    if (state.status == RecordStatus.listening) {
      await stop();
      return;
    }
    final ok = await _stt.init();
    if (!ok) {
      state = state.copyWith(
        status: RecordStatus.error,
        error: 'Microphone or speech recognition is unavailable. '
            'Check the app permissions and try again.',
      );
      return;
    }
    state = state.copyWith(status: RecordStatus.listening, transcript: '');
    await _stt.start(onResult: (text, _) {
      if (state.status == RecordStatus.listening) {
        state = state.copyWith(transcript: text);
      }
    });
  }

  Future<void> stop() async {
    await _stt.stop();
    state = state.copyWith(
      status: state.transcript.trim().isEmpty
          ? RecordStatus.idle
          : RecordStatus.ready,
    );
  }

  void editTranscript(String t) => state = state.copyWith(
        transcript: t,
        status: t.trim().isEmpty ? RecordStatus.idle : RecordStatus.ready,
      );

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
    } on QuotaExceededException catch (e) {
      state = state.copyWith(status: RecordStatus.error, quotaError: e);
    } catch (e) {
      state = state.copyWith(status: RecordStatus.error, error: e.toString());
    }
  }

  Future<String?> save() async {
    final interp = state.interpretation;
    if (interp == null) return null;
    final id = const Uuid().v4();
    await ref.read(dreamRepositoryProvider).save(
          id: id,
          createdAt: DateTime.now(),
          transcript: state.transcript.trim(),
          interp: interp,
        );
    state = state.copyWith(savedId: id);
    return id;
  }

  void reset() => state = const RecordState();
}

final recordControllerProvider =
    NotifierProvider<RecordController, RecordState>(RecordController.new);
