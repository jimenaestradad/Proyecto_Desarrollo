import 'package:flutter/material.dart';

/// Top-of-screen row: a leading widget (back button or avatar), a title, and
/// an optional trailing widget. `leading`/`trailing` are plain widget slots —
/// a multi-part trailing (e.g. a streak chip next to an XP pill) is just a
/// `Row` passed in. Screens with a genuinely different shape (extra
/// responsive branching, a composite trailing control) build their own
/// header instead of forcing it into this one.
class NoriScreenHeader extends StatelessWidget {
  const NoriScreenHeader({
    super.key,
    required this.leading,
    required this.title,
    required this.titleStyle,
    this.titleTextAlign,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final TextStyle titleStyle;
  final TextAlign? titleTextAlign;
  final Widget? trailing;

  /// The plain back-`IconButton` most headers use as their `leading`.
  static Widget backButton(BuildContext context) => IconButton(
    onPressed: () => Navigator.pop(context),
    icon: const Icon(Icons.arrow_back),
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        leading,
        Expanded(
          child: Text(title, style: titleStyle, textAlign: titleTextAlign),
        ),
        ?trailing,
      ],
    );
  }
}
