import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors.dart';
import '../../data/api/dream_api.dart';
import '../../core/telemetry.dart';
import '../../data/models.dart';
import '../../data/safety.dart';
import '../../widgets/dream_image_card.dart';
import '../../services/stt_service.dart';
import '../../providers/providers.dart';

enum RecordStatus { idle, listening, ready, interpreting, done, safety, error }

/// Which step failed, so the screen can point the retry at the right thing —
/// a mic permission problem and a failed interpretation need different words.
enum RecordErrorSource { mic, interpretation }

class RecordState {
  final RecordStatus status;
  final String transcript;
  final Interpretation? interpretation;
  final QuotaInfo? quota;
  final QuotaExceededException? quotaError;

  /// The thrown object, not its text. `Friendly.of` classifies a DioException
  /// by type — offline vs timeout vs 5xx — and `e.toString()` threw that away,
  /// so every network failure surfaced as "Something went sideways" instead of
  /// "You're offline". Widened to Object? deliberately.
  final Object? error;
  final RecordErrorSource? errorSource;

  /// Set the moment the reading is saved — which is the moment it arrives.
  final String? savedId;

  /// The dream's picture. Painted right after the reading for Plus, kept in
  /// memory for the reveal, and written next to the entry as soon as it lands.
  final Uint8List? imageBytes;
  final DreamImageStatus imageStatus;
  final String? imageError;

  /// True when the proxy refused a picture because this device isn't on Plus
  /// — the UI shows the upgrade rather than an error.
  final bool imageNeedsPlus;

  const RecordState({
    this.status = RecordStatus.idle,
    this.transcript = '',
    this.interpretation,
    this.quota,
    this.quotaError,
    this.error,
    this.errorSource,
    this.savedId,
    this.imageBytes,
    this.imageStatus = DreamImageStatus.idle,
    this.imageError,
    this.imageNeedsPlus = false,
  });

  RecordState copyWith({
    RecordStatus? status,
    String? transcript,
    Interpretation? interpretation,
    QuotaInfo? quota,
    String? savedId,
    QuotaExceededException? quotaError, // transient: cleared unless passed
    Object? error, // transient
    RecordErrorSource? errorSource, // transient: cleared unless passed
    Uint8List? imageBytes,
    DreamImageStatus? imageStatus,
    String? imageError, // transient
    bool imageNeedsPlus = false, // transient
  }) => RecordState(
    status: status ?? this.status,
    transcript: transcript ?? this.transcript,
    interpretation: interpretation ?? this.interpretation,
    quota: quota ?? this.quota,
    savedId: savedId ?? this.savedId,
    quotaError: quotaError,
    error: error,
    errorSource: errorSource,
    imageBytes: imageBytes ?? this.imageBytes,
    imageStatus: imageStatus ?? this.imageStatus,
    imageError: imageError,
    imageNeedsPlus: imageNeedsPlus,
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
        error:
            'Microphone or speech recognition is unavailable. '
            'Check the app permissions and try again.',
        errorSource: RecordErrorSource.mic,
      );
      return;
    }
    state = state.copyWith(status: RecordStatus.listening, transcript: '');
    await _stt.start(
      onResult: (text, _) {
        if (state.status == RecordStatus.listening) {
          state = state.copyWith(transcript: text);
        }
      },
    );
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

  /// Reads the dream, saves the reading the moment it arrives, and — on Plus
  /// — starts painting it straight away. The free tier may only get one
  /// reading a day, so nothing about it is ever left to a "Save" tap.
  Future<void> interpret() async {
    final text = state.transcript.trim();
    if (text.isEmpty) return;

    if (SafetyCheck.isConcerning(text)) {
      state = state.copyWith(status: RecordStatus.safety);
      return;
    }

    state = state.copyWith(status: RecordStatus.interpreting);
    final started = DateTime.now();
    try {
      final res = await ref.read(dreamApiProvider).explain(text);
      final id = await _save(text, res.interpretation);
      state = state.copyWith(
        status: RecordStatus.done,
        interpretation: res.interpretation,
        quota: res.quota,
        savedId: id,
      );
      ref.invalidate(quotaProvider);
      unawaited(
        Telemetry.dreamInterpreted(
          elapsedMs: DateTime.now().difference(started).inMilliseconds,
          dreamChars: text.length,
          tier: res.quota?.tier ?? 'free',
        ),
      );
      // Plus: the picture is part of the reading, not a second ask. Free: the
      // card shows the invitation, and the upsell is one tap away.
      if (ref.read(entitlementProvider)) unawaited(imagine());
    } on QuotaExceededException catch (e) {
      state = state.copyWith(status: RecordStatus.error, quotaError: e);
      unawaited(Telemetry.quotaHit(period: e.reason));
    } catch (e, st) {
      state = state.copyWith(
        status: RecordStatus.error,
        error: e,
        errorSource: RecordErrorSource.interpretation,
      );
      // A reading that fails is invisible to the crash dashboard otherwise:
      // the app did not crash, it just did not work.
      unawaited(Telemetry.recordFailure(e, st, during: 'interpret'));
    }
  }

  Future<String> _save(String text, Interpretation interp) async {
    final id = state.savedId ?? const Uuid().v4();
    await ref
        .read(dreamRepositoryProvider)
        .save(
          id: id,
          createdAt: DateTime.now(),
          transcript: text,
          interp: interp,
        );
    return id;
  }

  /// Paints the dream and writes the picture into the saved entry. The caller
  /// has already decided this device may (it checks the entitlement first and
  /// shows the upsell otherwise); the proxy still has the final say, and a 403
  /// here means the entitlement lapsed.
  Future<void> imagine() async {
    final interp = state.interpretation;
    final text = state.transcript.trim();
    if (interp == null || text.isEmpty) return;
    if (state.imageStatus == DreamImageStatus.generating) return;

    state = state.copyWith(imageStatus: DreamImageStatus.generating);
    try {
      final bytes = await ref
          .read(dreamApiProvider)
          .imagine(text, symbols: interp.symbols);
      final id = state.savedId;
      if (id != null) {
        final store = ref.read(imageStoreProvider);
        // Filenames are unique per generation, so a repaint would otherwise
        // leave the previous picture on disk with nothing pointing at it.
        await store.deleteAllFor(id);
        final path = await store.save(id, bytes);
        await ref.read(dreamRepositoryProvider).setImagePath(id, path);
      }
      state = state.copyWith(
        imageStatus: DreamImageStatus.ready,
        imageBytes: bytes,
      );
      ref.invalidate(quotaProvider);
    } on PlusRequiredException {
      state = state.copyWith(
        imageStatus: DreamImageStatus.idle,
        imageNeedsPlus: true,
      );
      unawaited(ref.read(entitlementProvider.notifier).refresh());
    } on QuotaExceededException catch (e) {
      state = state.copyWith(
        imageStatus: DreamImageStatus.error,
        imageError: e.reason == 'monthly'
            ? "You've painted all your dreams for this month."
            : "You've painted all your dreams for today.",
      );
    } catch (e) {
      final f = Friendly.of(e);
      state = state.copyWith(
        imageStatus: DreamImageStatus.error,
        imageError: f.offline
            ? "You're offline — the reading is saved; paint it from your journal later."
            : null,
      );
    }
  }

  void reset() => state = const RecordState();
}

final recordControllerProvider =
    NotifierProvider<RecordController, RecordState>(RecordController.new);
