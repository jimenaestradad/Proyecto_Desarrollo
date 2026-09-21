import 'package:flutter/material.dart';

/// Pixel size of the source canvas every `nori_breathing/frame_NN.png` was
/// exported at (see nori_breathing_sprite.dart) — all coordinates below are
/// in this same pixel space. Because every frame shares one canvas size,
/// converting an anchor to on-screen pixels only needs a single uniform
/// scale factor (`spriteWidth / kNoriFrameCanvasSize.width`), applied to
/// both axes, rather than separate x/y fractions.
const kNoriFrameCanvasSize = Size(223, 238);

/// Horizontal center of Nori's face/head, in the same canvas-pixel space —
/// the average eye-midpoint x across all 67 frames (118.1–118.7px, i.e.
/// essentially constant; breathing shifts him vertically, not sideways).
/// Not the same as the canvas's own horizontal center (223/2 = 111.5px) —
/// his tail sticks out on the left, which drags the *alpha bounding box*'s
/// center left of where his face actually is. Eye/head-anchored accessories
/// position off of this instead of relying on Stack-alignment auto-centering,
/// which was centering on the wrong axis by about 3% of his width.
const kNoriFaceCenterX = 118.3;

/// Where Nori's key features sit, in canvas-pixel coordinates, for one
/// frame of the breathing loop. Detected automatically (see the anchor
/// extraction script referenced in docs/KNOWN_ISSUES.md) by finding the
/// filled dark blobs that are his eyes and tail against each frame's alpha
/// mask — not hand-eyeballed, so it stays accurate across all 67 frames
/// including the blink frames, where the eyes are thin closed lines rather
/// than round pupils.
class NoriFrameAnchors {
  const NoriFrameAnchors({
    required this.eyeMidY,
    required this.headTopY,
    required this.tail,
  });

  /// Vertical midpoint between his two eyes — glasses anchor here.
  final double eyeMidY;

  /// Topmost opaque pixel of his silhouette (the horn tips) — hats/
  /// headphones anchor here. Tracks the same breathing-driven vertical
  /// shift as [eyeMidY] (they move together, since it's one rigid
  /// silhouette breathing), just measured at a different point on him.
  final double headTopY;

  /// Centroid of his tail — for a future tail-bow accessory (none exist in
  /// the catalog yet, see accessory_catalog.dart).
  final Offset tail;
}

