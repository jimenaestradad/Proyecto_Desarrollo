import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
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
  const NoriRoomStage({super.key, required this.onTapNori});

  final VoidCallback onTapNori;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/room_interior.jpg', fit: BoxFit.cover),
        // Rug sits higher up in this background than the previous one, so
        // both are shifted up to match (see the rug band's own pixel
        // fraction if retuning again after a future background swap).
        Align(alignment: const Alignment(0, 0.44), child: _ContactShadow()),
        Align(
          alignment: const Alignment(0, 0.28),
          child: FractionallySizedBox(
            widthFactor: 0.56,
            child: GestureDetector(
              onTap: onTapNori,
              child: const NoriBreathingSprite(),
            ),
          ),
        ),
      ],
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
