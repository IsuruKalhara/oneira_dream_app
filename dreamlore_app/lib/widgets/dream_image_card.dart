import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

enum DreamImageStatus { idle, generating, ready, error }

/// The picture of a dream, in every state it passes through: an invitation to
/// make one, the wait while it is painted, the reveal, and a failure. One
/// widget so the record result and a saved entry look and behave the same.
///
/// Free users see the same invitation with a Plus mark on it; what happens on
/// tap is the caller's decision (an upsell sheet), so the card itself never
/// knows about billing.
class DreamImageCard extends StatelessWidget {
  const DreamImageCard({
    super.key,
    required this.status,
    required this.locked,
    required this.onGenerate,
    this.bytes,
    this.path,
    this.error,
  });

  final DreamImageStatus status;
  final bool locked;
  final VoidCallback onGenerate;

  /// A freshly generated picture, not yet on disk.
  final Uint8List? bytes;

  /// A picture already saved with the dream.
  final String? path;
  final String? error;

  bool get _hasImage =>
      bytes != null || (path != null && path!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (status) {
      DreamImageStatus.generating => const _Dreaming(key: ValueKey('gen')),
      DreamImageStatus.ready when _hasImage => _Picture(
          key: const ValueKey('img'),
          bytes: bytes,
          path: path,
          onRegenerate: onGenerate,
        ),
      DreamImageStatus.error => _Failed(
          key: const ValueKey('err'),
          message: error ?? "Couldn't paint this one. Try again?",
          onRetry: onGenerate,
        ),
      _ => _Invite(key: const ValueKey('inv'), locked: locked, onTap: onGenerate),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 550),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (w, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(a),
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
      vsync: this, duration: const Duration(seconds: 6))
    ..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final radius = BorderRadius.circular(18);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
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
                    color: t.colorScheme.primary.withValues(alpha: 0.35)),
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
                        Text('See your dream', style: t.textTheme.titleMedium),
                        if (widget.locked) ...[
                          const SizedBox(width: 8),
                          _PlusPill(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Turn it into a picture you can keep.',
                      style: t.textTheme.bodySmall
                          ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: t.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlusPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: t.colorScheme.primary,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text('PLUS',
          style: t.textTheme.labelSmall?.copyWith(
            color: t.colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          )),
    );
  }
}

/// The wait. Drifting soft blobs in the night palette: it looks like a picture
/// forming, which is what is happening, and it never pretends to know how long
/// is left — a generation is 20-40 s and a progress bar would be a guess.
class _Dreaming extends StatefulWidget {
  const _Dreaming({super.key});
  @override
  State<_Dreaming> createState() => _DreamingState();
}

class _DreamingState extends State<_Dreaming>
    with SingleTickerProviderStateMixin {
  late final _ctl = AnimationController(
      vsync: this, duration: const Duration(seconds: 5))
    ..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AnimatedBuilder(
          animation: _ctl,
          builder: (_, _) {
            final v = _ctl.value * 2 * math.pi;
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: t.colorScheme.surfaceContainerHighest),
                _blob(t.colorScheme.primary, 0.45,
                    Alignment(math.sin(v) * 0.6, math.cos(v * 0.7) * 0.6), 1.3),
                _blob(t.colorScheme.tertiary, 0.30,
                    Alignment(math.cos(v * 0.8) * 0.7, math.sin(v * 0.5) * 0.7), 1.1),
                _blob(t.colorScheme.secondary, 0.25,
                    Alignment(math.sin(v * 0.6 + 2) * 0.5, math.cos(v + 1) * 0.5), 0.9),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: 0.6 + 0.4 * (0.5 + 0.5 * math.sin(v * 2)),
                        child: Icon(Icons.auto_awesome,
                            size: 30, color: t.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 12),
                      Text('Painting your dream…',
                          style: t.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text('This takes a moment. Stay with it.',
                          style: t.textTheme.bodySmall?.copyWith(
                              color: t.colorScheme.onSurfaceVariant)),
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
              gradient: RadialGradient(colors: [
                c.withValues(alpha: alpha),
                c.withValues(alpha: 0),
              ]),
            ),
          ),
        ),
      );
}

class _Picture extends StatelessWidget {
  const _Picture({super.key, this.bytes, this.path, required this.onRegenerate});
  final Uint8List? bytes;
  final String? path;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final image = bytes != null
        ? Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true)
        : Image.file(File(path!), fit: BoxFit.cover);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => _open(context, image),
          child: Hero(
            tag: 'dream-image-${path ?? bytes.hashCode}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: AspectRatio(aspectRatio: 1, child: image),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('Tap to view',
                style: t.textTheme.labelSmall
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            const Spacer(),
            TextButton.icon(
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Paint again'),
            ),
          ],
        ),
      ],
    );
  }

  void _open(BuildContext context, Widget image) {
    Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: InteractiveViewer(
              child: Hero(
                tag: 'dream-image-${path ?? bytes.hashCode}',
                child: image,
              ),
            ),
          ),
        ),
      ),
    ));
  }
}

class _Failed extends StatelessWidget {
  const _Failed({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.image_not_supported_outlined,
              color: t.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: t.textTheme.bodySmall)),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
