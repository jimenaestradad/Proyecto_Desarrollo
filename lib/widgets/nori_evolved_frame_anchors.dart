/// Pixel size of every `nori_evolved/frame_NN.png` -- all coordinates below
/// are in this canvas's pixel space, so converting to screen pixels only needs
/// one uniform factor (`spriteWidth / kNoriEvolvedCanvasWidth`), same as the
/// baby's [kNoriFrameCanvasSize].
const kNoriEvolvedCanvasWidth = 480.0;

/// Where the evolved Nori's eyes sit on one frame of [NoriEvolvedSprite]'s
/// 64-frame loop. Unlike the baby, the evolved head is a rigid shape: across
/// the whole loop the eye gap stays 40px and [eyeMidX] only wobbles within
/// ~4px, while [eyeMidY] swings ~99-147px as he hops onto his hind legs and
/// back down -- so the head just translates, and one eye-midpoint per frame is
/// enough to pin every head accessory (the placement table in
/// accessory_art.dart offsets from it).
class NoriEvolvedFrameAnchors {
  const NoriEvolvedFrameAnchors({required this.eyeMidX, required this.eyeMidY});

  final double eyeMidX;
  final double eyeMidY;
}

/// Extracted automatically from the frames' alpha cutouts: the head is the
/// topmost skin-coloured blob, and the eyes are the two dark blobs inside it
/// (filled pupils on open-eye frames; the closed-eye arcs on blink frames).
/// Frames 54-55 are mid-blink and ambiguous, so they're interpolated between
/// 53 and 56. Checked by compositing accessories onto frames across the loop.
const List<NoriEvolvedFrameAnchors> kNoriEvolvedFrameAnchors = [
  NoriEvolvedFrameAnchors(eyeMidX: 239.1, eyeMidY: 129.4), // frame 00
  NoriEvolvedFrameAnchors(eyeMidX: 239.1, eyeMidY: 129.4), // frame 01
  NoriEvolvedFrameAnchors(eyeMidX: 238.8, eyeMidY: 129.5), // frame 02
  NoriEvolvedFrameAnchors(eyeMidX: 239.2, eyeMidY: 129.7), // frame 03
  NoriEvolvedFrameAnchors(eyeMidX: 239.2, eyeMidY: 130.0), // frame 04
  NoriEvolvedFrameAnchors(eyeMidX: 239.5, eyeMidY: 130.2), // frame 05
  NoriEvolvedFrameAnchors(eyeMidX: 239.2, eyeMidY: 130.3), // frame 06
  NoriEvolvedFrameAnchors(eyeMidX: 239.1, eyeMidY: 130.4), // frame 07
  NoriEvolvedFrameAnchors(eyeMidX: 239.4, eyeMidY: 130.5), // frame 08
  NoriEvolvedFrameAnchors(eyeMidX: 239.3, eyeMidY: 130.8), // frame 09
  NoriEvolvedFrameAnchors(eyeMidX: 239.2, eyeMidY: 131.9), // frame 10
  NoriEvolvedFrameAnchors(eyeMidX: 239.5, eyeMidY: 133.0), // frame 11
  NoriEvolvedFrameAnchors(eyeMidX: 239.3, eyeMidY: 134.8), // frame 12
  NoriEvolvedFrameAnchors(eyeMidX: 239.7, eyeMidY: 136.4), // frame 13
  NoriEvolvedFrameAnchors(eyeMidX: 239.9, eyeMidY: 138.6), // frame 14
  NoriEvolvedFrameAnchors(eyeMidX: 240.1, eyeMidY: 140.1), // frame 15
  NoriEvolvedFrameAnchors(eyeMidX: 240.4, eyeMidY: 140.7), // frame 16
  NoriEvolvedFrameAnchors(eyeMidX: 240.5, eyeMidY: 139.7), // frame 17
  NoriEvolvedFrameAnchors(eyeMidX: 240.5, eyeMidY: 136.1), // frame 18
  NoriEvolvedFrameAnchors(eyeMidX: 240.5, eyeMidY: 130.1), // frame 19
  NoriEvolvedFrameAnchors(eyeMidX: 240.1, eyeMidY: 121.9), // frame 20
  NoriEvolvedFrameAnchors(eyeMidX: 240.2, eyeMidY: 113.4), // frame 21
  NoriEvolvedFrameAnchors(eyeMidX: 239.9, eyeMidY: 107.5), // frame 22
  NoriEvolvedFrameAnchors(eyeMidX: 239.7, eyeMidY: 103.2), // frame 23
  NoriEvolvedFrameAnchors(eyeMidX: 239.8, eyeMidY: 100.0), // frame 24
  NoriEvolvedFrameAnchors(eyeMidX: 239.6, eyeMidY: 99.0), // frame 25
  NoriEvolvedFrameAnchors(eyeMidX: 239.5, eyeMidY: 99.1), // frame 26
  NoriEvolvedFrameAnchors(eyeMidX: 239.5, eyeMidY: 100.0), // frame 27
  NoriEvolvedFrameAnchors(eyeMidX: 239.5, eyeMidY: 99.9), // frame 28
  NoriEvolvedFrameAnchors(eyeMidX: 239.5, eyeMidY: 99.7), // frame 29
  NoriEvolvedFrameAnchors(eyeMidX: 239.4, eyeMidY: 99.5), // frame 30
  NoriEvolvedFrameAnchors(eyeMidX: 239.8, eyeMidY: 108.9), // frame 31
  NoriEvolvedFrameAnchors(eyeMidX: 239.6, eyeMidY: 118.4), // frame 32
  NoriEvolvedFrameAnchors(eyeMidX: 239.8, eyeMidY: 128.3), // frame 33
  NoriEvolvedFrameAnchors(eyeMidX: 239.8, eyeMidY: 136.0), // frame 34
  NoriEvolvedFrameAnchors(eyeMidX: 239.9, eyeMidY: 141.2), // frame 35
  NoriEvolvedFrameAnchors(eyeMidX: 240.0, eyeMidY: 144.9), // frame 36
  NoriEvolvedFrameAnchors(eyeMidX: 240.1, eyeMidY: 147.0), // frame 37
  NoriEvolvedFrameAnchors(eyeMidX: 240.4, eyeMidY: 147.2), // frame 38
  NoriEvolvedFrameAnchors(eyeMidX: 240.5, eyeMidY: 147.2), // frame 39
  NoriEvolvedFrameAnchors(eyeMidX: 240.8, eyeMidY: 145.6), // frame 40
  NoriEvolvedFrameAnchors(eyeMidX: 241.0, eyeMidY: 143.6), // frame 41
  NoriEvolvedFrameAnchors(eyeMidX: 241.1, eyeMidY: 140.7), // frame 42
  NoriEvolvedFrameAnchors(eyeMidX: 241.5, eyeMidY: 138.1), // frame 43
  NoriEvolvedFrameAnchors(eyeMidX: 241.6, eyeMidY: 135.7), // frame 44
  NoriEvolvedFrameAnchors(eyeMidX: 241.6, eyeMidY: 134.2), // frame 45
  NoriEvolvedFrameAnchors(eyeMidX: 241.7, eyeMidY: 132.4), // frame 46
  NoriEvolvedFrameAnchors(eyeMidX: 241.9, eyeMidY: 131.3), // frame 47
  NoriEvolvedFrameAnchors(eyeMidX: 241.6, eyeMidY: 130.8), // frame 48
  NoriEvolvedFrameAnchors(eyeMidX: 241.2, eyeMidY: 130.3), // frame 49
  NoriEvolvedFrameAnchors(eyeMidX: 240.9, eyeMidY: 130.6), // frame 50
  NoriEvolvedFrameAnchors(eyeMidX: 240.5, eyeMidY: 130.5), // frame 51
  NoriEvolvedFrameAnchors(eyeMidX: 239.9, eyeMidY: 130.8), // frame 52
  NoriEvolvedFrameAnchors(eyeMidX: 239.5, eyeMidY: 131.0), // frame 53
  NoriEvolvedFrameAnchors(eyeMidX: 239.0, eyeMidY: 131.0), // frame 54
  NoriEvolvedFrameAnchors(eyeMidX: 238.5, eyeMidY: 131.0), // frame 55
  NoriEvolvedFrameAnchors(eyeMidX: 238.1, eyeMidY: 131.0), // frame 56
  NoriEvolvedFrameAnchors(eyeMidX: 237.8, eyeMidY: 130.8), // frame 57
  NoriEvolvedFrameAnchors(eyeMidX: 238.1, eyeMidY: 130.5), // frame 58
  NoriEvolvedFrameAnchors(eyeMidX: 237.7, eyeMidY: 130.5), // frame 59
  NoriEvolvedFrameAnchors(eyeMidX: 238.1, eyeMidY: 130.6), // frame 60
  NoriEvolvedFrameAnchors(eyeMidX: 238.4, eyeMidY: 130.2), // frame 61
  NoriEvolvedFrameAnchors(eyeMidX: 238.9, eyeMidY: 130.3), // frame 62
  NoriEvolvedFrameAnchors(eyeMidX: 239.0, eyeMidY: 130.5), // frame 63
];