/// One entry per frame of [NoriBreathingSprite]'s loop (frame_00..frame_66),
/// extracted by thresholding each frame's alpha-cutout for dark, filled
/// interior blobs — his two eyes are the two largest such blobs inside a
/// face-sized region (excludes the tail and the horn-shading marks, which
/// are dark too but sit outside that region), and his tail is the largest
/// dark blob left of/below his face. Verified by compositing crosshairs at
/// the detected points back onto sample frames (including blink frames)
/// and checking them by eye.
///
/// This is what lets an equipped accessory track Nori's real per-frame
/// motion instead of sitting at one fixed offset (see docs/KNOWN_ISSUES.md
/// — "Accessories use one fixed position across the whole breathing loop").
const List<NoriFrameAnchors> kNoriFrameAnchors = [
  NoriFrameAnchors(eyeMidY: 92.9, headTopY: 8.0, tail: Offset(40.5, 183.6)), // frame 00
  NoriFrameAnchors(eyeMidY: 93.7, headTopY: 9.0, tail: Offset(40.7, 183.3)), // frame 01
  NoriFrameAnchors(eyeMidY: 95.9, headTopY: 11.0, tail: Offset(39.5, 184.4)), // frame 02
  NoriFrameAnchors(eyeMidY: 98.4, headTopY: 14.0, tail: Offset(38.1, 183.6)), // frame 03
  NoriFrameAnchors(eyeMidY: 98.8, headTopY: 14.0, tail: Offset(38.2, 184.2)), // frame 04
  NoriFrameAnchors(eyeMidY: 96.9, headTopY: 13.0, tail: Offset(38.4, 183.2)), // frame 05
  NoriFrameAnchors(eyeMidY: 94.6, headTopY: 11.0, tail: Offset(39.2, 184.1)), // frame 06
  NoriFrameAnchors(eyeMidY: 91.4, headTopY: 8.0, tail: Offset(53.7, 196.7)), // frame 07
  NoriFrameAnchors(eyeMidY: 88.8, headTopY: 6.0, tail: Offset(52.9, 196.2)), // frame 08
  NoriFrameAnchors(eyeMidY: 86.6, headTopY: 5.0, tail: Offset(52.2, 195.7)), // frame 09
  NoriFrameAnchors(eyeMidY: 84.7, headTopY: 3.0, tail: Offset(53.3, 195.9)), // frame 10
  NoriFrameAnchors(eyeMidY: 83.0, headTopY: 2.0, tail: Offset(53.8, 195.3)), // frame 11
  NoriFrameAnchors(eyeMidY: 81.7, headTopY: 1.0, tail: Offset(54.8, 195.2)), // frame 12
  NoriFrameAnchors(eyeMidY: 81.1, headTopY: 0.0, tail: Offset(54.0, 193.6)), // frame 13
  NoriFrameAnchors(eyeMidY: 81.2, headTopY: 0.0, tail: Offset(54.1, 193.7)), // frame 14
  NoriFrameAnchors(eyeMidY: 82.4, headTopY: 1.0, tail: Offset(53.7, 193.8)), // frame 15
  NoriFrameAnchors(eyeMidY: 84.1, headTopY: 2.0, tail: Offset(40.6, 179.5)), // frame 16
  NoriFrameAnchors(eyeMidY: 86.2, headTopY: 3.0, tail: Offset(40.0, 178.3)), // frame 17
  NoriFrameAnchors(eyeMidY: 88.1, headTopY: 5.0, tail: Offset(40.5, 178.5)), // frame 18
  NoriFrameAnchors(eyeMidY: 90.0, headTopY: 6.0, tail: Offset(39.8, 179.7)), // frame 19
  NoriFrameAnchors(eyeMidY: 91.2, headTopY: 8.0, tail: Offset(40.0, 181.1)), // frame 20
  NoriFrameAnchors(eyeMidY: 92.7, headTopY: 9.0, tail: Offset(40.5, 180.8)), // frame 21
  NoriFrameAnchors(eyeMidY: 93.8, headTopY: 9.0, tail: Offset(40.6, 181.5)), // frame 22
  NoriFrameAnchors(eyeMidY: 94.4, headTopY: 10.0, tail: Offset(40.7, 183.2)), // frame 23
  NoriFrameAnchors(eyeMidY: 94.5, headTopY: 10.0, tail: Offset(40.6, 183.6)), // frame 24
  NoriFrameAnchors(eyeMidY: 94.0, headTopY: 9.0, tail: Offset(40.6, 183.7)), // frame 25
  NoriFrameAnchors(eyeMidY: 93.7, headTopY: 9.0, tail: Offset(40.9, 184.6)), // frame 26
  NoriFrameAnchors(eyeMidY: 93.3, headTopY: 8.0, tail: Offset(50.9, 194.8)), // frame 27
  NoriFrameAnchors(eyeMidY: 93.7, headTopY: 9.0, tail: Offset(51.0, 194.8)), // frame 28
  NoriFrameAnchors(eyeMidY: 95.0, headTopY: 10.0, tail: Offset(41.4, 185.7)), // frame 29
  NoriFrameAnchors(eyeMidY: 97.0, headTopY: 12.0, tail: Offset(39.9, 185.7)), // frame 30
  NoriFrameAnchors(eyeMidY: 99.1, headTopY: 14.0, tail: Offset(38.4, 183.1)), // frame 31
  NoriFrameAnchors(eyeMidY: 100.2, headTopY: 15.0, tail: Offset(38.6, 184.2)), // frame 32
  NoriFrameAnchors(eyeMidY: 100.0, headTopY: 15.0, tail: Offset(38.6, 184.0)), // frame 33
  NoriFrameAnchors(eyeMidY: 98.0, headTopY: 14.0, tail: Offset(39.0, 182.0)), // frame 34
  NoriFrameAnchors(eyeMidY: 95.2, headTopY: 11.0, tail: Offset(39.2, 183.5)), // frame 35
  NoriFrameAnchors(eyeMidY: 92.4, headTopY: 9.0, tail: Offset(40.1, 181.7)), // frame 36
  NoriFrameAnchors(eyeMidY: 89.4, headTopY: 6.0, tail: Offset(40.3, 181.8)), // frame 37
  NoriFrameAnchors(eyeMidY: 86.9, headTopY: 4.0, tail: Offset(40.7, 181.2)), // frame 38
  NoriFrameAnchors(eyeMidY: 85.4, headTopY: 3.0, tail: Offset(54.6, 195.8)), // frame 39
  NoriFrameAnchors(eyeMidY: 84.9, headTopY: 2.0, tail: Offset(54.1, 195.5)), // frame 40
  NoriFrameAnchors(eyeMidY: 85.3, headTopY: 3.0, tail: Offset(53.8, 194.8)), // frame 41
  NoriFrameAnchors(eyeMidY: 86.4, headTopY: 3.0, tail: Offset(54.2, 194.9)), // frame 42
  NoriFrameAnchors(eyeMidY: 87.9, headTopY: 5.0, tail: Offset(54.0, 195.0)), // frame 43
  NoriFrameAnchors(eyeMidY: 89.7, headTopY: 6.0, tail: Offset(40.0, 180.9)), // frame 44
  NoriFrameAnchors(eyeMidY: 91.6, headTopY: 8.0, tail: Offset(40.2, 181.2)), // frame 45
  NoriFrameAnchors(eyeMidY: 93.5, headTopY: 9.0, tail: Offset(39.4, 180.2)), // frame 46
  NoriFrameAnchors(eyeMidY: 95.0, headTopY: 11.0, tail: Offset(39.7, 181.8)), // frame 47
  NoriFrameAnchors(eyeMidY: 96.3, headTopY: 12.0, tail: Offset(39.8, 182.9)), // frame 48
  NoriFrameAnchors(eyeMidY: 96.8, headTopY: 13.0, tail: Offset(39.4, 182.5)), // frame 49
  NoriFrameAnchors(eyeMidY: 96.7, headTopY: 13.0, tail: Offset(39.0, 183.5)), // frame 50
  NoriFrameAnchors(eyeMidY: 96.3, headTopY: 12.0, tail: Offset(39.5, 184.7)), // frame 51
  NoriFrameAnchors(eyeMidY: 95.6, headTopY: 11.0, tail: Offset(40.2, 185.6)), // frame 52
  NoriFrameAnchors(eyeMidY: 94.7, headTopY: 10.0, tail: Offset(39.5, 184.5)), // frame 53
  NoriFrameAnchors(eyeMidY: 93.6, headTopY: 9.0, tail: Offset(40.4, 183.1)), // frame 54
  NoriFrameAnchors(eyeMidY: 92.4, headTopY: 7.0, tail: Offset(39.8, 183.1)), // frame 55
  NoriFrameAnchors(eyeMidY: 91.5, headTopY: 6.0, tail: Offset(40.1, 181.8)), // frame 56
  NoriFrameAnchors(eyeMidY: 90.5, headTopY: 5.0, tail: Offset(40.0, 179.4)), // frame 57
  NoriFrameAnchors(eyeMidY: 89.7, headTopY: 4.0, tail: Offset(39.8, 179.0)), // frame 58
  NoriFrameAnchors(eyeMidY: 89.2, headTopY: 4.0, tail: Offset(40.6, 178.3)), // frame 59
  NoriFrameAnchors(eyeMidY: 88.9, headTopY: 3.0, tail: Offset(41.0, 177.9)), // frame 60
  NoriFrameAnchors(eyeMidY: 89.3, headTopY: 4.0, tail: Offset(40.5, 178.0)), // frame 61
  NoriFrameAnchors(eyeMidY: 89.7, headTopY: 4.0, tail: Offset(40.8, 178.8)), // frame 62
  NoriFrameAnchors(eyeMidY: 90.4, headTopY: 5.0, tail: Offset(40.4, 178.2)), // frame 63
  NoriFrameAnchors(eyeMidY: 90.9, headTopY: 6.0, tail: Offset(40.8, 180.2)), // frame 64
  NoriFrameAnchors(eyeMidY: 91.7, headTopY: 7.0, tail: Offset(40.4, 181.3)), // frame 65
  NoriFrameAnchors(eyeMidY: 92.3, headTopY: 8.0, tail: Offset(40.7, 183.0)), // frame 66
];
