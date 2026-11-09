import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/remote_errors.dart';
import 'tactile_button.dart';

/// What a screen shows in place of its loading spinner when the first
/// load failed (see RemoteLoadState.loadError) -- a message and a retry,
/// instead of spinning forever.
class LoadErrorView extends StatelessWidget {
  const LoadErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.stackLg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 56,
                color: AppColors.inkMuted,
              ),
              const SizedBox(height: AppSpacing.stackSm),
              Text(
                "Couldn't load this",
                style: AppTextStyles.headlineLgMobile,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.stackSm),
              Text(
                remoteErrorMessage(error),
                style: AppTextStyles.bodyLg.copyWith(color: AppColors.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.stackLg),
              TactileButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
                expand: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
