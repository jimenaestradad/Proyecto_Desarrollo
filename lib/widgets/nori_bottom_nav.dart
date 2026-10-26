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
        border: Border(
          top: BorderSide(color: AppColors.ink, width: AppBorder.standard),
        ),
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
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ExcludeSemantics(
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
                // Plain Text, not a fixed-height FittedBox(scaleDown): the
                // old version shrank labels back down to fit a fixed 14px
                // box, which meant a larger system font size made the nav
                // labels *smaller* instead of bigger — the one place an
                // accessibility setting made the app actively worse. Every
                // label is short enough now ("Calendar" is the longest) to
                // render at full size in an Expanded slice at normal scale;
                // the bar has no fixed height (see NoriShell), so it simply
                // grows taller under a larger text scale instead of
                // shrinking its content. `ellipsis` is only a backstop for
                // extreme scale factors, not the normal-case behavior.
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSm.copyWith(
                    letterSpacing: 0,
                    color: selected ? AppColors.ink : AppColors.inkFaint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
