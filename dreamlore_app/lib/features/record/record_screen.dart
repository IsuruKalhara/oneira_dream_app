import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/errors.dart';
import '../../providers/providers.dart';
import '../../services/settings_service.dart';
import '../../services/share_card.dart';
import '../../ui/cards.dart';
import '../../ui/motion.dart';
import '../../ui/night.dart';
import '../../ui/scaffold.dart';
import '../../widgets/dream_image_card.dart';
import '../../widgets/interpretation_view.dart';
import '../../widgets/safety_view.dart';
import '../paywall/paywall_screen.dart';
import '../paywall/plus_upsell_sheet.dart';
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
      // The reading landed: a soft tap says so before the eye finds it.
      if (prev?.status != RecordStatus.done &&
          next.status == RecordStatus.done) {
        HapticFeedback.lightImpact();
      }
      // A Plus entitlement that lapsed mid-flow: the proxy said no, so offer
      // the way back rather than an error.
      if (next.imageNeedsPlus && !(prev?.imageNeedsPlus ?? false)) {
        PlusUpsellSheet.show(context);
      }
    });

    // One key per visual state, so live transcription (idle → listening →
    // ready) edits in place and only real state changes cross-fade.
    final stage = switch (state.status) {
      RecordStatus.interpreting => 'busy',
      RecordStatus.done => 'done',
      RecordStatus.safety => 'safety',
      RecordStatus.error => 'error',
      _ => 'capture',
    };
    final Widget body = StateSwitcher(
      child: KeyedSubtree(
        key: ValueKey(stage),
        child: switch (state.status) {
          RecordStatus.interpreting => _busy(context),
          RecordStatus.done => _done(context, state, ctl),
          RecordStatus.safety => SafetyView(onDismiss: ctl.reset),
          RecordStatus.error => _error(context, state, ctl),
          _ => _capture(context, state, ctl),
        },
      ),
    );

    return NightScaffold(
      title: 'Your dream',
      action:
          (state.status == RecordStatus.done ||
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

  Widget _capture(
    BuildContext context,
    RecordState state,
    RecordController ctl,
  ) {
    final t = Theme.of(context);
    final listening = state.status == RecordStatus.listening;
    final canInterpret = state.transcript.trim().isNotEmpty && !listening;

    return SingleChildScrollView(
      // Explicit padding drops the automatic extendBody inset — add the
      // nav-bar clearance back or the Interpret pill hides under the capsule
      // on short screens and large text scales.
      padding: EdgeInsets.fromLTRB(
        22,
        0,
        22,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        children: [
          _quotaBanner(context),
          const SizedBox(height: 28),
          Semantics(
            button: true,
            label: listening ? 'Stop recording' : 'Start recording your dream',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                ctl.toggleListening();
              },
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
                fontSize: 15,
                height: 1.5,
                color: Ob.parchment,
              ),
              decoration: const InputDecoration(
                hintText:
                    'Your words appear here. You can type or fix them too.',
                hintStyle: TextStyle(color: Ob.muted, height: 1.5),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          PrimaryPill(
            label: 'What does it mean?',
            sub: canInterpret ? 'We look it up in real dream books' : null,
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
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const PaywallScreen())),
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
          const _LibrarySearch(),
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
          const _SearchCaption(),
        ],
      ),
    ),
  );

  Widget _done(BuildContext context, RecordState state, RecordController ctl) {
    final isPaid = ref.watch(entitlementProvider);
    final bytes = state.imageBytes;
    return Column(
      children: [
        Expanded(
          child: InterpretationView(
            transcript: state.transcript,
            interp: state.interpretation!,
            picture: DreamImageCard(
              status: state.imageStatus,
              locked: !isPaid,
              bytes: bytes,
              error: state.imageError,
              // Free users get the offer, not a request that would only 403.
              onGenerate: isPaid
                  ? ctl.imagine
                  : () => PlusUpsellSheet.show(context),
              onShare: bytes == null
                  ? null
                  : () => ShareCard.share(
                      context: context,
                      imageBytes: bytes,
                      dream: state.transcript,
                    ),
            ),
          ),
        ),
        Padding(
          // Bottom inset keeps the pill clear of the floating nav capsule.
          padding: EdgeInsets.fromLTRB(
            22,
            8,
            22,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
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
    // Anything else is the reading failing: offline, slow, or the proxy
    // answering with a 5xx. Friendly turns that into the right next step.
    final friendly = (q == null && !micError) ? Friendly.of(state.error) : null;
    return EmptyState(
      icon: q != null
          ? Icons.lock_clock
          : micError
          ? Icons.mic_off_outlined
          : friendly!.icon,
      tint: q != null || friendly?.offline == true
          ? null
          : Theme.of(context).colorScheme.error,
      title: q != null
          ? "That's all your readings for ${q.reason == 'monthly' ? 'this month' : 'today'}"
          : micError
          ? 'The microphone is not available'
          : friendly!.title,
      body: q != null
          ? (q.resetsAt != null
                ? 'Your next one unlocks ${_friendly(q.resetsAt!)}. Your dream is still here.'
                : 'Your dream is still here — come back when it resets.')
          : micError
          ? 'Allow the microphone in your device settings, or type your '
                'dream instead — readings are identical either way.'
          : friendly!.body,
      action: Column(
        children: [
          if (q != null && q.upgrade)
            PrimaryPill(
              label: 'Get more readings',
              sub: 'Dreamlore Plus',
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const PaywallScreen())),
            )
          else if (micError) ...[
            PrimaryPill(
              label: 'Open device settings',
              sub: 'Turn the microphone on',
              onPressed: () => openAppSettings(),
            ),
            TextButton(
              onPressed: ctl.reset,
              child: const Text(
                "I'll type instead",
                style: TextStyle(color: Ob.muted),
              ),
            ),
          ] else if (q == null)
            PrimaryPill(
              label: 'Try again',
              sub: 'Your dream is kept',
              onPressed: ctl.interpret,
            ),
          if (!micError)
            TextButton(
              onPressed: ctl.reset,
              child: const Text(
                'Start over',
                style: TextStyle(color: Ob.muted),
              ),
            ),
        ],
      ),
    );
  }

  String _friendly(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final days = DateTime(
      local.year,
      local.month,
      local.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
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

class _MicOrbState extends State<_MicOrb> with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  /// Drives the ripples while listening: rings are born at the orb's edge and
  /// travel outward, fading as they go. A ring's size at birth follows the
  /// voice, so speaking louder visibly pushes bigger waves — evidence the mic
  /// hears you, which is the doubt this screen has to settle.
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
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
  void didUpdateWidget(_MicOrb old) {
    super.didUpdateWidget(old);
    if (MediaQuery.disableAnimationsOf(context)) return;
    if (widget.listening && !_ripple.isAnimating) _ripple.repeat();
    if (!widget.listening && _ripple.isAnimating) _ripple.stop();
  }

  @override
  void dispose() {
    _breath.dispose();
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.level,
      builder: (context, level, _) => AnimatedBuilder(
        animation: Listenable.merge([_breath, _ripple]),
        builder: (context, _) {
          // Voice drives the ring while listening; the slow breath drives it
          // otherwise. Only ever one source, so they never fight.
          final energy = widget.listening ? level : _breath.value * 0.35;
          return SizedBox(
            width: 260,
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.listening)
                  CustomPaint(
                    size: const Size(260, 260),
                    painter: _RipplePainter(
                      t: _ripple.value,
                      level: level,
                      color: widget.color,
                    ),
                  ),
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

/// Three rings, evenly phased, expanding from the orb's edge to the bounds and
/// fading out. Stroke width and starting radius grow with the voice level.
class _RipplePainter extends CustomPainter {
  final double t;
  final double level;
  final Color color;
  const _RipplePainter({
    required this.t,
    required this.level,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    const rings = 3;
    const inner = 74.0; // orb radius
    final outer = size.width / 2;
    for (var i = 0; i < rings; i++) {
      final phase = (t + i / rings) % 1.0;
      final r = inner + (outer - inner) * phase + level * 10;
      final alpha = (1 - phase) * (0.35 + level * 0.4);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 + level * 2.5 + (1 - phase) * 1.5
          ..color = color.withValues(alpha: alpha.clamp(0.0, 0.8)),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.t != t || old.level != level || old.color != color;
}

/// The wait, shown as what is happening: the three books of the library,
/// fanned like a hand of cards, each lit in turn as it is read, with a slow
/// beam sweeping across them. Honest — retrieval really does go book by
/// book — and far more alive than a spinner for a wait of up to half a minute.
class _LibrarySearch extends StatefulWidget {
  const _LibrarySearch();

  @override
  State<_LibrarySearch> createState() => _LibrarySearchState();
}

class _LibrarySearchState extends State<_LibrarySearch>
    with SingleTickerProviderStateMixin {
  static const _books = [
    (title: 'The Interpretation\nof Dreams', cover: 'assets/brand/book1.jpg'),
    (title: 'Dream\nPsychology', cover: 'assets/brand/book2.jpg'),
    (
      title: 'Ten Thousand\nDreams Interpreted',
      cover: 'assets/brand/book3.jpg',
    ),
  ];

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  bool _configured = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configured) return;
    _configured = true;
    if (!MediaQuery.disableAnimationsOf(context)) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 300,
      height: 200,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final t = _c.value;
          // Which book is "open" right now: thirds of the cycle.
          final active = (t * 3).floor() % 3;
          final within = (t * 3) % 1.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                _BookCard(
                  title: _books[i].title,
                  cover: _books[i].cover,
                  angle: (i - 1) * 0.22,
                  offset: Offset((i - 1) * 78.0, i == 1 ? -14 : 0),
                  lit: i == active,
                  glow: i == active ? math.sin(within * math.pi) : 0,
                  color: primary,
                ),
              // The reading beam: a soft band sweeping across the hand once
              // per cycle.
              IgnorePointer(
                child: Align(
                  alignment: Alignment(-1.4 + t * 2.8, 0),
                  child: Container(
                    width: 70,
                    height: 200,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primary.withValues(alpha: 0),
                          primary.withValues(alpha: 0.22),
                          primary.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final String title;
  final String cover;
  final double angle;
  final Offset offset;
  final bool lit;
  final double glow;
  final Color color;
  const _BookCard({
    required this.title,
    required this.cover,
    required this.angle,
    required this.offset,
    required this.lit,
    required this.glow,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset + Offset(0, lit ? -10 * glow : 0),
      child: Transform.rotate(
        angle: angle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          width: 112,
          height: 156,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: lit
                  ? color.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: 0.10),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5 * glow),
                blurRadius: 30 * glow + 6,
                spreadRadius: 2 * glow,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The cover, dimmed until this book is the one being read.
                AnimatedOpacity(
                  opacity: lit ? 1 : 0.45,
                  duration: const Duration(milliseconds: 500),
                  child: Image.asset(
                    cover,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(color: Ob.inkDeep),
                  ),
                ),
                // The title, legible over the art.
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(9, 18, 9, 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Ob.inkDeep.withValues(alpha: 0),
                          Ob.inkDeep.withValues(alpha: 0.92),
                        ],
                      ),
                    ),
                    child: Text(
                      title,
                      style: Ob.serif(
                        size: 11,
                        style: FontStyle.italic,
                        height: 1.2,
                        color: Ob.parchment.withValues(alpha: lit ? 1 : 0.75),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the app is doing right now, one line at a time, in the same rhythm
/// as the books lighting up.
class _SearchCaption extends StatefulWidget {
  const _SearchCaption();
  @override
  State<_SearchCaption> createState() => _SearchCaptionState();
}

class _SearchCaptionState extends State<_SearchCaption> {
  static const _lines = [
    'Opening The Interpretation of Dreams…',
    'Reading Dream Psychology…',
    'Checking Ten Thousand Dreams Interpreted…',
    'Writing it out for you…',
  ];
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (mounted) setState(() => _i = (_i + 1) % _lines.length);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.base,
      switchInCurve: Motion.curve,
      transitionBuilder: (w, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(a),
          child: w,
        ),
      ),
      child: Text(
        _lines[_i],
        key: ValueKey(_i),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14.5, height: 1.5, color: Ob.muted),
      ),
    );
  }
}
