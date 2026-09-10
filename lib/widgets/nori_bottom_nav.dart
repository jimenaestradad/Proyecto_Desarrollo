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
    (icon: Icons.groups, label: 'Social'),
    (icon: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.ink, width: AppBorder.standard)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _NavItem(
                  icon: _items[i].icon,
                  label: _items[i].label,
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.mossLight : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: selected
              ? Border.all(color: AppColors.ink, width: AppBorder.thin)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? AppColors.mossDark : AppColors.inkFaint,
            ),
            const SizedBox(height: 4),
            // FittedBox instead of a fixed font size + ellipsis: on narrow
            // screens five labels (one as long as "Achievements") in equal
            // Expanded slices don't all fit at full size, and truncating to
            // "Achiev…" reads as broken. Scaling down keeps the whole word.
            SizedBox(
              width: double.infinity,
              height: 14,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppTextStyles.labelSm.copyWith(
                    letterSpacing: 0,
                    color: selected ? AppColors.ink : AppColors.inkFaint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
