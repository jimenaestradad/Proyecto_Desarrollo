import 'dart:math';

import 'package:flutter/material.dart';

import '../data/accessory_catalog.dart';
import '../theme/app_theme.dart';

/// A hand-drawn, flat-outlined illustration for one accessory — drawn in
/// the same line-and-flat-color language as Nori himself (thick black
/// outlines, solid pastel fills, simple rounded shapes), not a generic
/// Material icon in a circle. Each accessory gets its own small shape
/// (headband + earcups, a cone hat, etc.) built from basic canvas
/// primitives so it actually reads as "worn" rather than as a UI badge.
///
/// [headWidth] is the art's own width; each shape picks its height to
/// match (see the per-shape widgets below), so callers only need to hand
/// in one size number.
class AccessoryArt extends StatelessWidget {
  const AccessoryArt({super.key, required this.item, required this.headWidth});

  final AccessoryItem item;
  final double headWidth;

  @override
  Widget build(BuildContext context) {
    switch (item.id) {
      case 'cozy-headphones':
        return _Headphones(width: headWidth, color: item.color);
      case 'smart-glasses':
        return _SmartGlasses(width: headWidth, color: item.color);
      case 'wizard-hat':
        return _WizardHat(width: headWidth, color: item.color);
      case 'propeller-beanie':
        return _PropellerBeanie(width: headWidth, color: item.color);
      case 'flower-crown':
        return _FlowerCrown(width: headWidth, color: item.color);
      default:
        return const SizedBox.shrink();
    }
  }
}

/// How to place [AccessoryArt] on top of Nori: a size (as a fraction of
/// whatever single reference measurement the caller has on hand — Nori's
/// rendered height in the Customization preview, his rendered sprite width
/// in NoriRoomStage) and a vertical shift from the top of his bounding box
/// (negative = extends upward above his head, positive = sits down into
/// the face/head).
///
/// [scale] is relative to Nori's whole body span (that's the only
/// measurement either screen actually has on hand), and his head is only
/// roughly a quarter to a third of that — the first pass here used
/// 0.4-0.5, sized as if it were relative to the head itself, which is why
/// everything rendered oversized (a propeller beanie taller than Nori).
/// These are recalibrated against the original icon-badge version (which
/// *was* sized right, at 0.24) and are still a first pass tuned by eye
/// against screenshots — nudge further here if something looks off once
/// Jimena tests it on device.
class _AccessoryPlacement {
  const _AccessoryPlacement({required this.scale, required this.topFraction});

  final double scale;
  final double topFraction;
}

const Map<String, _AccessoryPlacement> _kPlacements = {
  'cozy-headphones': _AccessoryPlacement(scale: 0.3, topFraction: 0.04),
  'smart-glasses': _AccessoryPlacement(scale: 0.2, topFraction: 0.22),
  'wizard-hat': _AccessoryPlacement(scale: 0.26, topFraction: -0.16),
  'propeller-beanie': _AccessoryPlacement(scale: 0.26, topFraction: -0.08),
  'flower-crown': _AccessoryPlacement(scale: 0.32, topFraction: -0.02),
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
  return Positioned(
    top: referenceSize * placement.topFraction,
    child: AccessoryArt(
      item: item,
      headWidth: referenceSize * placement.scale,
    ),
  );
}

class _Headphones extends StatelessWidget {
  const _Headphones({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 0.85,
      child: CustomPaint(painter: _HeadphonesPainter(color: color)),
    );
  }
}

class _HeadphonesPainter extends CustomPainter {
  _HeadphonesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final baselineY = h * 0.48;
    final earR = w * 0.17;

    final stroke = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;

    // Band: the top half of an ellipse spanning the two earcups, so it
    // reads as an arch going over the top of the head.
    final bandRect = Rect.fromCenter(
      center: Offset(w / 2, baselineY),
      width: w * 0.84,
      height: h * 0.82,
    );
    canvas.drawArc(bandRect, pi, pi, false, stroke);

    final cupFill = Paint()..color = color;
    final cupStroke = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05;
    final innerShade = Paint()..color = AppColors.ink.withValues(alpha: 0.16);

