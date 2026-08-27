import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Primary CTA button styled after the mockup's "tactile-button" /
/// "btn-pressable" classes: a solid drop shadow that flattens and the
/// button shifts down when pressed, like a physical key.
class TactileButton extends StatefulWidget {
  const TactileButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor = AppColors.primary,
    this.foregroundColor = AppColors.onPrimary,
    this.shadowColor = AppColors.onPrimaryFixedVariant,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color shadowColor;
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
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: widget.onPressed == null
              ? widget.backgroundColor.withValues(alpha: 0.5)
              : widget.backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: _pressed
              ? const []
              : [
                  BoxShadow(
                    color: widget.shadowColor,
                    offset: const Offset(0, 4),
                  ),
                ],
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
