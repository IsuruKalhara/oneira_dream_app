import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/motion.dart';
import '../ui/night.dart';

enum DreamImageStatus { idle, generating, ready, error }

/// The picture of a dream, in every state it passes through: an invitation to
/// make one, the wait while it is painted, the reveal, and a failure. One
/// widget so the record result and a saved entry look and behave the same.
///
/// Free users see the same invitation with a Plus mark on it; what happens on
/// tap is the caller's decision (an upsell sheet), so the card itself never
/// knows about billing. Likewise [onShare]: the card offers the action, the
/// caller composes the share.
class DreamImageCard extends StatelessWidget {
  const DreamImageCard({
    super.key,
    required this.status,
    required this.locked,
    required this.onGenerate,
    this.onShare,
    this.bytes,
    this.path,
    this.error,
  });

  final DreamImageStatus status;
  final bool locked;
  final VoidCallback onGenerate;
  final VoidCallback? onShare;

  /// A freshly generated picture, not yet on disk.
  final Uint8List? bytes;

  /// A picture already saved with the dream.
  final String? path;
  final String? error;

  bool get _hasImage => bytes != null || (path != null && path!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (status) {
      DreamImageStatus.generating => const _Dreaming(key: ValueKey('gen')),
      DreamImageStatus.ready when _hasImage => _Picture(
        key: const ValueKey('img'),
        bytes: bytes,
        path: path,
        // A picture that arrived as bytes was painted just now — that is the
        // moment worth a reveal; one loaded from disk is simply there.
        fresh: bytes != null,
        onRegenerate: onGenerate,
        onShare: onShare,
      ),
      DreamImageStatus.error => _Failed(
        key: const ValueKey('err'),
        message: error ?? "Couldn't paint this one. Try again?",
        onRetry: onGenerate,
      ),
      _ => _Invite(
        key: const ValueKey('inv'),
        locked: locked,
        onTap: onGenerate,
      ),
    };
    return AnimatedSwitcher(
      duration: Motion.slow,
      switchInCurve: Motion.curve,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (w, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.0).animate(a),
          child: w,
        ),
      ),
      child: child,
    );
  }
}

/// "See your dream" — the invitation. A quiet gradient with a slow sheen, so it
/// reads as something alive rather than a button.
class _Invite extends StatefulWidget {
  const _Invite({super.key, required this.locked, required this.onTap});
  final bool locked;
  final VoidCallback onTap;
  @override
  State<_Invite> createState() => _InviteState();
}

