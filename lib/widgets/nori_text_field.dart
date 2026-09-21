import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Labeled, pill-bordered text field — the shape [SignUpScreen] originally
/// had as a private `_buildField`, promoted here so [EditProfileScreen] can
/// reuse it instead of re-implementing the same decoration.
class NoriTextField extends StatelessWidget {
  const NoriTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.full)),
      borderSide: BorderSide(color: AppColors.ink, width: AppBorder.standard),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.gutter),
            child: Text(label, style: AppTextStyles.labelSm),
          ),
          const SizedBox(height: AppSpacing.unit),
          TextField(
            controller: controller,
            obscureText: obscureText,
            enableSuggestions: !obscureText,
            autocorrect: !obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            onSubmitted: onSubmitted,
            style: AppTextStyles.bodyMd,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.bodyMd.copyWith(
                color: AppColors.inkFaint,
              ),
              prefixIcon: Icon(icon, color: AppColors.ink),
              filled: true,
              fillColor: AppColors.linenAlt,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.gutter,
                vertical: AppSpacing.stackSm,
              ),
              border: border,
              enabledBorder: border,
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(AppRadius.full)),
                borderSide: BorderSide(
                  color: AppColors.ink,
                  width: AppBorder.thick,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
