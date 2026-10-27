import 'package:flutter/material.dart';
import '../data/accessory_catalog.dart';
import '../models/pet.dart';
import '../theme/app_theme.dart';
import 'accessory_art.dart';
import 'nori_breathing_sprite.dart';
import 'nori_evolved_sprite.dart';

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

  /// Which form to show: [PetEvolutionStage.baby] is the breathing sprite,
  /// anything later is the winged [NoriEvolvedSprite]. Every evolved stage
  /// shares that one form today — there's art for two forms only.
  final PetEvolutionStage stage;

  /// The accessory equipped in Customization (see accessory_catalog.dart),
  /// or null when nothing is equipped. Drawn near Nori's head via
  /// accessory_art.dart's hand-drawn, flat-outlined illustrations, matching
  /// his own art style rather than a generic UI icon.
  ///
  /// Only drawn on the baby form: accessory positions are calibrated against
  /// the baby's frames, and the evolved form has no anchors yet (see
  /// docs/KNOWN_ISSUES.md), so it's hidden there rather than floating in the
  /// wrong place.
  final AccessoryItem? equippedAccessory;

  bool get _isEvolved => stage != PetEvolutionStage.baby;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The evolved canvas is mostly wing span, so it needs far more width
        // than the baby to keep the body about the same height. Over 1.0 the
        // widest wing tips clip at the screen edge mid-flap — accepted.
        final widthFactor = _isEvolved ? 1.3 : 0.56;

        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/room_interior.jpg', fit: BoxFit.cover),
            // Rug sits higher up in this background than the previous one,
            // so both are shifted up to match (see the rug band's own
            // pixel fraction if retuning again after a future background
            // swap).
            Align(alignment: const Alignment(0, 0.44), child: _ContactShadow()),
            Align(
              alignment: const Alignment(0, 0.28),
              child: FractionallySizedBox(
                widthFactor: widthFactor,
                child: GestureDetector(
                  onTap: onTapNori,
                  child: _isEvolved
                      ? LayoutBuilder(
                          builder: (context, box) =>
                              NoriEvolvedSprite(width: box.maxWidth),
                        )
                      : NoriBreathingSprite(
                          overlayBuilder: equippedAccessory == null
                              ? null
                              : (context, spriteWidth, anchors) =>
                                    animatedPositionedAccessoryArt(
                                      item: equippedAccessory!,
                                      spriteWidth: spriteWidth,
                                      anchors: anchors,
                                    ) ??
                                    positionedAccessoryArt(
                                      item: equippedAccessory!,
                                      referenceSize: spriteWidth,
                                    ),
                        ),
                ),
              ),
            ),
          ],
        );
      },
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
