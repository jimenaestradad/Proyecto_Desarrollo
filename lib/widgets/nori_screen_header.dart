import 'package:flutter/material.dart';

/// Header row with leading widget, title and optional trailing widget.
/// Slots accept composite widgets; screens needing a different layout build their own.
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
  /// [result] is what the route pops with — `Navigator.pop` skips
  /// `PopScope`, so a screen that returns a value on system back must pass
  /// the same value here.
  static Widget backButton(BuildContext context, {Object? result}) =>
      IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.pop(context, result),
        icon: const Icon(Icons.arrow_back),
      );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        leading,
        Expanded(
          // One line that shrinks to fit: with a large system font the avatar,
          // streak chip and XP pill leave little room, and the title used to
          // break mid-word ("Calenda / r").
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: titleTextAlign == TextAlign.center
                ? Alignment.center
                : AlignmentDirectional.centerStart,
            child: Text(
              title,
              style: titleStyle,
              textAlign: titleTextAlign,
              maxLines: 1,
            ),
          ),
        ),
        if (trailing != null) const SizedBox(width: 8),
        ?trailing,
      ],
    );
  }
}
