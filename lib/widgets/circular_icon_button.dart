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
    this.showDot = false,
    this.largeTapTarget = false,
  });

  /// Lays the button out in a 48x48dp box (Android's minimum touch target)
  /// around the same 36dp circle. Off by default so existing rows keep their
  /// spacing; turn it on where there is room.
  final bool largeTapTarget;

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double iconSize;

  /// A small terracotta dot on the top-right edge, e.g. unread notifications.
  /// Callers should say so in [tooltip] too, for screen readers.
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final button = Material(
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
    if (!showDot) return _wrap(button);
    return _wrap(
      Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: -1,
            right: -1,
            child: IgnorePointer(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.terracotta,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.ink,
                    width: AppBorder.thin,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// With [largeTapTarget], taps anywhere in the 48dp box counts. The
  /// circle's own button still handles taps on the circle (and its ripple);
  /// the box only catches the margin around it.
  Widget _wrap(Widget circle) {
    if (!largeTapTarget) return circle;
    return SizedBox.square(
      dimension: 48,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        excludeFromSemantics: true,
        child: Center(child: circle),
      ),
    );
  }
}
