import 'package:flutter/material.dart';

import 'nori_frame_anchors.dart';

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
  const NoriBreathingSprite({super.key, this.overlayBuilder});

  /// Builds a widget (an equipped accessory, typically) positioned using
  /// this same tick's [NoriFrameAnchors], so it can track Nori's real
  /// per-frame motion instead of sitting at one fixed offset — see
  /// docs/KNOWN_ISSUES.md. [spriteWidth] is this sprite's actual rendered
  /// width, for sizing the overlay relative to him. Composited in the same
  /// `AnimatedBuilder` frame as the sprite image itself so the two never
  /// fall out of sync.
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
            // Explicit width matters here: without it, Image only shrinks
            // to fit tight constraints and never grows past the frame's
            // native 223px size, so on any screen wide enough to offer more
            // than that, the real rendered width would silently stay
            // pinned at 223 while spriteWidth (used above for the overlay's
            // scale/position math) kept assuming the larger offered width —
            // the two would only agree by coincidence on some screens and
            // visibly disagree on others (confirmed: an equipped accessory
            // came out oversized and off-position specifically on a preset
            // wide enough to trigger this).
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
