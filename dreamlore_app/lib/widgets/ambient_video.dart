import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../ui/motion.dart';
import '../ui/night.dart';

/// A silent looping clip used as a living background — the night over the lake
/// behind the first onboarding page.
///
/// The hard part of a background video is the loop: `video_player`'s own
/// looping stutters for a frame at the wrap on Android, which reads as a jump.
/// So this does not use plugin looping. It runs two controllers of the same
/// clip and cross-fades from one to the other a beat before the end, then back
/// — the seam is always hidden under a fade, no matter what the clip does at
/// its boundary. It is still decoration, so: no sound, no controls, fades in
/// only once playing, frozen under reduced motion, and if the asset can't load
/// the page simply keeps the starfield it already had.
class AmbientVideo extends StatefulWidget {
  final String asset;

  /// How much of the night ground shows through, so type stays readable.
  final double dim;

  const AmbientVideo({super.key, required this.asset, this.dim = 0.35});

  @override
  State<AmbientVideo> createState() => _AmbientVideoState();
}

class _AmbientVideoState extends State<AmbientVideo> {
  final List<VideoPlayerController> _ctls = [];
  int _front = 0; // which controller is currently shown
  bool _ready = false;
  bool _failed = false;
  bool _configured = false;

  // Cross-fade begins this long before a clip ends, and lasts this long.
  static const _lead = Duration(milliseconds: 900);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_configured) return;
    _configured = true;
    if (Motion.reduced(context)) return;
    _load();
  }

  Future<void> _load() async {
    try {
      for (var i = 0; i < 2; i++) {
        final c = VideoPlayerController.asset(widget.asset);
        await c.initialize();
        await c.setVolume(0);
        _ctls.add(c);
      }
      _ctls[0].addListener(_tick);
      await _ctls[0].play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      for (final c in _ctls) {
        c.dispose();
      }
      _ctls.clear();
      if (mounted) setState(() => _failed = true);
    }
  }

  void _tick() {
    if (!mounted || _ctls.length < 2) return;
    final front = _ctls[_front];
    final v = front.value;
    if (!v.isInitialized || v.duration == Duration.zero) return;
    if (v.position >= v.duration - _lead && !_switching) {
      _switching = true;
      _handOff();
    }
  }

  bool _switching = false;

  Future<void> _handOff() async {
    final next = (_front + 1) % 2;
    final incoming = _ctls[next];
    await incoming.seekTo(Duration.zero);
    await incoming.play();
    incoming.addListener(_tick);
    _ctls[_front].removeListener(_tick);
    if (mounted) setState(() => _front = next);
    // Let the outgoing clip finish under the fade, then park it.
    Future.delayed(_lead, () async {
      if (!mounted) return;
      await _ctls[next == 0 ? 1 : 0].pause();
      _switching = false;
    });
  }

  @override
  void dispose() {
    for (final c in _ctls) {
      c.removeListener(_tick);
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.expand();
    return AnimatedOpacity(
      opacity: _ready ? 1 : 0,
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOut,
      child: !_ready
          ? const SizedBox.expand()
          : Stack(
              fit: StackFit.expand,
              children: [
                for (var i = 0; i < _ctls.length; i++)
                  AnimatedOpacity(
                    opacity: i == _front ? 1 : 0,
                    duration: _lead,
                    curve: Curves.easeInOut,
                    child: _Fitted(controller: _ctls[i]),
                  ),
                // Ink over the clip, heavier at the bottom where copy sits.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Ob.ink.withValues(alpha: widget.dim),
                        Ob.ink.withValues(alpha: widget.dim + 0.25),
                        Ob.ink.withValues(alpha: 0.92),
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Fitted extends StatelessWidget {
  final VideoPlayerController controller;
  const _Fitted({required this.controller});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: controller.value.size.width,
        height: controller.value.size.height,
        child: VideoPlayer(controller),
      ),
    );
  }
}
