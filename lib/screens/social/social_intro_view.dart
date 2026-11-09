import 'package:flutter/material.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/tactile_button.dart';

class SocialIntroView extends StatelessWidget {
  const SocialIntroView({
    super.key,
    required this.onFindFriends,
    required this.onInvite,
  });

  final VoidCallback onFindFriends;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Good habits grow together', style: AppTextStyles.headlineLgMobile),
      const SizedBox(height: AppSpacing.unit),
      Text(
        'Find your friends and cheer each other on, one habit at a time.',
        style: AppTextStyles.bodyMd.copyWith(color: AppColors.inkMuted),
      ),
      const SizedBox(height: AppSpacing.stackMd),
      const _Explainer(
        icon: Icons.people_outline,
        color: AppColors.mossLight,
        title: 'Keep each other going',
        message: 'Build friend streaks and send a little encouragement.',
      ),
      const SizedBox(height: AppSpacing.stackSm),
      const _Explainer(
        icon: Icons.add_a_photo_outlined,
        color: AppColors.mustardLight,
        title: 'Share proof, celebrate progress',
        message: 'Share your completed habits and join friendly competitions.',
      ),
      const SizedBox(height: AppSpacing.stackSm),
      const _Explainer(
        icon: Icons.pets,
        color: AppColors.sky,
        title: "Visit each other's pets",
        message: "Drop by a friend's pet room and send a cheerful hello.",
      ),
      const SizedBox(height: AppSpacing.stackMd),
      TactileButton(
        label: 'Find by username',
        icon: Icons.person_search_outlined,
        onPressed: onFindFriends,
      ),
      const SizedBox(height: AppSpacing.stackSm),
      TactileButton(
        label: 'Share invite link',
        icon: Icons.link,
        backgroundColor: AppColors.white,
        onPressed: onInvite,
      ),
    ],
  );
}

class _Explainer extends StatelessWidget {
  const _Explainer({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => NoriCard(
    color: color,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NoriIconBadge(icon: icon, background: color, size: 48, iconSize: 24),
        const SizedBox(width: AppSpacing.stackSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelLg),
              const SizedBox(height: AppSpacing.unit),
              Text(message, style: AppTextStyles.bodyMd),
            ],
          ),
        ),
      ],
    ),
  );
}
