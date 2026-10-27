import 'package:flutter/material.dart';

const _frameCount = 64;

/// 64 frames at 12fps (every 2nd frame of the 24fps source), so the loop is
/// 128 source frames long (~5.33s).
const _loopDuration = Duration(milliseconds: 5333);

/// Pixel size every `nori_evolved/frame_NN.png` was exported at.
const _frameAspect = 480 / 300;

/// The evolved (winged) Nori's idle loop: a wing-flap cycle extracted from
/// real generated footage and cut to transparent PNGs (see
/// assets/images/nori_evolved). Same approach as [NoriBreathingSprite], minus
/// the accessory overlay — this form has no per-frame anchors yet, so
/// accessories aren't drawn on it (see docs/KNOWN_ISSUES.md).
///
/// The source clip doesn't loop on its own (it opens with the wings spread and
/// ends folded), so the frames are the stretch from the folded rest pose back
/// to a matching mid-fold; the wrap reads as a quick wing lift. The canvas is
/// wide because the wings spread far past the body, so [width] is the wing
/// span, not the body width.
class NoriEvolvedSprite extends StatefulWidget {
  const NoriEvolvedSprite({super.key, required this.width});

  final double width;

  @override
  State<NoriEvolvedSprite> createState() => _NoriEvolvedSpriteState();
}

class _NoriEvolvedSpriteState extends State<NoriEvolvedSprite>
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
        'assets/images/nori_evolved/frame_${i.toString().padLeft(2, '0')}.png',
      ),
    );
    _controller = AnimationController(vsync: this, duration: _loopDuration)
      ..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honor the OS "remove animations" setting, like NoriBreathingSprite.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
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
      builder: (context, _) {
        final index = (_controller.value * _frameCount).floor().clamp(
          0,
          _frameCount - 1,
        );
        return Image(
          image: _frames[index],
          width: widget.width,
          height: widget.width / _frameAspect,
          gaplessPlayback: true,
        );
      },
    );
  }
}
