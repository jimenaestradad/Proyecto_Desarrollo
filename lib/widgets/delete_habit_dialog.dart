import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../theme/app_theme.dart';

/// Confirms a permanent habit delete — shared by the edit-habit screen and
/// the Archived list. Only offered for habits with almost no history
/// (kMaxDeletableActiveDays); anything else can only be archived.
Future<bool> confirmDeleteHabit(BuildContext context, Habit habit) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
      ),
      title: Text('Delete "${habit.name}"?'),
      content: const Text(
        'This permanently removes the habit and anything you logged for it, '
        'and takes back any XP and coins it earned. This can’t be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
