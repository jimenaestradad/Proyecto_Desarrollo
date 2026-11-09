import 'package:flutter/material.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/loading_overlay.dart';
import 'package:nori/widgets/nori_card.dart';

/// The shell shared by Log In, Sign Up and Choose Username: a scrollable,
/// vertically centered, width-limited card with a [LoadingOverlay] on top
/// while [loading].
class AuthCardScreen extends StatelessWidget {
  const AuthCardScreen({
    super.key,
    required this.loading,
    required this.children,
  });

  final bool loading;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.containerPaddingMobile,
                    vertical: AppSpacing.stackMd,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          (constraints.maxHeight - (AppSpacing.stackMd * 2))
                              .clamp(0.0, double.infinity),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: NoriCard(
                          padding: const EdgeInsets.all(AppSpacing.stackMd),
                          radius: AppRadius.lg,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: children,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (loading) const LoadingOverlay(),
        ],
      ),
    );
  }
}
