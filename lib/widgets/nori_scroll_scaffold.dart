import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shared padded, width-capped, centered scroll body.
/// The width cap is a ceiling; target Android phone widths use the mobile layout.
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
