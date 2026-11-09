import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Small "type one line" dialog in the Flat Storybook style (white, ink-
/// bordered, cancel + save). Returns the typed text, or null if cancelled.
/// Shared by Settings (add/rename a habit category) and Add Habit's inline
/// "Add Category" entry.
Future<String?> showNoriTextPrompt(
  BuildContext context, {
  required String title,
  String? hint,
  String? initialValue,
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _TextPromptDialog(title: title, hint: hint, initialValue: initialValue),
);

/// Owns its controller so it's disposed with the dialog, after the close
/// animation — disposing right after `showDialog` returns would leave the
/// still-animating field using a dead controller.
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({required this.title, this.hint, this.initialValue});

  final String title;
  final String? hint;
  final String? initialValue;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
      ),
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
