import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Modal bottom sheet in the Flat Storybook style: white, ink-bordered top
/// edge, radius [AppRadius.md], a small grab handle, optional heading.
/// [builder] provides the sheet body; pop with `Navigator.pop(context, value)`.
Future<T?> showNoriSheet<T>(
  BuildContext context, {
  String? title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
      side: BorderSide(color: AppColors.ink, width: AppBorder.standard),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.containerPaddingMobile,
          AppSpacing.stackSm,
          AppSpacing.containerPaddingMobile,
          AppSpacing.stackMd + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inkFaint,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              if (title != null) ...[
                Text(title, style: AppTextStyles.headlineMd),
                const SizedBox(height: AppSpacing.stackSm),
              ],
              builder(sheetContext),
            ],
          ),
        ),
      ),
    ),
  );
}

/// One tappable row inside a [showNoriSheet] ("Remove friend", "Block", …).
class NoriSheetAction extends StatelessWidget {
  const NoriSheetAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.error : AppColors.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.stackSm,
          horizontal: 4,
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppSpacing.stackSm),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.labelLg.copyWith(
                  color: color,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
