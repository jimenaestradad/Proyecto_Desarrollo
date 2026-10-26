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
    this.onChanged,
    this.suffixIcon,
    this.helperText,
    this.helperColor,
    this.readOnly = false,
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

  /// Fires on every keystroke — used for live validation (e.g. the sign-up
  /// screen's "is this username taken?" check) without waiting for submit.
  final ValueChanged<String>? onChanged;

  /// Shown at the trailing edge of the field, e.g. a spinner/check/cross
  /// reflecting live-validation state. Doesn't replace `obscureText`'s own
  /// visibility toggle (there isn't one here) — fields needing both would
  /// need a small rework, not a case this screen hits yet.
  final Widget? suffixIcon;

  /// Small status line under the field (e.g. "Username is taken"). Purely
  /// informational — doesn't block submission on its own.
  final String? helperText;
  final Color? helperColor;

  /// Shows the value without letting it be edited (e.g. a Google account's
  /// email, which belongs to Google).
  final bool readOnly;

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
            readOnly: readOnly,
            obscureText: obscureText,
            enableSuggestions: !obscureText,
            autocorrect: !obscureText,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
            style: AppTextStyles.bodyMd,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.bodyMd.copyWith(
                color: AppColors.inkFaint,
              ),
              prefixIcon: Icon(icon, color: AppColors.ink),
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: readOnly ? AppColors.linen : AppColors.linenAlt,
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
          if (helperText != null) ...[
            const SizedBox(height: AppSpacing.unit),
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.gutter),
              child: Text(
                helperText!,
                style: AppTextStyles.labelSm.copyWith(
                  color: helperColor ?? AppColors.inkMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
