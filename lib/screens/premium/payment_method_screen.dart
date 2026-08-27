import 'package:flutter/material.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/future_feature_banner.dart';
import 'package:nori/widgets/tactile_button.dart';

enum _PaymentMethod { card, paypal, express }

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  _PaymentMethod _selectedMethod = _PaymentMethod.card;

  void _showUnavailable() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Not available yet')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('Payment Method', style: AppTextStyles.headlineLgMobile),
        actions: const [SizedBox(width: 48)],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 760
              ? AppSpacing.containerPaddingDesktop
              : AppSpacing.containerPaddingMobile;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.gutter,
              horizontalPadding,
              AppSpacing.stackLg,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FutureFeatureBanner(
                      message:
                          "Payments aren't implemented — nothing here is sent or stored.",
                    ),
                    const SizedBox(height: AppSpacing.stackMd),
                    const _PlanSummaryCard(),
                    const SizedBox(height: AppSpacing.stackMd),
                    _PaymentOptionCard(
                      selected: _selectedMethod == _PaymentMethod.card,
                      onTap: () =>
                          setState(() => _selectedMethod = _PaymentMethod.card),
                      icon: Icons.credit_card,
                      title: 'Credit / Debit Card',
                      child: _selectedMethod == _PaymentMethod.card
                          ? const _CardPreviewFields()
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.gutter),
                    _PaymentOptionCard(
                      selected: _selectedMethod == _PaymentMethod.paypal,
                      onTap: () => setState(
                        () => _selectedMethod = _PaymentMethod.paypal,
                      ),
                      icon: Icons.account_balance_wallet,
                      title: 'PayPal',
                      child: _selectedMethod == _PaymentMethod.paypal
                          ? Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton(
                                onPressed: _showUnavailable,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.onSurface,
                                  side: const BorderSide(
                                    color: AppColors.outlineVariant,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.stackMd,
                                    vertical: AppSpacing.stackSm,
                                  ),
                                ),
                                child: const Text('Connect'),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.gutter),
                    _PaymentOptionCard(
                      selected: _selectedMethod == _PaymentMethod.express,
                      onTap: () => setState(
                        () => _selectedMethod = _PaymentMethod.express,
                      ),
                      icon: Icons.phone_iphone,
                      title: 'Express Checkout',
                      child: _selectedMethod == _PaymentMethod.express
                          ? Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _showUnavailable,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.inverseSurface,
                                      foregroundColor:
                                          AppColors.inverseOnSurface,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.stackSm,
                                      ),
                                    ),
                                    child: const Text('Pay'),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.stackSm),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _showUnavailable,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.onSurface,
                                      side: const BorderSide(
                                        color: AppColors.outline,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.stackSm,
                                      ),
                                    ),
                                    child: const Text('G Pay'),
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.stackMd),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock,
                          size: 20,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: AppSpacing.unit),
                        Text(
                          'Secure & Encrypted',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.secondary,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _CheckoutBar(onConfirm: _showUnavailable),
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.containerPaddingMobile),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SELECTED PLAN',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Nori Plus Yearly', style: AppTextStyles.headlineMd),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.gutter),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                r'$39.99',
                style: AppTextStyles.headlineLgMobile.copyWith(
                  color: AppColors.primary,
                ),
              ),
              Text(
                '/year',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentOptionCard extends StatelessWidget {
  const _PaymentOptionCard({
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.title,
    this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.surfaceContainerLow
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.containerPaddingMobile),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _SelectionDot(selected: selected),
                      const SizedBox(width: AppSpacing.stackSm),
                      Icon(
                        icon,
                        color: selected
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.stackSm),
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyles.bodyLg.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (child != null) ...[
                    const SizedBox(height: AppSpacing.stackMd),
                    child!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceContainerLowest,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.outlineVariant,
          width: 2,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? AppColors.primary : Colors.transparent,
        ),
      ),
    );
  }
}

class _CardPreviewFields extends StatelessWidget {
  const _CardPreviewFields();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _PreviewTextField(
          label: 'Card Number',
          hint: '0000 0000 0000 0000',
          suffixIcon: Icons.credit_score,
        ),
        SizedBox(height: AppSpacing.gutter),
        Row(
          children: [
            Expanded(
              child: _PreviewTextField(label: 'Expiry Date', hint: 'MM/YY'),
            ),
            SizedBox(width: AppSpacing.gutter),
            Expanded(
              child: _PreviewTextField(label: 'CVV', hint: '123'),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.gutter),
        _PreviewTextField(label: 'Cardholder Name', hint: 'Name on card'),
      ],
    );
  }
}

class _PreviewTextField extends StatelessWidget {
  const _PreviewTextField({
    required this.label,
    required this.hint,
    this.suffixIcon,
  });

  final String label;
  final String hint;
  final IconData? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: AppColors.surfaceContainer,
        labelStyle: AppTextStyles.labelSm.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
        hintStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.outline),
        suffixIcon: suffixIcon == null
            ? null
            : Icon(suffixIcon, color: AppColors.outline),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.stackSm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: const Border(top: BorderSide(color: AppColors.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.containerPaddingMobile),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final total = Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Due Today',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      Text(r'$39.99', style: AppTextStyles.headlineLgMobile),
                    ],
                  );

                  if (constraints.maxWidth < 440) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        total,
                        const SizedBox(height: AppSpacing.stackSm),
                        TactileButton(
                          label: 'Confirm & Subscribe',
                          icon: Icons.check_circle,
                          onPressed: onConfirm,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      total,
                      const SizedBox(width: AppSpacing.stackMd),
                      Expanded(
                        child: TactileButton(
                          label: 'Confirm & Subscribe',
                          icon: Icons.check_circle,
                          onPressed: onConfirm,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
