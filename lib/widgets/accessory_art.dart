import 'package:flutter/material.dart';

import '../data/accessory_catalog.dart';
import 'nori_frame_anchors.dart';

/// Draws one equipped accessory as a hand-drawn cutout PNG (see
/// accessory_catalog.dart's [AccessoryItem.image]) — every catalog entry
/// has real art now, cut from Jimena's reference sheets in
/// assets/source/accessories/.
///
/// [headWidth] is the art's own width; height comes from
/// [_kImageAspectRatios] so the box is sized correctly before the image
/// itself has loaded.
class AccessoryArt extends StatelessWidget {
  const AccessoryArt({
    super.key,
    required this.item,
    required this.headWidth,
    this.renderWidth,
  });

  final AccessoryItem item;
  final double headWidth;

  /// Overrides the box's actual on-screen width while [headWidth] still
  /// determines its height (via [_kImageAspectRatios]) -- lets an item
  /// stretch wider (or narrower) without its own art growing/shrinking
  /// taller too. Used by steampunk-goggles, whose lenses needed to spread
  /// out to actually line up with Nori's (wider-set) eyes -- see
  /// [_AccessoryPlacement.widthStretch]. Defaults to [headWidth] (no
  /// stretch, the original behavior).
  final double? renderWidth;

  @override
  Widget build(BuildContext context) {
    final image = item.wornImage ?? item.image;
    final aspect = _kImageAspectRatios[item.id];
    if (image == null || aspect == null) return const SizedBox.shrink();
    return SizedBox(
      width: renderWidth ?? headWidth,
      height: headWidth * aspect,
      // fill (not contain) so a non-1.0 renderWidth actually stretches the
      // art instead of letterboxing it -- a no-op when renderWidth is
      // unset, since the box already matches the image's own aspect then.
      child: Image.asset(image, fit: BoxFit.fill),
    );
  }
}

/// height/width of each hand-cutout PNG, so [AccessoryArt] can size its box
/// before the image itself has loaded. Source pixel dimensions, from the
/// cutout script run against assets/source/accessories/ — see
/// accessory_catalog.dart. Keyed by the image [AccessoryArt] actually
/// renders (`wornImage ?? image`), so `tail-charm-clasp` reflects its
/// smaller worn cutout, not the bold shop-icon one.
const Map<String, double> _kImageAspectRatios = {
  'flower-crown': 59 / 160,
  'horn-bow': 71 / 85,
  'sunglasses': 58 / 130,
  'steampunk-goggles': 55 / 144,
  'chef-hat': 82 / 100,
  'tail-charm-clasp': 85 / 45,
};

/// How to place [AccessoryArt] on top of Nori: a size (as a fraction of
/// whatever single reference measurement the caller has on hand — Nori's
/// rendered height in the Customization preview, his rendered sprite width
/// in NoriRoomStage) and a vertical shift from the top of his bounding box
/// (negative = extends upward above his head, positive = sits down into
/// the face/head).
///
/// [scale] is relative to Nori's whole body span (that's the only
/// measurement either screen actually has on hand), and his head is only
/// roughly a quarter to a third of that. Tuned by eye against screenshots —
/// nudge further here if something looks off once Jimena tests it on
/// device.
class _AccessoryPlacement {
  const _AccessoryPlacement({
    required this.scale,
    required this.topFraction,
    this.dxFraction = 0,
    this.widthStretch = 1,
  });

  final double scale;
  final double topFraction;

  /// Horizontal nudge (fraction of [referenceSize]) from the Stack's
  /// automatic horizontal centering — every other accessory here sits on
  /// Nori's centerline so this defaults to 0; `tail-charm-clasp` is the one
  /// exception, since the tail it hangs from sticks out to his side rather
  /// than sitting on the centerline.
  final double dxFraction;

  /// Stretches the art horizontally only (see [AccessoryArt.renderWidth]) --
  /// 1 (the default) draws it at its own natural aspect ratio.
  final double widthStretch;
}

