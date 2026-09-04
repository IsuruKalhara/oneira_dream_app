import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/providers.dart';
import '../../services/settings_service.dart';
import '../../ui/cards.dart';
import '../../ui/night.dart';
import '../../ui/scaffold.dart';
import '../../widgets/interpretation_view.dart';
import '../../widgets/safety_view.dart';
import '../paywall/paywall_screen.dart';
import 'record_controller.dart';

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});
  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordControllerProvider);
    final ctl = ref.read(recordControllerProvider.notifier);

    // Keep the text field in sync with live transcription without fighting edits.
    ref.listen(recordControllerProvider, (prev, next) {
      if (next.transcript != _text.text) {
        _text.value = TextEditingValue(
          text: next.transcript,
          selection: TextSelection.collapsed(offset: next.transcript.length),
        );
      }
    });

    final Widget body = switch (state.status) {
      RecordStatus.interpreting => _busy(context),
      RecordStatus.done => _done(context, state, ctl),
      RecordStatus.safety => SafetyView(onDismiss: ctl.reset),
      RecordStatus.error => _error(context, state, ctl),
      _ => _capture(context, state, ctl),
    };

    return NightScaffold(
      title: 'Log a dream',
      action: (state.status == RecordStatus.done ||
              state.status == RecordStatus.error)
          ? IconButton(
              tooltip: 'New dream',
              onPressed: ctl.reset,
              icon: const Icon(Icons.refresh, color: Ob.muted),
            )
          : null,
      child: body,
    );
  }

  /// The payoff for the onboarding "what brings you here?" question — the
  /// answer tailors this line and nothing else.
  String _idlePrompt() {
    switch (ref.read(settingsServiceProvider).intent) {
      case DreamIntent.recall:
        return 'Tap and say what you remember — even fragments';
      case DreamIntent.recurring:
        return 'Tap and tell me the dream again';
      case DreamIntent.patterns:
        return "Tap and add tonight's dream";
      case DreamIntent.curiosity:
      case null:
        return 'Tap and tell me your dream';
    }
  }

  Widget _capture(BuildContext context, RecordState state, RecordController ctl) {
    final t = Theme.of(context);
    final listening = state.status == RecordStatus.listening;
    final canInterpret = state.transcript.trim().isNotEmpty && !listening;

    return SingleChildScrollView(
      // Explicit padding drops the automatic extendBody inset — add the
      // nav-bar clearance back or the Interpret pill hides under the capsule
      // on short screens and large text scales.
      padding: EdgeInsets.fromLTRB(
          22, 0, 22, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        children: [
          _quotaBanner(context),
          const SizedBox(height: 28),
          Semantics(
            button: true,
            label: listening
                ? 'Stop recording'
                : 'Start recording your dream',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: ctl.toggleListening,
              child: _MicOrb(
                listening: listening,
                level: ref.read(sttServiceProvider).level,
                color: listening ? t.colorScheme.error : t.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            listening ? 'Listening… tap to stop' : _idlePrompt(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Ob.parchment,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: TextField(
              controller: _text,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              onChanged: ctl.editTranscript,
              style: const TextStyle(
                  fontSize: 15, height: 1.5, color: Ob.parchment),
              decoration: const InputDecoration(
                hintText: 'Your dream will appear here — you can edit it too.',
                hintStyle: TextStyle(color: Ob.muted, height: 1.5),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          PrimaryPill(
            label: 'Interpret',
            sub: canInterpret ? 'Reads it against the library' : null,
            onPressed: canInterpret ? ctl.interpret : null,
          ),
        ],
      ),
    );
  }

  Widget _quotaBanner(BuildContext context) {
    final quota = ref.watch(quotaProvider).asData?.value;
    if (quota == null || quota.isPaid) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 16, color: Ob.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${quota.dayRemaining} of ${quota.dayLimit} free readings left today',
              style: const TextStyle(fontSize: 13, color: Ob.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PaywallScreen())),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  /// Moonly narrates long waits with labelled progress rather than a bare
  /// spinner. These three steps are what actually happens server-side, so the
  /// narration is honest rather than theatre.
  Widget _busy(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _PulsingOrb(),
              const SizedBox(height: 30),
              const Text(
                'Reading your dream',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: Ob.parchment,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Searching the library, then writing a reading that quotes it.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, height: 1.5, color: Ob.muted),
              ),
            ],
          ),
        ),
      );

  Widget _done(BuildContext context, RecordState state, RecordController ctl) {
    return Column(
      children: [
        Expanded(
          child: InterpretationView(
            transcript: state.transcript,
            interp: state.interpretation!,
          ),
        ),
        Padding(
          // Bottom inset keeps the pill clear of the floating nav capsule.
          padding: EdgeInsets.fromLTRB(
              22, 8, 22, 12 + MediaQuery.paddingOf(context).bottom),
          child: PrimaryPill(
            label: 'Done',
            // The reading auto-saved the moment it arrived — on the free tier
            // it may be the only one today, so it is never losable.
            sub: 'Saved to your journal',
            onPressed: ctl.reset,
          ),
        ),
      ],
    );
  }

  Widget _error(BuildContext context, RecordState state, RecordController ctl) {
    final q = state.quotaError;
    final micError = state.errorSource == RecordErrorSource.mic;
    return EmptyState(
      icon: q != null
          ? Icons.lock_clock
          : micError
              ? Icons.mic_off_outlined
              : Icons.error_outline,
      tint: q != null ? null : Theme.of(context).colorScheme.error,
      title: q != null
          ? "That's all your readings for ${q.reason == 'monthly' ? 'this month' : 'today'}"
          : micError
              ? 'The microphone is not available'
              : 'Something went wrong',
      body: q != null
          ? (q.resetsAt != null
              ? 'Your next one unlocks ${_friendly(q.resetsAt!)}. Your dream is still here.'
              : 'Your dream is still here — come back when it resets.')
          : micError
              ? 'Allow the microphone in your device settings, or type your '
                  'dream instead — readings are identical either way.'
              : (state.error ?? 'Please try again.'),
      action: Column(
        children: [
          if (q != null && q.upgrade)
            PrimaryPill(
              label: 'Get more readings',
              sub: 'Dreamlore Plus',
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaywallScreen())),
            )
          else if (micError) ...[
            PrimaryPill(
              label: 'Open device settings',
              sub: 'Turn the microphone on',
              onPressed: () => openAppSettings(),
            ),
            TextButton(
              onPressed: ctl.reset,
              child: const Text("I'll type instead",
                  style: TextStyle(color: Ob.muted)),
            ),
          ] else if (q == null)
            PrimaryPill(label: 'Try again', onPressed: ctl.interpret),
          if (!micError)
            TextButton(
              onPressed: ctl.reset,
              child:
                  const Text('Start over', style: TextStyle(color: Ob.muted)),
            ),
        ],
      ),
    );
  }

  String _friendly(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final days = DateTime(local.year, local.month, local.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (days <= 0) return 'at $hh:$mm';
    if (days == 1) return 'tomorrow at $hh:$mm';
    // Monthly resets weeks away must not claim "tomorrow" — that told free
    // users their readings return early, at the exact moment of the upsell.
    return 'on ${DateFormat('d MMMM').format(local)}';
  }
}


