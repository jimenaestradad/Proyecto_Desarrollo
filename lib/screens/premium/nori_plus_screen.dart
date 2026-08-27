import 'package:flutter/material.dart';
import 'package:nori/screens/premium/payment_method_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/future_feature_banner.dart';
import 'package:nori/widgets/tactile_button.dart';

class NoriPlusScreen extends StatefulWidget {
  const NoriPlusScreen({super.key});

  @override
  State<NoriPlusScreen> createState() => _NoriPlusScreenState();
}

class _NoriPlusScreenState extends State<NoriPlusScreen> {
  int _selectedPlan = 1;

  void _showUnavailable() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Not available yet')));
  }

  void _openPaymentMethod() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentMethodScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.containerPaddingMobile,
          AppSpacing.gutter,
          AppSpacing.containerPaddingMobile,
          AppSpacing.stackLg,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FutureFeatureBanner(),
                const SizedBox(height: AppSpacing.stackLg),
                const _PlusHero(),
                const SizedBox(height: AppSpacing.stackLg),
                const _FeatureComparisonCard(),
                const SizedBox(height: AppSpacing.stackMd),
                _PlanCard(
                  title: 'Monthly',
                  price: r'$4.99 / month',
                  selected: _selectedPlan == 0,
                  onTap: () => setState(() => _selectedPlan = 0),
                ),
                const SizedBox(height: AppSpacing.gutter),
                _PlanCard(
                  title: 'Yearly',
                  price: r'$39.99 / year',
                  badge: 'Save 33%',
                  selected: _selectedPlan == 1,
                  onTap: () => setState(() => _selectedPlan = 1),
                ),
                const SizedBox(height: AppSpacing.stackLg),
                TactileButton(
                  label: 'Upgrade Now',
                  icon: Icons.rocket_launch,
                  onPressed: _openPaymentMethod,
                ),
                const SizedBox(height: AppSpacing.stackSm),
                Align(
                  child: TextButton(
                    onPressed: _showUnavailable,
                    child: const Text('Restore Purchases'),
                  ),
                ),
                const SizedBox(height: AppSpacing.stackSm),
                Text(
                  'Subscription automatically renews unless canceled. '
                  'Terms of Service and Privacy Policy apply.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlusHero extends StatelessWidget {
  const _PlusHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryFixed,
            border: Border.all(
              color: AppColors.surfaceContainerLowest,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.pets, color: AppColors.primary, size: 58),
        ),
        const SizedBox(height: AppSpacing.stackSm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Nori Plus',
              style: AppTextStyles.headlineLgMobile.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.unit),
            const Icon(
              Icons.stars,
              color: AppColors.tertiaryFixedDim,
              size: 26,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.unit),
        Text(
          'Unlock exclusive pets, unlimited habits, and reach your goals faster.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLg.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _FeatureComparisonCard extends StatelessWidget {
  const _FeatureComparisonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        children: [
          _ComparisonRow(
            label: 'Feature',
            free: Text('Free'),
            plus: Text('Plus'),
            isHeader: true,
          ),
          _ComparisonRow(
            label: 'Active Habits',
            free: Text('Up to 3'),
            plus: Text('Unlimited'),
          ),
          _ComparisonRow(
            label: 'Exclusive Pets',
            free: Icon(Icons.close),
            plus: Icon(Icons.check_circle),
            alternate: true,
          ),
          _ComparisonRow(
            label: 'Advanced Analytics',
            free: Icon(Icons.close),
            plus: Icon(Icons.check_circle),
          ),
          _ComparisonRow(
            label: 'Custom Widgets',
            free: Icon(Icons.close),
            plus: Icon(Icons.check_circle),
            alternate: true,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.free,
    required this.plus,
    this.isHeader = false,
    this.alternate = false,
    this.showDivider = true,
  });

  final String label;
  final Widget free;
  final Widget plus;
  final bool isHeader;
  final bool alternate;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final baseStyle = isHeader ? AppTextStyles.labelLg : AppTextStyles.bodyMd;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: isHeader ? AppSpacing.gutter : AppSpacing.stackSm,
      ),
      decoration: BoxDecoration(
        color: isHeader || alternate
            ? AppColors.surfaceContainerLow
            : AppColors.surfaceContainerLowest,
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.outlineVariant))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: baseStyle.copyWith(
                color: isHeader
                    ? AppColors.onSurfaceVariant
                    : AppColors.onSurface,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: IconTheme(
              data: const IconThemeData(color: AppColors.outline, size: 22),
              child: DefaultTextStyle(
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                child: free,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: IconTheme(
              data: const IconThemeData(color: AppColors.primary, size: 22),
              child: DefaultTextStyle(
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
                child: plus,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String price;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: selected
              ? AppColors.primaryFixed.withValues(alpha: 0.55)
              : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.outlineVariant,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.headlineMd.copyWith(
                            color: selected
                                ? AppColors.primary
                                : AppColors.onSurface,
                          ),
                        ),
                        Text(
                          price,
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.primary : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.outlineVariant,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check,
                            size: 17,
                            color: AppColors.onPrimary,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: -11,
            right: AppSpacing.gutter,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.unit,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.tertiaryFixedDim,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: AppColors.tertiaryContainer),
              ),
              child: Text(
                badge!,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onTertiaryFixedVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
