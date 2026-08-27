import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NoriBottomNav extends StatelessWidget {
  const NoriBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (icon: Icons.pets, label: 'Home'),
    (icon: Icons.check_circle, label: 'Habits'),
    (icon: Icons.calendar_month, label: 'Calendar'),
    (icon: Icons.emoji_events, label: 'Achievements'),
    (icon: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.sm),
          topRight: Radius.circular(AppRadius.sm),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < _items.length; i++)
              _NavItem(
                icon: _items[i].icon,
                label: _items[i].label,
                selected: i == currentIndex,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: selected
                  ? AppColors.onPrimaryContainer
                  : AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.labelSm.copyWith(
                color: selected
                    ? AppColors.onPrimaryContainer
                    : AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
