import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Full-bleed translucent scrim + spinner. Must be used as a direct child of
/// a [Stack] (relies on [Positioned.fill]).
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.linen.withValues(alpha: 0.72),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
