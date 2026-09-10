import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../data/accessory_catalog.dart';
import '../models/pet.dart';
import '../theme/app_theme.dart';
import 'accessory_badge.dart';
import 'nori_breathing_sprite.dart';

/// Nori's room: the interior background with Nori standing on the rug,
/// breathing gently in place. Purely visual — no data reads. Tapping Nori
/// opens Customization; [onTapNori] is supplied by the caller so this
/// widget doesn't need to know about navigation.
///
/// Full-bleed (no rounded corners) — this fills the whole screen behind the
/// HUD and habit panel, not a padded/rounded card floating over a plain
/// background.
///
/// The static front/side/back renders bundled under assets/images/ are for
/// a later turn-around feature, not wired here (see docs/OPEN_DECISIONS.md;
/// nothing about pet-facing direction is decided) — this stage uses the
/// animated breathing sprite instead.
class NoriRoomStage extends StatelessWidget {
  const NoriRoomStage({
    super.key,
    required this.onTapNori,
    this.stage = PetEvolutionStage.baby,
    this.equippedAccessory,
  });

  final VoidCallback onTapNori;

  /// PLACEHOLDER, not real stage-2 art (see docs/KNOWN_ISSUES.md): only
  /// [PetEvolutionStage.baby]'s sprite/photos exist today (see
  /// nori_breathing_sprite.dart — extracted from real filmed footage of a
  /// physical prop, not vector art, so a true second form needs new
  /// footage of the actual object, not something generatable in code).
  /// Until that exists, [PetEvolutionStage.evolution1] reuses the same
  /// breathing sprite scaled up with a warm aura behind it, so evolving
  /// reads as "grew, something changed" instead of silently doing nothing.
  final PetEvolutionStage stage;

  /// The accessory equipped in Customization (see accessory_catalog.dart),
  /// or null when nothing is equipped. Drawn as a small [AccessoryBadge]
  /// near Nori's head — there's no fitted art layer to composite onto the
  /// photographed sprite, so a badge is the equip-feedback stand-in.
  final AccessoryItem? equippedAccessory;

  bool get _isEvolved => stage != PetEvolutionStage.baby;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/room_interior.jpg', fit: BoxFit.cover),
        if (_isEvolved)
          Align(
            alignment: const Alignment(0, 0.3),
            child: const _EvolvedAura(),
          ),
        // Rug sits higher up in this background than the previous one, so
        // both are shifted up to match (see the rug band's own pixel
        // fraction if retuning again after a future background swap).
        Align(alignment: const Alignment(0, 0.44), child: _ContactShadow()),
        Align(
          alignment: const Alignment(0, 0.28),
          child: FractionallySizedBox(
            // Placeholder "grew" cue for evolution1 — see [stage] doc.
            widthFactor: _isEvolved ? 0.66 : 0.56,
            child: GestureDetector(
              onTap: onTapNori,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  const NoriBreathingSprite(),
                  if (equippedAccessory != null)
                    Positioned(
                      top: -6,
                      child: AccessoryBadge(item: equippedAccessory!),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Soft warm glow standing in for real stage-2 art (see [NoriRoomStage.
/// stage]) — reuses the same blurred-circle + sparkle language as
/// welcome_screen.dart and evolution_screen.dart so it reads as "on brand"
/// rather than a bolted-on effect.
class _EvolvedAura extends StatelessWidget {
  const _EvolvedAura();

  static const _sparkles = [
    Offset(-0.62, -0.5),
    Offset(0.58, -0.42),
    Offset(0.7, 0.3),
    Offset(-0.68, 0.32),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 36, sigmaY: 36),
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.mustard.withValues(alpha: 0.55),
              ),
            ),
          ),
          for (final offset in _sparkles)
            Align(
              alignment: Alignment(offset.dx, offset.dy),
              child: Icon(
                Icons.star_rounded,
                size: 18,
                color: AppColors.mustardDark.withValues(alpha: 0.85),
              ),
            ),
        ],
      ),
    );
  }
}

/// A soft drawn ellipse standing in for ground contact — the room art's own
/// shadow was cut away with the background during asset prep (it read as a
/// halo once Nori was lifted off white), so this keeps him grounded on the
/// rug instead of looking like he's floating.
class _ContactShadow extends StatelessWidget {
  const _ContactShadow();

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.34,
      child: AspectRatio(
        aspectRatio: 3.2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.ink.withValues(alpha: 0.22),
                AppColors.ink.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
