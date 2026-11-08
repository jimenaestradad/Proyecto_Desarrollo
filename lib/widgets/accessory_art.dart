import 'package:flutter/material.dart';

import '../data/accessory_catalog.dart';
import 'nori_evolved_frame_anchors.dart';
import 'nori_frame_anchors.dart';

/// Draws an equipped accessory's hand-cut PNG from [AccessoryItem.image].
/// [headWidth] sets its width; [_kImageAspectRatios] sizes it before loading.
class AccessoryArt extends StatelessWidget {
  const AccessoryArt({super.key, required this.item, required this.headWidth});

  final AccessoryItem item;
  final double headWidth;

  @override
  Widget build(BuildContext context) {
    final image = item.wornImage ?? item.image;
    final aspect = _kImageAspectRatios[item.id];
    if (image == null || aspect == null) return const SizedBox.shrink();
    return SizedBox(
      width: headWidth,
      height: headWidth * aspect,
      child: Image.asset(image, fit: BoxFit.fill),
    );
  }
}

/// Source PNG height/width ratios for sizing [AccessoryArt] before images load.
/// Uses the rendered `wornImage ?? image`, including the tail charm's smaller cutout.
const Map<String, double> _kImageAspectRatios = {
  'flower-crown': 59 / 160,
  'horn-bow': 71 / 85,
  'sunglasses': 58 / 130,
  'steampunk-goggles': 55 / 144,
  'chef-hat': 82 / 100,
  'tail-charm-clasp': 85 / 45,
};

/// Accessory size and top offset relative to Nori's rendered reference measurement.
/// Negative offsets extend above the head; [scale] is relative to the whole body span.
class _AccessoryPlacement {
  const _AccessoryPlacement({
    required this.scale,
    required this.topFraction,
    this.dxFraction = 0,
  });

  final double scale;
  final double topFraction;

  /// Horizontal nudge from Stack centering as a fraction of [referenceSize].
  /// Defaults to zero; the tail charm needs a side offset.
  final double dxFraction;
}

const Map<String, _AccessoryPlacement> _kPlacements = {
  // A full wreath across the top of the head with the horns rising behind it,
  // as in the reference sheet: ~2.5 eye gaps wide (gap is 210px of
  // nori_front.png's 800), centred ~0.7 gaps above the eye line.
  'flower-crown': _AccessoryPlacement(scale: 0.667, topFraction: 0.059),
  // Center the bow in the horn valley, about 9–10% down nori_front.png.
  // Static zero is the horn tips; animated headTopY uses a different reference.
  'horn-bow': _AccessoryPlacement(scale: 0.22, topFraction: -0.03),
  'sunglasses': _AccessoryPlacement(scale: 0.52, topFraction: 0.25),
  // Wear goggles as a headband around the horn bases.
  // Art spans ~2.3 eye gaps, with lenses ~one gap apart and ~0.66 gaps above the eyes.
  'steampunk-goggles': _AccessoryPlacement(scale: 0.60, topFraction: 0.06),
  'chef-hat': _AccessoryPlacement(scale: 0.28, topFraction: -0.12),
  // Hook the clasp onto the tail leaf at ~77% of nori_front.png's height.
  // dxFraction is relative to the corrected face centerline.
  'tail-charm-clasp': _AccessoryPlacement(
    scale: 0.11,
    topFraction: 0.68,
    dxFraction: -0.44,
  ),
};

/// Correct static centering to the eye midpoint at ~54.8% of image width.
/// The tail shifts the bounding-box center left; convert the offset to height units
/// using nori_front.png's 742/800 width/height ratio.
const double _kFaceCenterOffsetFraction = 0.0483 * (742 / 800);

/// Positions [AccessoryArt] over Nori's image in a Stack for consistent previews.
/// [referenceSize] follows [_AccessoryPlacement]'s reference measurement.
Widget positionedAccessoryArt({
  required AccessoryItem item,
  required double referenceSize,
}) {
  final placement = _kPlacements[item.id];
  if (placement == null) return const SizedBox.shrink();
  final headWidth = referenceSize * placement.scale;
  final art = AccessoryArt(item: item, headWidth: headWidth);
  final dx =
      referenceSize * (_kFaceCenterOffsetFraction + placement.dxFraction);
  return Positioned(
    top: referenceSize * placement.topFraction,
    child: Transform.translate(offset: Offset(dx, 0), child: art),
  );
}

/// Which of Nori's per-frame [NoriFrameAnchors] an accessory should track.
/// Only the anchors that already have a real body part behind them are
/// here — see the "not yet anchored" list on [_kAnimatedPlacements].
enum AccessoryAnchor { eyeMid, headTop, tail }

/// Like [_AccessoryPlacement], but the vertical position is expressed as an
/// offset from a moving per-frame [AccessoryAnchor] instead of a constant
/// fraction of [referenceSize] — see [animatedPositionedAccessoryArt].
class _AnimatedAccessoryPlacement {
  const _AnimatedAccessoryPlacement({
    required this.scale,
    required this.anchor,
    required this.dyFrac,
    this.dxFrac = 0,
  });

