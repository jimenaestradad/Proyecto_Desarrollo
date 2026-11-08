import 'package:flutter/material.dart';

import 'nori_evolved_frame_anchors.dart';

const _frameCount = 64;

/// 64 frames at 12fps (every 2nd frame of the 24fps source), so the loop is
/// 128 source frames long (~5.33s).
const _loopDuration = Duration(milliseconds: 5333);

/// Pixel size every `nori_evolved/frame_NN.png` was exported at.
const _frameAspect = 480 / 300;

/// Wing-flap idle loop from transparent PNGs in assets/images/nori_evolved.
/// [kNoriEvolvedFrameAnchors] keeps accessories attached through the hop.
/// [width] measures the wing span, rather than body width.
class NoriEvolvedSprite extends StatefulWidget {
  const NoriEvolvedSprite({
    super.key,
    required this.width,
    this.overlayBuilder,
  });

  final double width;

  /// Builds an accessory from this tick's [NoriEvolvedFrameAnchors] and [spriteWidth].
  /// Shares the sprite's AnimatedBuilder frame to prevent drift.
  final Widget? Function(
    BuildContext context,
    double spriteWidth,
    NoriEvolvedFrameAnchors anchors,
  )?
  overlayBuilder;

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
        final image = Image(
          image: _frames[index],
          width: widget.width,
          height: widget.width / _frameAspect,
          gaplessPlayback: true,
        );
        final overlay = widget.overlayBuilder?.call(
          context,
          widget.width,
          kNoriEvolvedFrameAnchors[index],
        );
        if (overlay == null) return image;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [image, overlay],
        );
      },
    );
  }
}
