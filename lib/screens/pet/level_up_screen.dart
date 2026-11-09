import 'package:flutter/material.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/celebration_card.dart';

/// Celebrates a level increase using the shared [CelebrationScreen] shell.
/// Use [showLevelUpCelebration] to present it.
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
      title: 'You leveled up!',
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