  final double scale;
  final AccessoryAnchor anchor;

  /// Offset from the anchor to the accessory box's top edge, as a fraction
  /// of the sprite's rendered width — the animated equivalent of
  /// [_AccessoryPlacement.topFraction], just measured from a point that
  /// moves with Nori's breathing instead of from a fixed origin.
  final double dyFrac;

  /// Horizontal fine-nudge added to anchor centering, in [dyFrac] units.
  /// Eye/head anchors center on [kNoriFaceCenterX]; tail anchors use per-frame position.
  final double dxFrac;
}

/// Breathing-sprite placements track [kNoriFrameAnchors] to follow Nori's motion.
/// Sunglasses center on the eye line via `dyFrac = -scale * aspectRatio / 2`.
/// Neck, torso and feet items still need anchors when implemented.
const Map<String, _AnimatedAccessoryPlacement> _kAnimatedPlacements = {
  // Full wreath like the reference sheet (see the static placement): ~2.5 eye
  // gaps wide, centred ~0.7 gaps above the eye line (gap = 59.7px of the
  // 223px canvas), so anchored off eyeMid like the goggles.
  'flower-crown': _AnimatedAccessoryPlacement(
    scale: 0.68,
    anchor: AccessoryAnchor.eyeMid,
    dyFrac: -0.316,
  ),
  // Place the small bow down from headTopY's horn tips into the valley.
  // Keep it centered between the horns, matching the static placement.
  'horn-bow': _AnimatedAccessoryPlacement(
    scale: 0.22,
    anchor: AccessoryAnchor.headTop,
    dyFrac: 0.16,
  ),
  // Same headTopY-is-the-horn-tips story as the crown/bow above -- was
  // floating in a big gap above the horns at -0.04, brought down to rest
  // near the horn/head line like they do.
  'chef-hat': _AnimatedAccessoryPlacement(
    scale: 0.28,
    anchor: AccessoryAnchor.headTop,
    dyFrac: 0.04,
  ),
  // Pulled-up goggles (headband style, per the reference sheet), anchored
  // off eyeMid like the glasses but sitting on top of the head: ~2.3 eye gaps
  // wide, lens centres ~0.66 gaps above the eye line (eye gap is 59.7px of
  // the 223px canvas).
  'steampunk-goggles': _AnimatedAccessoryPlacement(
    scale: 0.615,
    anchor: AccessoryAnchor.eyeMid,
    dyFrac: -0.284,
  ),
  // dyFrac centers the lens box on the eye line: -scale * (own aspect
  // ratio, 58/130) / 2.
  'sunglasses': _AnimatedAccessoryPlacement(
    scale: 0.52,
    anchor: AccessoryAnchor.eyeMid,
    dyFrac: -0.116,
  ),
  // Was floating well below the actual tail, down near the rug --
  // pulled up to actually sit at/near it, and nudged left so it hangs off
  // the tail's leaf instead of overlapping his leg.
  'tail-charm-clasp': _AnimatedAccessoryPlacement(
    scale: 0.08,
    anchor: AccessoryAnchor.tail,
    dyFrac: -0.14,
    dxFrac: 0.02,
  ),
};

/// Animated anchor-tracking counterpart to [positionedAccessoryArt].
/// Unmapped items return null so callers can fall back to fixed placement.
const double _kTailXMean = 43.17;

/// Smooth tail.dy with a circular moving average to soften ~10–14px extraction jumps.
/// Raw anchors made the charm visibly snap between heights.
List<double>? _kSmoothedTailY;
List<double> get _smoothedTailY => _kSmoothedTailY ??= _circularMovingAverage([
  for (final a in kNoriFrameAnchors) a.tail.dy,
], window: 9);

List<double> _circularMovingAverage(
  List<double> values, {
  required int window,
}) {
  final n = values.length;
  final half = window ~/ 2;
  return [
    for (var i = 0; i < n; i++)
      [
            for (var k = -half; k <= half; k++) values[(i + k + n) % n],
          ].reduce((a, b) => a + b) /
          (2 * half + 1),
  ];
}

/// [kNoriFrameAnchors] entries are reused const instances, so identity
/// comparison reliably finds which frame index a given [NoriFrameAnchors]
/// came from without threading a frame index through every call site.
int? _frameIndexOf(NoriFrameAnchors anchors) {
  for (var i = 0; i < kNoriFrameAnchors.length; i++) {
    if (identical(kNoriFrameAnchors[i], anchors)) return i;
  }
  return null;
}

