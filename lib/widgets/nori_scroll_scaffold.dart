import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The scrollable body shape shared by most top-level screens: a padded,
/// width-capped, centered column. `maxWidth` only matters on screen widths
/// this app doesn't actually ship to — the app is Android-only (see
/// CLAUDE.md), and every real target width is well under even the smallest
/// `maxWidth` any screen uses — but it costs nothing to keep as a ceiling.
///
/// This intentionally does NOT re-add the desktop-vs-mobile responsive
/// padding/branching every screen used to compute via its own `LayoutBuilder`
/// — that branch never fires on the phone widths this app targets (per
/// CLAUDE.md, only the mobile layout matches the real Android target), so it
/// was dead code, not a feature being dropped.
class NoriScrollScaffold extends StatelessWidget {
  const NoriScrollScaffold({
    super.key,
    required this.maxWidth,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final double maxWidth;
  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerPaddingMobile,
        AppSpacing.gutter,
        AppSpacing.containerPaddingMobile,
        AppSpacing.stackLg,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: crossAxisAlignment,
            children: children,
          ),
        ),
      ),
    );
  }
}
