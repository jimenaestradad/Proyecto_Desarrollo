import 'package:flutter/material.dart';

import 'nori_frame_anchors.dart';

const _frameCount = 67;

/// Source loop duration: 134 frames at 24fps (~5.58s).
/// Keeping every second frame yields 12fps while preserving the original timing.
const _loopDuration = Duration(milliseconds: 5583);

/// Nori's idle animation: a real breathing + blink loop, not a synthetic
/// scale/translate — extracted frame-by-frame from a source video in
/// assets/source and cut to transparent PNGs (see assets/images/nori_breathing).
/// Precaches every frame up front so the loop doesn't pop on first play.
class NoriBreathingSprite extends StatefulWidget {
  const NoriBreathingSprite({super.key, this.overlayBuilder});

  /// Builds an overlay from this tick's [NoriFrameAnchors] and actual [spriteWidth].
  /// Composited with the sprite in the same AnimatedBuilder frame to stay synchronized.
  final Widget Function(
    BuildContext context,
    double spriteWidth,
    NoriFrameAnchors anchors,
  )?
  overlayBuilder;

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
    // Honor the OS "remove animations" setting: hold Nori on his first
    // frame instead of looping the breathing cycle forever.
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final spriteWidth = constraints.maxWidth;
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final index = (_controller.value * _frameCount).floor().clamp(
              0,
              _frameCount - 1,
            );
            // Set explicit spriteWidth so the image can grow beyond its native 223px width.
            // Overlay scale and position must use the same rendered width as the image.
            final image = Image(
              image: _frames[index],
              width: spriteWidth,
              gaplessPlayback: true,
            );
            final overlayBuilder = widget.overlayBuilder;
            if (overlayBuilder == null) return image;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                image,
                overlayBuilder(context, spriteWidth, kNoriFrameAnchors[index]),
              ],
            );
          },
        );
      },
    );
  }
}