class _InviteState extends State<_Invite> with SingleTickerProviderStateMixin {
  late final _ctl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  bool _configured = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configured) return;
    _configured = true;
    if (!Motion.reduced(context)) _ctl.repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final radius = BorderRadius.circular(22);
    return PressScale(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap();
          },
          borderRadius: radius,
          child: AnimatedBuilder(
            animation: _ctl,
            builder: (_, child) {
              final x = math.sin(_ctl.value * 2 * math.pi);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment(-1 + x * 0.4, -1),
                    end: Alignment(1 + x * 0.4, 1),
                    colors: [
                      t.colorScheme.primary.withValues(alpha: 0.28),
                      t.colorScheme.tertiary.withValues(alpha: 0.14),
                      t.colorScheme.primary.withValues(alpha: 0.22),
                    ],
                  ),
                  border: Border.all(
                    color: t.colorScheme.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: child,
              );
            },
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.colorScheme.primary.withValues(alpha: 0.25),
                  ),
                  child: Icon(
                    widget.locked ? Icons.lock_outline : Icons.auto_awesome,
                    color: t.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'See your dream',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Ob.parchment,
                            ),
                          ),
                          if (widget.locked) ...[
                            const SizedBox(width: 8),
                            const _PlusPill(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Turn it into a picture you can keep.',
                        style: TextStyle(fontSize: 13, color: Ob.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Ob.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlusPill extends StatelessWidget {
  const _PlusPill();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: t.colorScheme.primary,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'PLUS',
        style: t.textTheme.labelSmall?.copyWith(
          color: t.colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// The wait. Drifting soft blobs in the night palette: it looks like a picture
/// forming, which is what is happening. It never pretends to know how long is
/// left — a generation is 20-40 s and a progress bar would be a guess — but
/// the caption moves through what is being done, so the wait has a shape.
class _Dreaming extends StatefulWidget {
  const _Dreaming({super.key});
  @override
  State<_Dreaming> createState() => _DreamingState();
}

class _DreamingState extends State<_Dreaming>
    with SingleTickerProviderStateMixin {
  static const _lines = [
    'Painting your dream…',
    'Sketching the scene…',
    'Mixing the colours of it…',
    'Adding the last light…',
  ];

  late final _ctl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  Timer? _caption;
  int _line = 0;
  bool _configured = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configured) return;
    _configured = true;
    if (!Motion.reduced(context)) _ctl.repeat();
    _caption = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) setState(() => _line = (_line + 1) % _lines.length);
    });
  }

  @override
  void dispose() {
    _caption?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AnimatedBuilder(
          animation: _ctl,
          builder: (_, _) {
            final v = _ctl.value * 2 * math.pi;
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Colors.white.withValues(alpha: 0.04)),
                _blob(
                  t.colorScheme.primary,
                  0.45,
                  Alignment(math.sin(v) * 0.6, math.cos(v * 0.7) * 0.6),
                  1.3,
                ),
                _blob(
                  t.colorScheme.tertiary,
                  0.30,
                  Alignment(math.cos(v * 0.8) * 0.7, math.sin(v * 0.5) * 0.7),
                  1.1,
                ),
                _blob(
                  t.colorScheme.secondary,
                  0.25,
                  Alignment(math.sin(v * 0.6 + 2) * 0.5, math.cos(v + 1) * 0.5),
                  0.9,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: 0.6 + 0.4 * (0.5 + 0.5 * math.sin(v * 2)),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 30,
                          color: Ob.parchment,
                        ),
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: Motion.base,
                        child: Text(
                          _lines[_line],
                          key: ValueKey(_line),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Ob.parchment,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'This takes a moment. Stay with it.',
                        style: TextStyle(fontSize: 12.5, color: Ob.muted),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _blob(Color c, double alpha, Alignment at, double size) => Align(
    alignment: at,
    child: FractionallySizedBox(
      widthFactor: size,
      heightFactor: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              c.withValues(alpha: alpha),
              c.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The reveal. A fresh painting arrives with a slow settle and a glow that
/// blooms then fades — the one moment in the app that earns a flourish — and
/// a soft haptic so the phone in a half-asleep hand says "it's here".
class _Picture extends StatefulWidget {
  const _Picture({
    super.key,
    this.bytes,
    this.path,
    required this.fresh,
    required this.onRegenerate,
    this.onShare,
  });
  final Uint8List? bytes;
  final String? path;
  final bool fresh;
  final VoidCallback onRegenerate;
  final VoidCallback? onShare;

  @override
  State<_Picture> createState() => _PictureState();
}

class _PictureState extends State<_Picture> {
  @override
  void initState() {
    super.initState();
    if (widget.fresh) HapticFeedback.mediumImpact();
  }

  String get _tag => 'dream-image-${widget.path ?? widget.bytes.hashCode}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final image = widget.bytes != null
        ? Image.memory(widget.bytes!, fit: BoxFit.cover, gaplessPlayback: true)
        : Image.file(File(widget.path!), fit: BoxFit.cover);

    final reduced = Motion.reduced(context);
    final frame = GestureDetector(
      onTap: () => _open(context, image),
      child: Hero(
        tag: _tag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AspectRatio(aspectRatio: 1, child: image),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.fresh && !reduced)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOutCubic,
            builder: (_, v, child) {
              // Glow rises fast and decays slowly; scale settles from 1.04.
              final glow = math.sin(v * math.pi) * (1 - v * 0.4);
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: t.colorScheme.primary.withValues(
                        alpha: 0.55 * glow,
                      ),
                      blurRadius: 40 * glow + 8,
                      spreadRadius: 4 * glow,
                    ),
                  ],
                ),
                child: Transform.scale(
                  scale: 1.04 - 0.04 * Curves.easeOutCubic.transform(v),
                  child: child,
                ),
              );
            },
            child: frame,
          )
        else
          frame,
        const SizedBox(height: 4),
        Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Tap to view',
                style: TextStyle(fontSize: 11.5, color: Ob.muted),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: widget.onRegenerate,
              style: TextButton.styleFrom(foregroundColor: Ob.muted),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Paint again'),
            ),
            if (widget.onShare != null)
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  widget.onShare!();
                },
                style: TextButton.styleFrom(foregroundColor: Ob.parchment),
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Share'),
              ),
          ],
        ),
      ],
    );
  }

  void _open(BuildContext context, Widget image) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: InteractiveViewer(
                child: Hero(tag: _tag, child: image),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_not_supported_outlined, color: Ob.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13.5, color: Ob.parchment),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