    for (final cx in [w * 0.1, w * 0.9]) {
      final center = Offset(cx, baselineY);
      canvas.drawCircle(center, earR, cupFill);
      canvas.drawCircle(center, earR, cupStroke);
      canvas.drawCircle(center, earR * 0.42, innerShade);
    }
  }

  @override
  bool shouldRepaint(covariant _HeadphonesPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _SmartGlasses extends StatelessWidget {
  const _SmartGlasses({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 0.44,
      child: CustomPaint(painter: _SmartGlassesPainter(color: color)),
    );
  }
}

class _SmartGlassesPainter extends CustomPainter {
  _SmartGlassesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final lensW = w * 0.36;
    final lensH = h * 0.9;

    final lensFill = Paint()..color = color.withValues(alpha: 0.6);
    final stroke = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.14
      ..strokeCap = StrokeCap.round;

    final leftLens = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, h * 0.05, lensW, lensH),
      Radius.circular(lensH * 0.4),
    );
    final rightLens = RRect.fromRectAndRadius(
      Rect.fromLTWH(w - lensW, h * 0.05, lensW, lensH),
      Radius.circular(lensH * 0.4),
    );
    canvas.drawRRect(leftLens, lensFill);
    canvas.drawRRect(leftLens, stroke);
    canvas.drawRRect(rightLens, lensFill);
    canvas.drawRRect(rightLens, stroke);

    canvas.drawLine(
      Offset(lensW, h * 0.45),
      Offset(w - lensW, h * 0.45),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _SmartGlassesPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _WizardHat extends StatelessWidget {
  const _WizardHat({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 1.15,
      child: CustomPaint(painter: _WizardHatPainter(color: color)),
    );
  }
}

class _WizardHatPainter extends CustomPainter {
  _WizardHatPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final brimRect = Rect.fromCenter(
      center: Offset(w / 2, h * 0.82),
      width: w,
      height: h * 0.22,
    );
    canvas.drawOval(brimRect, fill);
    canvas.drawOval(brimRect, stroke);

    // A gently curved cone, tipping to one side like a classic wizard hat.
    final cone = Path()
      ..moveTo(w * 0.22, h * 0.78)
      ..quadraticBezierTo(w * 0.38, h * 0.2, w * 0.6, h * 0.02)
      ..quadraticBezierTo(w * 0.7, h * 0.32, w * 0.78, h * 0.78)
      ..close();
    canvas.drawPath(cone, fill);
    canvas.drawPath(cone, stroke);

    _drawStar(
      canvas,
      Offset(w * 0.55, h * 0.44),
      w * 0.075,
      Paint()..color = AppColors.white.withValues(alpha: 0.9),
    );
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    const points = 5;
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final radius = i.isEven ? r : r * 0.42;
      final angle = (pi / points) * i - pi / 2;
      final point = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WizardHatPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PropellerBeanie extends StatelessWidget {
  const _PropellerBeanie({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 0.95,
      child: CustomPaint(painter: _PropellerBeaniePainter(color: color)),
    );
  }
}

class _PropellerBeaniePainter extends CustomPainter {
  _PropellerBeaniePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round;

    // Dome: the top half of a circle, sitting on the head like a cap.
    final domeRect = Rect.fromCenter(
      center: Offset(w / 2, h * 0.64),
      width: w * 0.86,
      height: h * 0.86,
    );
    final domePath = Path()
      ..addArc(domeRect, pi, pi)
      ..close();
    canvas.drawPath(domePath, fill);
    canvas.drawArc(domeRect, pi, pi, false, stroke);
    canvas.drawLine(
      Offset(domeRect.left, h * 0.64),
      Offset(domeRect.right, h * 0.64),
      stroke,
    );

    final stickTop = Offset(w / 2, h * 0.08);
    canvas.drawLine(Offset(w / 2, h * 0.24), stickTop, stroke);

    final bladeFill = Paint()..color = AppColors.white;
    final bladeStroke = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035;
    canvas.save();
    canvas.translate(stickTop.dx, stickTop.dy);
    for (final angle in [0.0, pi / 2]) {
      canvas.save();
      canvas.rotate(angle);
      final blade = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 0.5, height: w * 0.13),
        Radius.circular(w * 0.065),
      );
      canvas.drawRRect(blade, bladeFill);
      canvas.drawRRect(blade, bladeStroke);
      canvas.restore();
    }
    canvas.restore();
    canvas.drawCircle(stickTop, w * 0.05, fill);
    canvas.drawCircle(stickTop, w * 0.05, stroke);
  }

  @override
  bool shouldRepaint(covariant _PropellerBeaniePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _FlowerCrown extends StatelessWidget {
  const _FlowerCrown({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 0.5,
      child: CustomPaint(painter: _FlowerCrownPainter(color: color)),
    );
  }
}

class _FlowerCrownPainter extends CustomPainter {
  _FlowerCrownPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.018;

    final leafFill = Paint()..color = AppColors.moss;
    for (final cx in [w * 0.34, w * 0.66]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, h * 0.5), width: w * 0.16, height: w * 0.08),
        leafFill,
      );
    }

    final flowerCenters = [
      Offset(w * 0.16, h * 0.62),
      Offset(w * 0.5, h * 0.18),
      Offset(w * 0.84, h * 0.62),
    ];
    final petalColors = [color, AppColors.blush, color];
    for (var i = 0; i < flowerCenters.length; i++) {
      _drawFlower(canvas, flowerCenters[i], w * 0.13, petalColors[i], stroke);
    }
  }

  void _drawFlower(
    Canvas canvas,
    Offset center,
    double r,
    Color petalColor,
    Paint stroke,
  ) {
    final petalPaint = Paint()..color = petalColor;
    for (var i = 0; i < 5; i++) {
      final angle = (2 * pi / 5) * i;
      final petalCenter = Offset(
        center.dx + r * 0.55 * cos(angle),
        center.dy + r * 0.55 * sin(angle),
      );
      canvas.drawCircle(petalCenter, r * 0.5, petalPaint);
      canvas.drawCircle(petalCenter, r * 0.5, stroke);
    }
    final corePaint = Paint()..color = AppColors.mustard;
    canvas.drawCircle(center, r * 0.38, corePaint);
    canvas.drawCircle(center, r * 0.38, stroke);
  }

  @override
  bool shouldRepaint(covariant _FlowerCrownPainter oldDelegate) =>
      oldDelegate.color != color;
}
