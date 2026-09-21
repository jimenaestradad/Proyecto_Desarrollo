import 'package:flutter/material.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/future_feature_banner.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
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
      backgroundColor: AppColors.linen,
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
      body: NoriScrollScaffold(
        maxWidth: 680,
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
            onTap: () => setState(() => _selectedMethod = _PaymentMethod.card),
            icon: Icons.credit_card,
            title: 'Credit / Debit Card',
            child: _selectedMethod == _PaymentMethod.card
                ? const _CardPreviewFields()
                : null,
          ),
          const SizedBox(height: AppSpacing.gutter),
          _PaymentOptionCard(
            selected: _selectedMethod == _PaymentMethod.paypal,
            onTap: () =>
                setState(() => _selectedMethod = _PaymentMethod.paypal),
            icon: Icons.account_balance_wallet,
            title: 'PayPal',
            child: _selectedMethod == _PaymentMethod.paypal
                ? Align(
                    alignment: Alignment.centerRight,
                    child: TactileButton(
                      label: 'Connect',
                      onPressed: _showUnavailable,
                      backgroundColor: AppColors.white,
                      expand: false,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.gutter),
          _PaymentOptionCard(
            selected: _selectedMethod == _PaymentMethod.express,
            onTap: () =>
                setState(() => _selectedMethod = _PaymentMethod.express),
            icon: Icons.phone_iphone,
            title: 'Express Checkout',
            child: _selectedMethod == _PaymentMethod.express
                ? Row(
                    children: [
                      Expanded(
                        child: TactileButton(
                          label: 'Pay',
                          onPressed: _showUnavailable,
                          backgroundColor: AppColors.terracotta,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.stackSm),
                      Expanded(
                        child: TactileButton(
                          label: 'G Pay',
                          onPressed: _showUnavailable,
                          backgroundColor: AppColors.white,
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
              const Icon(Icons.lock, size: 20, color: AppColors.terracottaDark),
              const SizedBox(width: AppSpacing.unit),
              Text(
                'Secure & Encrypted',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.terracottaDark,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _CheckoutBar(onConfirm: _showUnavailable),
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard();

  @override
  Widget build(BuildContext context) {
    return NoriCard(
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SELECTED PLAN',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.inkMuted,
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
                  color: AppColors.terracottaDark,
                ),
              ),
              Text(
                '/year',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.inkMuted),
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
          color: selected ? AppColors.mossLight : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.ink, width: AppBorder.standard),
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
                            ? AppColors.mossDark
                            : AppColors.inkMuted,
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
        color: AppColors.white,
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? AppColors.moss : Colors.transparent,
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
        fillColor: AppColors.linenAlt,
        labelStyle: AppTextStyles.labelSm.copyWith(color: AppColors.inkMuted),
        hintStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.inkFaint),
        suffixIcon: suffixIcon == null
            ? null
            : Icon(suffixIcon, color: AppColors.ink),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.stackSm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(
            color: AppColors.ink,
            width: AppBorder.standard,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(
            color: AppColors.ink,
            width: AppBorder.standard,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(
            color: AppColors.mossDark,
            width: AppBorder.standard,
          ),
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
        color: AppColors.white,
        border: const Border(
          top: BorderSide(color: AppColors.ink, width: AppBorder.standard),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.containerPaddingMobile),
          // Align (not Center) with heightFactor: 1 so this shrink-wraps to
          // its content's height — Scaffold lays bottomNavigationBar out
          // with a loose (not tight) height constraint, and a plain Center
          // expands to fill all of it, which made this bar balloon to
          // consume nearly the whole screen and starve `body` of space.
          child: Align(
            heightFactor: 1,
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
                          color: AppColors.inkMuted,
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