/// The record button. Two states, both alive:
///
/// * **Idle** — breathes slowly, so the screen never looks frozen at 6am.
/// * **Listening** — the halo swells with your actual voice. `speech_to_text`
///   reports live loudness and the app was throwing it away; without it a user
///   has no evidence the mic is hearing them, which is the single most common
///   doubt on this screen.
class _MicOrb extends StatefulWidget {
  final bool listening;
  final ValueNotifier<double> level;
  final Color color;

  const _MicOrb({
    required this.listening,
    required this.level,
    required this.color,
  });

  @override
  State<_MicOrb> createState() => _MicOrbState();
}

class _MicOrbState extends State<_MicOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  bool _configured = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configured) return;
    _configured = true;
    if (!MediaQuery.disableAnimationsOf(context)) _breath.repeat(reverse: true);
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.level,
      builder: (context, level, _) => AnimatedBuilder(
        animation: _breath,
        builder: (context, _) {
          // Voice drives the ring while listening; the slow breath drives it
          // otherwise. Only ever one source, so they never fight.
          final energy = widget.listening ? level : _breath.value * 0.35;
          return SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Halo that swells with the voice.
                Container(
                  width: 148 + energy * 46,
                  height: 148 + energy * 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.10 + energy * 0.16),
                  ),
                ),
                Orb(
                  size: 148,
                  color: widget.color,
                  icon: widget.listening
                      ? Icons.stop_rounded
                      : Icons.mic_rounded,
                  lit: true,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Slow breathing orb for the interpretation wait — the one place in the app
/// where the user is asked to sit still for up to half a minute.
class _PulsingOrb extends StatefulWidget {
  const _PulsingOrb();

  @override
  State<_PulsingOrb> createState() => _PulsingOrbState();
}

class _PulsingOrbState extends State<_PulsingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  bool _configured = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configured) return;
    _configured = true;
    if (!MediaQuery.disableAnimationsOf(context)) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      builder: (_, _) => Transform.scale(
        scale: 0.92 + 0.08 * _c.value,
        child: Orb(size: 104, color: primary, lit: true),
      ),
    );
  }
}