const Map<String, _AccessoryPlacement> _kPlacements = {
  // Sits right at the top of the round head (measured against
  // nori_front.png's own alpha silhouette: the ears/head roundness starts
  // at ~13.5% of the image height, well below the horn tips), dipping
  // slightly into the horn valley the way a headband actually would.
  'flower-crown': _AccessoryPlacement(scale: 0.32, topFraction: 0.08),
  // Perched up between the horns rather than resting low on the forehead
  // -- nori_front.png's horn valley sits around 9-10% down, so the bow's
  // box needs to start well above that (negative topFraction) to read as
  // "on top of the head" instead of "stuck to the face". Centered
  // (dxFraction: 0) like the goggles/crown/glasses above, rather than
  // shifted toward one horn -- off-center here is what read as "crooked".
  // NOT the same reference point as the animated placement below --
  // confirmed by testing: nori_front.png's own "zero" is the horn tips
  // (they touch the very top of the image), while the animated canvas's
  // headTopY anchor sits lower already, so the two dyFrac/topFraction
  // values aren't interchangeable. Measured directly off nori_front.png
  // instead: the valley between the horns bottoms out around 9-10% down,
  // so the box centers there.
  'horn-bow': _AccessoryPlacement(scale: 0.22, topFraction: -0.03),
  'sunglasses': _AccessoryPlacement(scale: 0.52, topFraction: 0.25),
  // These are real glasses, not pushed-up-on-the-forehead ones --
  // Jimena wants them actually covering his eyes. Same eye-line depth
  // as sunglasses below (topFraction centers the box on eyeMidFrac,
  // ~0.363), with a bigger scale than the old forehead version so the
  // lenses are big enough to fully cover the eyes.
  'steampunk-goggles': _AccessoryPlacement(
    scale: 0.46,
    topFraction: 0.275,
    // Stretched wider so the lenses line up with Nori's actual (wider-
    // set) eyes instead of sitting bunched together in the middle.
    widthStretch: 1.3,
  ),
  'chef-hat': _AccessoryPlacement(scale: 0.28, topFraction: -0.12),
  // The clasp hooks onto the tail's leafy tip -- measured directly off
  // nori_front.png (green tail-leaf pixels average at ~77% of the image's
  // height; dxFraction is relative to the *face* centerline now that
  // _kFaceCenterOffsetFraction corrects for it, so this is bigger-magnitude
  // than a naive "left of the middle of the picture" guess would be).
  'tail-charm-clasp': _AccessoryPlacement(
    scale: 0.11,
    topFraction: 0.68,
    dxFraction: -0.44,
  ),
};

/// nori_front.png's tail sticks out to Nori's left, which drags the
/// alpha bounding box's geometric center to the left of his actual
/// face/eye centerline -- measured directly off the art: the two eyes'
/// shared midpoint sits at ~54.8% of the image's width, not 50%.
/// [positionedAccessoryArt] used to rely on the enclosing `Stack`'s
/// `topCenter` alignment for horizontal placement whenever an item's
/// [_AccessoryPlacement.dxFraction] was 0, but that alignment only knows
/// about the geometric center -- so every "centered" accessory (sunglasses,
/// goggles, the flower crown, the chef hat) actually rendered shifted well
/// to the left of Nori's real face, which is exactly the "crooked"/
/// off-center look Jimena flagged. This is the same correction the
/// animated placements already get for free via [kNoriFaceCenterX] --
/// expressed here as a fraction of [referenceSize] (742/800 is
/// nori_front.png's own width/height ratio, since the offset was measured
/// as a fraction of the image's *width*, not the height [referenceSize]
/// itself represents).
const double _kFaceCenterOffsetFraction = 0.0483 * (742 / 800);

