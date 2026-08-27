import 'package:flutter/material.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/future_feature_banner.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  static const _categories = [
    (label: 'Hats', icon: Icons.checkroom),
    (label: 'Clothes', icon: Icons.dry_cleaning),
    (label: 'Food', icon: Icons.restaurant),
    (label: 'Furniture', icon: Icons.chair),
    (label: 'Premium', icon: Icons.diamond),
  ];

  static const _items = [
    _ShopItem(
      name: 'Wizard Hat',
      price: '350',
      icon: Icons.auto_awesome,
      color: AppColors.primaryFixed,
    ),
    _ShopItem(
      name: 'Royal Crown',
      price: '800',
      icon: Icons.emoji_events,
      color: AppColors.tertiaryFixed,
      badge: 'New',
      badgeColor: AppColors.errorContainer,
      badgeTextColor: AppColors.onErrorContainer,
    ),
    _ShopItem(
      name: 'Dino Onesie',
      price: '550',
      icon: Icons.checkroom,
      color: AppColors.secondaryContainer,
    ),
    _ShopItem(
      name: 'Propeller Beanie',
      price: '200',
      icon: Icons.toys,
      color: AppColors.tertiaryFixed,
    ),
    _ShopItem(
      name: 'Smart Glasses',
      price: 'Owned',
      icon: Icons.visibility,
      color: AppColors.surfaceContainerHigh,
      owned: true,
    ),
    _ShopItem(
      name: 'Sushi Treat',
      price: '100',
      previousPrice: '150',
      icon: Icons.restaurant,
      color: AppColors.secondaryContainer,
      badge: 'Sale',
      badgeColor: AppColors.secondaryContainer,
      badgeTextColor: AppColors.onSecondaryContainer,
    ),
  ];

  int _selectedCategory = 0;

  void _showUnavailable() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Not available yet')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pet Boutique')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;
          final horizontalPadding = isWide
              ? AppSpacing.containerPaddingDesktop
              : AppSpacing.containerPaddingMobile;
          final crossAxisCount = constraints.maxWidth >= 1050
              ? 4
              : constraints.maxWidth >= 700
              ? 3
              : 2;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.gutter,
              horizontalPadding,
              AppSpacing.stackLg,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Spoil your companion with new looks and treats!',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.stackSm),
                    const FutureFeatureBanner(),
                    const SizedBox(height: AppSpacing.stackMd),
                    const _BalanceCard(),
                    const SizedBox(height: AppSpacing.stackMd),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.stackSm),
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          return ChoiceChip(
                            avatar: Icon(category.icon, size: 18),
                            label: Text(category.label),
                            selected: _selectedCategory == index,
                            onSelected: (_) {
                              setState(() => _selectedCategory = index);
                            },
                            labelStyle: AppTextStyles.labelLg.copyWith(
                              color: _selectedCategory == index
                                  ? AppColors.onPrimary
                                  : AppColors.onSurface,
                            ),
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.surfaceContainerLowest,
                            side: BorderSide(
                              color: _selectedCategory == index
                                  ? AppColors.primary
                                  : AppColors.outlineVariant,
                            ),
                            shape: const StadiumBorder(),
                            showCheckmark: false,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppSpacing.stackMd),
                    GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: AppSpacing.gutter,
                      mainAxisSpacing: AppSpacing.gutter,
                      childAspectRatio: isWide ? 0.72 : 0.61,
                      children: [
                        for (final item in _items)
                          _ShopItemCard(
                            item: item,
                            onPressed: _showUnavailable,
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
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainerLowest,
            ),
            child: const Icon(
              Icons.monetization_on,
              color: AppColors.tertiary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AVAILABLE BALANCE',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
                Text('1,250 Coins', style: AppTextStyles.headlineMd),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  const _ShopItemCard({required this.item, required this.onPressed});

  final _ShopItem item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: item.owned ? 0.78 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.stackSm),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: item.color,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        item.icon,
                        size: 54,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  if (item.badge != null)
                    Positioned(
                      top: AppSpacing.unit,
                      left: AppSpacing.unit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.unit,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: item.badgeColor,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          item.badge!,
                          style: AppTextStyles.labelSm.copyWith(
                            color: item.badgeTextColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelLg,
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 20,
              child: item.owned
                  ? Text(
                      item.price,
                      style: AppTextStyles.labelLg.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    )
                  : Row(
                      children: [
                        if (item.previousPrice != null) ...[
                          Text(
                            item.previousPrice!,
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.error,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.unit),
                        ],
                        const Icon(
                          Icons.monetization_on,
                          color: AppColors.tertiary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.price,
                          style: AppTextStyles.labelLg.copyWith(
                            color: AppColors.tertiary,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                backgroundColor: item.owned
                    ? AppColors.surfaceContainer
                    : AppColors.primary,
                foregroundColor: item.owned
                    ? AppColors.onSurfaceVariant
                    : AppColors.onPrimary,
                textStyle: AppTextStyles.labelLg,
              ),
              child: Text(item.owned ? 'Equip' : 'Buy'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopItem {
  const _ShopItem({
    required this.name,
    required this.price,
    required this.icon,
    required this.color,
    this.previousPrice,
    this.owned = false,
    this.badge,
    this.badgeColor = AppColors.surfaceContainer,
    this.badgeTextColor = AppColors.onSurfaceVariant,
  });

  final String name;
  final String price;
  final String? previousPrice;
  final IconData icon;
  final Color color;
  final bool owned;
  final String? badge;
  final Color badgeColor;
  final Color badgeTextColor;
}
