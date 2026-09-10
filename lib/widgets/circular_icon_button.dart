import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small circular icon button — a bordered white "Flat Storybook" chip
/// around an [Icon], matching Home's Shop shortcut. Used for compact header
/// actions (Shop, Notifications, Bucket List, ...) across screens.
class CircularIconButton extends StatelessWidget {
  const CircularIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 20,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.88),
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.ink, width: AppBorder.standard),
      ),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize, color: AppColors.ink),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
      ),
    );
  }
}
