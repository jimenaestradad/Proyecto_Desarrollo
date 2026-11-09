import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/validators.dart';

/// The password rules as a checklist that ticks off while the person types.
/// Purely local (no network), so it is instant; the submit-time
/// [validateNewPassword] stays as the backstop.
class PasswordRules extends StatelessWidget {
  const PasswordRules({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final checks = passwordChecks(value.text);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Rule('At least $passwordMinLength characters', checks.longEnough),
            _Rule('A letter', checks.hasLetter),
            _Rule('A number', checks.hasNumber),
          ],
        );
      },
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.label, this.met);

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: met ? AppColors.mossDark : AppColors.inkFaint,
          ),
          const SizedBox(width: AppSpacing.unit),
          Text(
            label,
            style: AppTextStyles.labelSm.copyWith(
              color: met ? AppColors.mossDark : AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
