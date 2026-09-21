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
      child: Image.asset(image, fit: BoxFit.contain),
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
  });

  final double scale;
  final double topFraction;

  /// Horizontal nudge (fraction of [referenceSize]) from the Stack's
  /// automatic horizontal centering — every other accessory here sits on
  /// Nori's centerline so this defaults to 0; `tail-charm-clasp` is the one
  /// exception, since the tail it hangs from sticks out to his side rather
  /// than sitting on the centerline.
  final double dxFraction;
}

const Map<String, _AccessoryPlacement> _kPlacements = {
  'flower-crown': _AccessoryPlacement(scale: 0.32, topFraction: 0.1),
  'horn-bow': _AccessoryPlacement(
    scale: 0.26,
    topFraction: 0.09,
    dxFraction: 0.15,
  ),
  'sunglasses': _AccessoryPlacement(scale: 0.52, topFraction: 0.25),
  'steampunk-goggles': _AccessoryPlacement(scale: 0.4, topFraction: -0.02),
  'chef-hat': _AccessoryPlacement(scale: 0.28, topFraction: -0.12),
  'tail-charm-clasp': _AccessoryPlacement(
    scale: 0.11,
    topFraction: 0.7,
    dxFraction: -0.28,
  ),
};

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
  final art = AccessoryArt(
    item: item,
    headWidth: referenceSize * placement.scale,
  );
  return Positioned(
    top: referenceSize * placement.topFraction,
    child: placement.dxFraction == 0
        ? art
        : Transform.translate(
            offset: Offset(referenceSize * placement.dxFraction, 0),
            child: art,
          ),
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

  /// Horizontal fine-nudge from the anchor to the accessory box's left
  /// edge, same units as [dyFrac] — on top of, not instead of, the
  /// automatic horizontal centering every anchor already gets (see
  /// [animatedPositionedAccessoryArt]: `eyeMid`/`headTop` center on
  /// [kNoriFaceCenterX], `tail` on the per-frame tail position). Used by
  /// `horn-bow`, which sits off-center near the left horn rather than
  /// centered like a hat.
  final double dxFrac;
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
  'flower-crown': _AnimatedAccessoryPlacement(
    scale: 0.32,
    anchor: AccessoryAnchor.headTop,
    dyFrac: 0.08,
  ),
  'horn-bow': _AnimatedAccessoryPlacement(
    scale: 0.22,
    anchor: AccessoryAnchor.headTop,
    dyFrac: -0.06,
    dxFrac: -0.14,
  ),
  'chef-hat': _AnimatedAccessoryPlacement(
    scale: 0.28,
    anchor: AccessoryAnchor.headTop,
    dyFrac: -0.04,
  ),
  // Pushed-up-on-the-forehead goggles — anchored off eyeMid like sunglasses
  // (same "near the eyes" family) but with a much bigger upward nudge, so
  // they sit above the eyes instead of on them.
  'steampunk-goggles': _AnimatedAccessoryPlacement(
    scale: 0.4,
    anchor: AccessoryAnchor.eyeMid,
    dyFrac: -0.17,
  ),
  // dyFrac centers the lens box on the eye line: -scale * (own aspect
  // ratio, 58/130) / 2.
  'sunglasses': _AnimatedAccessoryPlacement(
    scale: 0.52,
    anchor: AccessoryAnchor.eyeMid,
    dyFrac: -0.116,
  ),
  'tail-charm-clasp': _AnimatedAccessoryPlacement(
    scale: 0.08,
    anchor: AccessoryAnchor.tail,
    dyFrac: -0.02,
  ),
};

/// Anchor-tracking counterpart to [positionedAccessoryArt], used only by
/// [NoriRoomStage] (the animated breathing sprite) via
/// [NoriBreathingSprite.overlayBuilder]. Returns null when [item] has no
/// entry in [_kAnimatedPlacements] yet, so callers can fall back to
/// [positionedAccessoryArt]'s fixed placement rather than the accessory
/// disappearing.
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
      top = anchors.tail.dy * scale + placement.dyFrac * spriteWidth;
      anchorX = anchors.tail.dx;
  }
  final left = anchorX * scale - accWidth / 2 + placement.dxFrac * spriteWidth;

  return Positioned(
    top: top,
    left: left,
    child: AccessoryArt(item: item, headWidth: accWidth),
  );
}
