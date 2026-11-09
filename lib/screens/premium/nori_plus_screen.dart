import 'package:flutter/material.dart';
import 'package:nori/screens/premium/nori_plans.dart';
import 'package:nori/screens/premium/payment_method_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/future_feature_banner.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_segmented_control.dart';
import 'package:nori/widgets/tactile_button.dart';

class NoriPlusScreen extends StatefulWidget {
  const NoriPlusScreen({super.key});

  @override
  State<NoriPlusScreen> createState() => _NoriPlusScreenState();
}

class _NoriPlusScreenState extends State<NoriPlusScreen> {
  PlanTier _tier = PlanTier.plus;
  BillingPeriod _period = BillingPeriod.yearly;

  void _showUnavailable() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Not available yet')));
  }

  void _openPaymentMethod() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodScreen(plan: PlanChoice(_tier, _period)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.linen,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
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
                const SizedBox(height: AppSpacing.stackSm),
                Text(
                  'Everything social stays free on every plan.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.stackMd),
                NoriSegmentedControl(
                  labels: const ['Monthly', 'Yearly'],
                  selectedIndex: _period.index,
                  onChanged: (i) =>
                      setState(() => _period = BillingPeriod.values[i]),
                ),
                const SizedBox(height: AppSpacing.stackMd),
                _PlanCard(
                  title: 'Nori Plus',
                  price: PlanChoice(PlanTier.plus, _period).priceLabel,
                  detail: 'For one person',
                  badge: _period == BillingPeriod.yearly ? 'Save 37%' : null,
                  selected: _tier == PlanTier.plus,
                  onTap: () => setState(() => _tier = PlanTier.plus),
                ),
                const SizedBox(height: AppSpacing.gutter),
                _PlanCard(
                  title: 'Nori Duo',
                  price: PlanChoice(PlanTier.duo, _period).priceLabel,
                  detail: 'Two linked accounts, one bill',
                  badge: _period == BillingPeriod.yearly ? 'Save 37%' : null,
                  selected: _tier == PlanTier.duo,
                  onTap: () => setState(() => _tier = PlanTier.duo),
                ),
                const SizedBox(height: AppSpacing.stackLg),
                TactileButton(
                  label: 'Upgrade now',
                  icon: Icons.rocket_launch,
                  onPressed: _openPaymentMethod,
                ),
                const SizedBox(height: AppSpacing.stackSm),
                Align(
                  child: TextButton(
                    onPressed: _showUnavailable,
                    child: const Text('Restore purchases'),
                  ),
                ),
                const SizedBox(height: AppSpacing.stackSm),
                Text(
                  'Subscription automatically renews unless canceled. '
                  'Terms of Service and Privacy Policy apply.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.inkMuted,
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
            color: AppColors.mossLight,
            border: Border.all(color: AppColors.ink, width: AppBorder.thick),
          ),
          child: const Icon(Icons.pets, color: AppColors.mossDark, size: 58),
        ),
        const SizedBox(height: AppSpacing.stackSm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Nori Plus',
              style: AppTextStyles.headlineLgMobile.copyWith(
                color: AppColors.mossDark,
              ),
            ),
            const SizedBox(width: AppSpacing.unit),
            const Icon(Icons.stars, color: AppColors.mustardDark, size: 26),
          ],
        ),
        const SizedBox(height: AppSpacing.unit),
        Text(
          'No ads, unlimited habits and a new exclusive accessory for your Nori every month.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLg.copyWith(color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

class _FeatureComparisonCard extends StatelessWidget {
  const _FeatureComparisonCard();

  @override
  Widget build(BuildContext context) {
    return const NoriCard(
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ComparisonRow(
            label: 'Feature',
            free: Text('Free'),
            plus: Text('Plus & Duo'),
            isHeader: true,
          ),
          _ComparisonRow(
            label: 'Active habits',
            free: Text('Up to 5'),
            plus: Text('Unlimited'),
          ),
          _ComparisonRow(
            label: 'Bucket list goals',
            free: Text('Up to 3'),
            plus: Text('Unlimited'),
            alternate: true,
          ),
          _ComparisonRow(
            label: 'No ads',
            free: Icon(Icons.close),
            plus: Icon(Icons.check_circle),
          ),
          _ComparisonRow(
            label: 'Daily coin bonus',
            free: Icon(Icons.close),
            plus: Icon(Icons.check_circle),
            alternate: true,
          ),
          _ComparisonRow(
            label: 'Monthly accessory',
            free: Icon(Icons.close),
            plus: Icon(Icons.check_circle),
          ),
          _ComparisonRow(
            label: 'Advanced stats',
            free: Icon(Icons.close),
            plus: Icon(Icons.check_circle),
            alternate: true,
          ),
          _ComparisonRow(
            label: 'Color themes',
            free: Icon(Icons.close),
            plus: Icon(Icons.check_circle),
          ),
          _ComparisonRow(
            label: 'Early access to new pets',
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
        color: isHeader || alternate ? AppColors.linenAlt : AppColors.white,
        border: showDivider
            ? const Border(
                bottom: BorderSide(color: AppColors.ink, width: AppBorder.thin),
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: baseStyle.copyWith(
                color: isHeader ? AppColors.inkMuted : AppColors.ink,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: IconTheme(
              data: const IconThemeData(color: AppColors.inkFaint, size: 22),
              child: DefaultTextStyle(
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.inkMuted,
                ),
                child: free,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: IconTheme(
              data: const IconThemeData(color: AppColors.mossDark, size: 22),
              child: DefaultTextStyle(
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.mossDark,
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
    this.detail,
    this.badge,
  });

  final String title;
  final String price;
  final bool selected;
  final VoidCallback onTap;
  final String? detail;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: selected ? AppColors.mossLight : AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            side: BorderSide(color: AppColors.ink, width: AppBorder.standard),
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
                                ? AppColors.mossDark
                                : AppColors.ink,
                          ),
                        ),
                        Text(
                          price,
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                        if (detail != null)
                          Text(
                            detail!,
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.inkMuted,
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
                      color: selected ? AppColors.moss : AppColors.white,
                      border: Border.all(
                        color: AppColors.ink,
                        width: AppBorder.thin,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check,
                            size: 17,
                            color: AppColors.ink,
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
                color: AppColors.mustard,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: AppColors.ink, width: AppBorder.thin),
              ),
              child: Text(
                badge!,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.mustardDark,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