Widget? animatedPositionedAccessoryArt({
  required AccessoryItem item,
  required double spriteWidth,
  required NoriFrameAnchors anchors,
}) {
  final placement = _kAnimatedPlacements[item.id];
  if (placement == null) return null;

  final scale = spriteWidth / kNoriFrameCanvasSize.width;
  final accWidth = spriteWidth * placement.scale;
  final double top;
  double anchorX;
  switch (placement.anchor) {
    case AccessoryAnchor.eyeMid:
      top = anchors.eyeMidY * scale + placement.dyFrac * spriteWidth;
      anchorX = kNoriFaceCenterX;
    case AccessoryAnchor.headTop:
      top = anchors.headTopY * scale + placement.dyFrac * spriteWidth;
      anchorX = kNoriFaceCenterX;
    case AccessoryAnchor.tail:
      // Track smoothed vertical tail motion while keeping X at its calibrated mean.
      // Raw tail.dx adds an unrelated sideways wobble.
      final frameIndex = _frameIndexOf(anchors);
      final tailY = frameIndex != null
          ? _smoothedTailY[frameIndex]
          : anchors.tail.dy;
      top = tailY * scale + placement.dyFrac * spriteWidth;
      anchorX = _kTailXMean;
  }
  final left = anchorX * scale - accWidth / 2 + placement.dxFrac * spriteWidth;

  return Positioned(
    top: top,
    left: left,
    child: AccessoryArt(item: item, headWidth: accWidth),
  );
}

/// Evolved head accessories track the per-frame eye midpoint; the head only translates.
/// [scale] and [dyFrac] use sprite-width units, calibrated from baby placements.
/// The tail charm is omitted because the evolved tail is usually obscured.
class _EvolvedPlacement {
  const _EvolvedPlacement({required this.scale, required this.dyFrac});

  final double scale;
  final double dyFrac;
}

const Map<String, _EvolvedPlacement> _kEvolvedPlacements = {
  // Full wreath across the head, horns rising behind it (matches the baby's):
  // ~2.5 eye gaps wide, centred ~0.7 gaps above the eye line.
  'flower-crown': _EvolvedPlacement(scale: 0.212, dyFrac: -0.098),
  // Centred between the horn bases, just above the forehead marks.
  'horn-bow': _EvolvedPlacement(scale: 0.075, dyFrac: -0.085),
  // Box centred on the eye line. Kept smaller than the lens spacing would
  // ideally want (lenses are 46% of the art's width apart vs the pupils' 40px):
  // 0.162 read as too big on the evolved head, and this still covers the eyes.
  'sunglasses': _EvolvedPlacement(scale: 0.14, dyFrac: -0.031),
  // Pulled up like a headband (matches the baby's): lenses flank the horn
  // bases, ~0.66 eye gaps above the eye line.
  'steampunk-goggles': _EvolvedPlacement(scale: 0.20, dyFrac: -0.091),
  // Perched on the dome with the horns rising past its sides.
  'chef-hat': _EvolvedPlacement(scale: 0.10, dyFrac: -0.136),
};

/// Whether [item] has a sensible spot on the evolved form. False means it is
/// still equipped but not drawn there (currently just `tail-charm-clasp`;
/// the plan is to replace it with a similar evolved-friendly accessory rather
/// than place it -- see docs/KNOWN_ISSUES.md).
bool accessoryFitsEvolved(AccessoryItem item) =>
    _kEvolvedPlacements.containsKey(item.id);

/// Evolved-form counterpart to [animatedPositionedAccessoryArt]. Returns null
/// when [item] doesn't fit the evolved form (see [accessoryFitsEvolved]).
Widget? evolvedPositionedAccessoryArt({
  required AccessoryItem item,
  required double spriteWidth,
  required NoriEvolvedFrameAnchors anchors,
}) {
  final placement = _kEvolvedPlacements[item.id];
  if (placement == null) return null;
  final scale = spriteWidth / kNoriEvolvedCanvasWidth;
  final accWidth = spriteWidth * placement.scale;
  return Positioned(
    top: anchors.eyeMidY * scale + placement.dyFrac * spriteWidth,
    left: anchors.eyeMidX * scale - accWidth / 2,
    child: AccessoryArt(item: item, headWidth: accWidth),
  );
}

/// Reusable static Nori preview wearing [item], or bare when null.
/// Shares [positionedAccessoryArt] and [_kPlacements] with Customization
/// so Shop cards show the same fit and receive placement adjustments together.
class NoriAccessoryPreview extends StatelessWidget {
  const NoriAccessoryPreview({super.key, required this.height, this.item});

  final double height;
  final AccessoryItem? item;

  /// nori_front.png's own width/height ratio (742x800 -- see the pixel
  /// measurements in [_kPlacements]'s comments).
  static const double _imageAspect = 742 / 800;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Size placements from Nori's actual rendered height when card width limits the image.
        // Shrink the widget to that height too, avoiding letterboxing that floats accessories.
        final maxWidth = constraints.maxWidth;
        final renderedHeight =
            maxWidth.isFinite && maxWidth / _imageAspect < height
            ? maxWidth / _imageAspect
            : height;
        return SizedBox(
          height: renderedHeight,
          width: renderedHeight * _imageAspect,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Image.asset(
                'assets/images/nori_front.png',
                height: renderedHeight,
                fit: BoxFit.contain,
              ),
              if (item != null)
                positionedAccessoryArt(
                  item: item!,
                  referenceSize: renderedHeight,
                ),
            ],
          ),
        );
      },
    );
  }
}
