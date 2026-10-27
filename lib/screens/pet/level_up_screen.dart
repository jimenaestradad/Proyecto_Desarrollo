import 'package:flutter/material.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/celebration_card.dart';

/// Full-screen celebration shown when the user's level increases —
/// [EvolutionScreen]'s sibling for the other half of the core loop
/// (complete habits → earn XP → level up → pet grows). Both share
/// [CelebrationScreen]'s shell and differ only in words and the badge.
/// Push with [showLevelUpCelebration] rather than a bare `Navigator.push`.
class LevelUpScreen extends StatelessWidget {
  const LevelUpScreen({super.key, required this.level, required this.petName});

  final int level;
  final String petName;

  @override
  Widget build(BuildContext context) {
    return CelebrationScreen(
      kicker: 'LEVEL UP!',
      badge: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.military_tech,
              size: 44,
              color: AppColors.mustardDark,
            ),
            const SizedBox(height: 4),
            Text('Lv. $level', style: AppTextStyles.headlineMd),
          ],
        ),
      ),
      title: 'You Leveled Up!',
      message: '$petName is proud of you — keep those habits up!',
    );
  }
}

Future<void> showLevelUpCelebration(
  BuildContext context, {
  required int level,
  required String petName,
}) => showCelebrationRoute(
  context,
  (_) => LevelUpScreen(level: level, petName: petName),
);
