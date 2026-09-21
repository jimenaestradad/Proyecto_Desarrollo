import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Title row for a card/page section, with an optional leading icon and a
/// trailing action. `trailing` is a full widget slot (not a baked-in
/// `TextButton`) since call sites style their trailing action differently.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    this.icon,
    required this.title,
    this.titleStyle,
    required this.trailing,
  });

  final IconData? icon;
  final String title;

  /// Defaults to [AppTextStyles.headlineMd] at 18px, the size most section
  /// headers use — pass the full [AppTextStyles.headlineMd] to match a
  /// page-level heading instead (e.g. Profile's achievements preview).
  final TextStyle? titleStyle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: AppColors.mossDark, size: 20),
          const SizedBox(width: AppSpacing.unit),
        ],
        Expanded(
          child: Text(
            title,
            style: titleStyle ?? AppTextStyles.headlineMd.copyWith(fontSize: 18),
          ),
        ),
        trailing,
      ],
    );
  }
}
