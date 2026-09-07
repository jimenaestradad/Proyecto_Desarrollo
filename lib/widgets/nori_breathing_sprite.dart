import 'package:flutter/material.dart';

const _frameCount = 67;

/// Real duration of the source loop: 134 frames @ 24fps (~5.58s),
/// sampled down to every 2nd frame (12fps effective — matching this to the
/// source's own frame rate rather than an arbitrary flipbook rate is what
/// keeps the breathing looking smooth instead of choppy; a longer loop
/// needs proportionally more kept frames, not the same fixed budget).
const _loopDuration = Duration(milliseconds: 5583);

/// Nori's idle animation: a real breathing + blink loop, not a synthetic
/// scale/translate — extracted frame-by-frame from a source video in
/// assets/source and cut to transparent PNGs (see assets/images/nori_breathing).
/// Precaches every frame up front so the loop doesn't pop on first play.
class NoriBreathingSprite extends StatefulWidget {
  const NoriBreathingSprite({super.key});

  @override
  State<NoriBreathingSprite> createState() => _NoriBreathingSpriteState();
}

class _NoriBreathingSpriteState extends State<NoriBreathingSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<ImageProvider> _frames;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    _frames = List.generate(
      _frameCount,
      (i) => AssetImage(
        'assets/images/nori_breathing/frame_${i.toString().padLeft(2, '0')}.png',
      ),
    );
    _controller = AnimationController(vsync: this, duration: _loopDuration)
      ..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    for (final frame in _frames) {
      precacheImage(frame, context);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final index = (_controller.value * _frameCount).floor().clamp(
          0,
          _frameCount - 1,
        );
        return Image(image: _frames[index], gaplessPlayback: true);
      },
    );
  }
}
