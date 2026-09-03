import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Primary CTA button for the "Flat Storybook" design system: a flat fill
/// with a thick ink outline and a hard (non-blurred) ink offset shadow that
/// collapses — like a pressed sticker — when tapped.
class TactileButton extends StatefulWidget {
  const TactileButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor = AppColors.terracotta,
    this.foregroundColor = AppColors.ink,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool expand;

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: widget.onPressed == null
              ? widget.backgroundColor.withValues(alpha: 0.5)
              : widget.backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.ink, width: AppBorder.standard),
          boxShadow: _pressed
              ? const []
              : const [BoxShadow(color: AppColors.ink, offset: Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.label,
              style: AppTextStyles.labelLg.copyWith(
                color: widget.foregroundColor,
              ),
            ),
            if (widget.icon != null) ...[
              const SizedBox(width: 8),
              Icon(widget.icon, size: 20, color: widget.foregroundColor),
            ],
          ],
        ),
      ),
    );

    return widget.expand
        ? SizedBox(width: double.infinity, child: child)
        : child;
  }
}