/// Wraps [AccessoryArt] in the `Positioned` it needs to sit correctly
/// inside a `Stack` whose only other (non-positioned) child is Nori's
/// sprite/image — used identically by the Customization preview and
/// NoriRoomStage so an equipped accessory lands in the same relative spot
/// everywhere Nori appears. See [_AccessoryPlacement] for what
/// [referenceSize] scales against.
Widget positionedAccessoryArt({
  required AccessoryItem item,
  required double referenceSize,
}) {
  final placement = _kPlacements[item.id];
  if (placement == null) return const SizedBox.shrink();
  final headWidth = referenceSize * placement.scale;
  final art = AccessoryArt(
    item: item,
    headWidth: headWidth,
    renderWidth: headWidth * placement.widthStretch,
  );
  final dx = referenceSize * (_kFaceCenterOffsetFraction + placement.dxFraction);
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
    this.widthStretch = 1,
  });

  final double scale;
  final AccessoryAnchor anchor;

  /// Offset from the anchor to the accessory box's top edge, as a fraction
  /// of the sprite's rendered width — the animated equivalent of
  /// [_AccessoryPlacement.topFraction], just measured from a point that
  /// moves with Nori's breathing instead of from a fixed origin.
  final double dyFrac;

  /// Horizontal fine-nudge from the anchor to the accessory box's left
  /// edge, same units as [dyFrac] — on top of, not instead of, the
  /// automatic horizontal centering every anchor already gets (see
  /// [animatedPositionedAccessoryArt]: `eyeMid`/`headTop` center on
  /// [kNoriFaceCenterX], `tail` on the per-frame tail position). Used by
  /// `horn-bow`, which sits off-center near the left horn rather than
  /// centered like a hat.
  final double dxFrac;

  /// Stretches the art horizontally only (see [AccessoryArt.renderWidth]) --
  /// 1 (the default) draws it at its own natural aspect ratio.
  final double widthStretch;
}

/// Anchor-based placements for [NoriRoomStage]'s animated breathing sprite.
/// Calibrated by eye against rendered frames (frame_00 in particular) the
/// same way [_kPlacements] was, but referencing [kNoriFrameAnchors] instead
/// of a single fixed fraction, so the accessory now moves with Nori instead
/// of drifting off him over the loop (docs/KNOWN_ISSUES.md).
///
/// `sunglasses`'s [_AnimatedAccessoryPlacement.dyFrac] is derived directly
/// from its own art's aspect ratio (see [_kImageAspectRatios]) so its
/// vertical center — not just its top edge — lands on the eye line:
/// `dyFrac = -scale * aspectRatio / 2`.
///
/// Not yet anchored: neckties/bows/necklaces/bandanas (no anatomical "neck"
/// on Nori's silhouette to detect automatically — he's a single rounded
/// body with no distinct head/neck/torso break), torso-worn items (bags,
/// vests, capes), and feet (socks, boots) — none of these have a body part
/// to anchor to in [kNoriFrameAnchors] yet. Add the anchor once one of
/// these is actually implemented; the reference art for several already
/// exists in assets/source/accessories/ waiting on it (see that folder's
/// README entry for which sheet/item). `tail` *is* anchored, first used by
/// `tail-charm-clasp` below.
const Map<String, _AnimatedAccessoryPlacement> _kAnimatedPlacements = {
  // headTopY tracks the very tip of the horns, not the head surface below
  // them (confirmed from Jimena's Home screenshot: at 0.08 the crown was
  // floating in a visible gap above the horns instead of resting on the
  // head) -- pushed down further so it sits right at the horn/head line.
  'flower-crown': _AnimatedAccessoryPlacement(
    scale: 0.32,
    anchor: AccessoryAnchor.headTop,
    dyFrac: 0.18,
  ),
  // Same headTopY-is-the-horn-tips correction as the flower crown above,
  // scaled down since the bow nestles *between* the horns (in the valley)
  // rather than resting on the wider head surface below them. Centered
  // (dxFrac: 0) instead of shifted toward one horn -- same fix as the
  // static placement, where off-center is what read as "crooked".
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
  // Pushed-up-on-the-forehead goggles — anchored off eyeMid like sunglasses
  // (same "near the eyes" family) but with a bigger upward nudge, so they
  // sit above the eyes instead of on them. Was riding up on/above the
  // horns at -0.17 -- pulled back down toward the forehead.
  // Real glasses that should cover his eyes, not sit pushed up on the
  // forehead -- same "center the box on eyeMidY" formula as sunglasses
  // below, scaled up so the lenses are actually big enough to cover them.
  // No widthStretch here (unlike the static placement) -- this one was
  // already correctly sized/positioned on the Home screen before the
  // stretch was added; only Style Pet/the Shop needed it.
  'steampunk-goggles': _AnimatedAccessoryPlacement(
    scale: 0.46,
    anchor: AccessoryAnchor.eyeMid,
    dyFrac: -0.06,
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

/// Anchor-tracking counterpart to [positionedAccessoryArt], used only by
/// [NoriRoomStage] (the animated breathing sprite) via
/// [NoriBreathingSprite.overlayBuilder]. Returns null when [item] has no
/// entry in [_kAnimatedPlacements] yet, so callers can fall back to
/// [positionedAccessoryArt]'s fixed placement rather than the accessory
/// disappearing.
const double _kTailXMean = 43.17;

/// The raw per-frame tail.dy in nori_frame_anchors.dart has sudden jumps
/// of ~10-14 canvas px lasting a handful of frames -- almost certainly an
/// artifact of the auto-extraction script momentarily mis-tracking the
/// tail (motion blur, or it briefly overlapping his leg) rather than real
/// motion. Tracking it directly made the tail charm visibly snap between
/// two heights instead of moving smoothly (confirmed by Jimena watching it
/// live: "tipo un segundo arriba y uno abajo"). Smoothing it with a
/// circular moving average turns those snaps into a gentle ramp without
/// needing to hand-fix the underlying data.
List<double>? _kSmoothedTailY;
List<double> get _smoothedTailY => _kSmoothedTailY ??= _circularMovingAverage(
  [for (final a in kNoriFrameAnchors) a.tail.dy],
  window: 9,
);

List<double> _circularMovingAverage(List<double> values, {required int window}) {
  final n = values.length;
  final half = window ~/ 2;
  return [
    for (var i = 0; i < n; i++)
      [for (var k = -half; k <= half; k++) values[(i + k + n) % n]].reduce(
            (a, b) => a + b,
          ) /
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
  final renderWidth = accWidth * placement.widthStretch;
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
      // The tail's real visible motion is vertical (up/down), not
      // horizontal -- confirmed by Jimena watching it live. So it tracks
      // a smoothed version of tail.dy (see [_smoothedTailY]), but anchorX
      // stays pinned at the calibrated mean instead of following
      // anchors.tail.dx, which just reads as an unrelated left-right
      // wobble.
      final frameIndex = _frameIndexOf(anchors);
      final tailY = frameIndex != null
          ? _smoothedTailY[frameIndex]
          : anchors.tail.dy;
      top = tailY * scale + placement.dyFrac * spriteWidth;
      anchorX = _kTailXMean;
  }
  final left = anchorX * scale - renderWidth / 2 + placement.dxFrac * spriteWidth;

  return Positioned(
    top: top,
    left: left,
    child: AccessoryArt(item: item, headWidth: accWidth, renderWidth: renderWidth),
  );
}


/// A small live render of Nori wearing [item] (or bare, if null): the same
/// nori_front.png art plus [positionedAccessoryArt] the Customization
/// screen's "Style Pet" preview uses, just reusable at any [height]. The
/// Shop uses this for each accessory card so a shopper sees how the item
/// will actually sit on Nori -- not just its flat cutout icon floating in
/// a colored box -- both before and after buying it. Because it calls the
/// exact same [positionedAccessoryArt] function with the exact same
/// placement table ([_kPlacements]), tuning an accessory's position once
/// updates its look everywhere this preview (or the Customization screen)
/// is used.
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
        // A Shop grid cell is much narrower relative to its height than
        // the Customization screen's preview panel is, so unlike there,
        // width -- not [height] -- is often what actually limits how big
        // Nori renders here (Image.asset(fit: contain) shrinks him to fit
        // the available width, leaving empty space above/below within a
        // box that's still nominally [height] tall). [_kPlacements]'
        // fractions are measured against Nori's own rendered height, so
        // an accessory positioned against the full, unshrunk [height]
        // instead of his actual (smaller) rendered height ends up floating
        // well above his head. Working out the real rendered height here
        // -- and sizing this widget's own box to match exactly, with no
        // leftover letterboxing -- keeps every placement correct at any
        // card size.
        final maxWidth = constraints.maxWidth;
        final renderedHeight = maxWidth.isFinite && maxWidth / _imageAspect < height
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
                positionedAccessoryArt(item: item!, referenceSize: renderedHeight),
            ],
          ),
        );
      },
    );
  }
}
