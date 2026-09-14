import 'package:flutter/material.dart';
import 'package:nori/data/accessory_catalog.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/inventory.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/screens/customization/customization_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/formatting.dart';
import 'package:nori/widgets/future_feature_banner.dart';
import 'package:nori/widgets/nori_icon_badge.dart';

enum _CareEffect { snacks, soap, toys }

class _CareItem {
  const _CareItem({
    required this.name,
    required this.icon,
    required this.color,
    required this.price,
    required this.effect,
    required this.grants,
  });

  final String name;
  final IconData icon;
  final Color color;
  final int price;
  final _CareEffect effect;
  final int grants;
}

class _PreviewItem {
  const _PreviewItem({
    required this.name,
    required this.icon,
    required this.color,
    required this.category,
    required this.price,
    this.badge,
    this.badgeColor = AppColors.linenAlt,
    this.badgeTextColor = AppColors.inkMuted,
  });

  final String name;
  final IconData icon;
  final Color color;
  final int category;
  final String price;
  final String? badge;
  final Color badgeColor;
  final Color badgeTextColor;
}

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  static const _categories = [
    (label: 'Hats', icon: Icons.checkroom),
    (label: 'Clothes', icon: Icons.dry_cleaning),
    (label: 'Food & Care', icon: Icons.restaurant),
    (label: 'Furniture', icon: Icons.chair),
    (label: 'Premium', icon: Icons.diamond),
  ];

  static const _hatsCategory = 0;
  static const _foodCategory = 2;

  static const _careItems = [
    _CareItem(
      name: 'Snack Pack',
      icon: Icons.restaurant,
      color: AppColors.blush,
      price: 50,
      effect: _CareEffect.snacks,
      grants: 3,
    ),
    _CareItem(
      name: 'Soap Bar',
      icon: Icons.soap,
      color: AppColors.sky,
      price: 40,
      effect: _CareEffect.soap,
      grants: 3,
    ),
    _CareItem(
      name: 'Toy Ball',
      icon: Icons.sports_baseball,
      color: AppColors.mustardLight,
      price: 60,
      effect: _CareEffect.toys,
      grants: 3,
    ),
  ];

  static const _previewItems = [
    _PreviewItem(
      name: 'Dino Onesie',
      icon: Icons.checkroom,
      color: AppColors.blush,
      category: 1,
      price: '550',
    ),
    _PreviewItem(
      name: 'Royal Crown',
      icon: Icons.emoji_events,
      color: AppColors.mustardLight,
      category: 4,
      price: '800',
      badge: 'New',
      badgeColor: AppColors.errorContainer,
      badgeTextColor: AppColors.onErrorContainer,
    ),
  ];

  int _selectedCategory = 0;
  NoriUser? _user;
  Inventory? _inventory;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await AppData.user.getCurrentUser();
    final inventory = await AppData.inventory.getInventory();
    if (!mounted) return;
    setState(() {
      _user = user;
      _inventory = inventory;
    });
  }

  Future<void> _reloadData() async {
    final user = await AppData.user.getCurrentUser();
    final inventory = await AppData.inventory.getInventory();
    if (!mounted) return;
    setState(() {
      _user = user;
      _inventory = inventory;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showUnavailable() => _showSnack('Not available yet');

  Future<void> _buyCareItem(_CareItem item) async {
    final user = _user;
    if (user == null) return;
    if (user.coins < item.price) {
      _showSnack('Not enough coins.');
      return;
    }
    await AppData.user.addCoins(-item.price);
    switch (item.effect) {
      case _CareEffect.snacks:
        await AppData.inventory.addSnacks(item.grants);
      case _CareEffect.soap:
        await AppData.inventory.addSoap(item.grants);
      case _CareEffect.toys:
        await AppData.inventory.addToys(item.grants);
    }
    await _reloadData();
    if (!mounted) return;
    _showSnack('Bought ${item.name} — head to Home to use it!');
  }

  Future<void> _buyAccessory(AccessoryItem item) async {
    final user = _user;
    if (user == null) return;
    if (user.coins < item.price) {
      _showSnack('Not enough coins.');
      return;
    }
    await AppData.user.addCoins(-item.price);
    await AppData.inventory.addAccessory(item.id);
    await _reloadData();
    if (!mounted) return;
    _showSnack('Bought ${item.name}!');
  }

  void _openCustomization() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CustomizationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final inventory = _inventory;

    return Scaffold(
      backgroundColor: AppColors.linen,
      appBar: AppBar(title: const Text('Pet Boutique')),
      body: user == null || inventory == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 800;
                final horizontalPadding = isWide
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
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Spoil your companion with new looks and treats!',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.stackMd),
                          _BalanceCard(coins: user.coins),
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
                                  avatar: Icon(
                                    category.icon,
                                    size: 18,
                                    color: AppColors.ink,
                                  ),
                                  label: Text(category.label),
                                  selected: _selectedCategory == index,
                                  onSelected: (_) {
                                    setState(() => _selectedCategory = index);
                                  },
                                  labelStyle: AppTextStyles.labelLg.copyWith(
                                    color: AppColors.ink,
                                  ),
                                  selectedColor: AppColors.moss,
                                  backgroundColor: AppColors.white,
                                  side: const BorderSide(
                                    color: AppColors.ink,
                                    width: AppBorder.thin,
                                  ),
                                  shape: const StadiumBorder(),
                                  elevation: 0,
                                  pressElevation: 0,
                                  showCheckmark: false,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.stackMd),
                          _buildGrid(isWide, inventory),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildGrid(bool isWide, Inventory inventory) {
    final crossAxisCount = isWide ? 4 : 2;

    if (_selectedCategory == _hatsCategory) {
      return GridView.count(
        crossAxisCount: crossAxisCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSpacing.gutter,
        mainAxisSpacing: AppSpacing.gutter,
        childAspectRatio: isWide ? 0.72 : 0.61,
        children: [
          for (final item in kAccessoryCatalog)
            _AccessoryCard(
              item: item,
              owned: inventory.ownedAccessoryIds.contains(item.id),
              onBuy: () => _buyAccessory(item),
              onEquip: _openCustomization,
            ),
        ],
      );
    }

    if (_selectedCategory == _foodCategory) {
      return GridView.count(
        crossAxisCount: crossAxisCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSpacing.gutter,
        mainAxisSpacing: AppSpacing.gutter,
        childAspectRatio: isWide ? 0.72 : 0.61,
        children: [
          for (final item in _careItems)
            _CareItemCard(item: item, onBuy: () => _buyCareItem(item)),
        ],
      );
    }

    final items = _previewItems
        .where((item) => item.category == _selectedCategory)
        .toList(growable: false);
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.stackLg),
        child: FutureFeatureBanner(
          message: 'More items are coming to this category soon.',
        ),
      );
    }
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.gutter,
      mainAxisSpacing: AppSpacing.gutter,
      childAspectRatio: isWide ? 0.72 : 0.61,
      children: [
        for (final item in items)
          _PreviewItemCard(item: item, onPressed: _showUnavailable),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    final formatted = formatThousands(coins);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: BoxDecoration(
        color: AppColors.mustardLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppBorder.standard),
      ),
      child: Row(
        children: [
          const NoriIconBadge(
            icon: Icons.monetization_on,
            background: AppColors.white,
            size: 44,
            circle: true,
            iconSize: 28,
            iconColor: AppColors.mustardDark,
          ),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AVAILABLE BALANCE',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.inkMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                Text('$formatted Coins', style: AppTextStyles.headlineMd),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCardShell extends StatelessWidget {
  const _ItemCardShell({
    required this.icon,
    required this.color,
    required this.name,
    required this.priceLabel,
    required this.buttonLabel,
    required this.onPressed,
    this.badge,
    this.badgeColor = AppColors.linenAlt,
    this.badgeTextColor = AppColors.inkMuted,
    this.dimmed = false,
  });

  final IconData icon;
  final Color color;
  final String name;
  final Widget priceLabel;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final String? badge;
  final Color badgeColor;
  final Color badgeTextColor;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.78 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.stackSm),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.ink, width: AppBorder.standard),
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
                        color: color,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: AppColors.ink,
                          width: AppBorder.thin,
                        ),
                      ),
                      child: Icon(icon, size: 54, color: AppColors.ink),
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      top: AppSpacing.unit,
                      left: AppSpacing.unit,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.unit,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: AppColors.ink,
                            width: AppBorder.thin,
                          ),
                        ),
                        child: Text(
                          badge!,
                          style: AppTextStyles.labelSm.copyWith(
                            color: badgeTextColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelLg,
            ),
            const SizedBox(height: 4),
            SizedBox(height: 20, child: priceLabel),
            const SizedBox(height: AppSpacing.stackSm),
            FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                backgroundColor: onPressed == null
                    ? AppColors.linenAlt
                    : AppColors.moss,
                foregroundColor: onPressed == null
                    ? AppColors.inkMuted
                    : AppColors.ink,
                textStyle: AppTextStyles.labelLg,
                elevation: 0,
                side: const BorderSide(
                  color: AppColors.ink,
                  width: AppBorder.standard,
                ),
              ),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.price});

  final int price;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.monetization_on, color: AppColors.mustardDark, size: 16),
        const SizedBox(width: 4),
        Text(
          '$price',
          style: AppTextStyles.labelLg.copyWith(color: AppColors.mustardDark),
        ),
      ],
    );
  }
}

class _AccessoryCard extends StatelessWidget {
  const _AccessoryCard({
    required this.item,
    required this.owned,
    required this.onBuy,
    required this.onEquip,
  });

  final AccessoryItem item;
  final bool owned;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    return _ItemCardShell(
      icon: item.icon,
      color: item.color,
      name: item.name,
      dimmed: owned,
      priceLabel: owned
          ? Text('Owned', style: AppTextStyles.labelLg.copyWith(color: AppColors.inkMuted))
          : _PriceRow(price: item.price),
      buttonLabel: owned ? 'Equip' : 'Buy',
      onPressed: owned ? onEquip : onBuy,
    );
  }
}

class _CareItemCard extends StatelessWidget {
  const _CareItemCard({required this.item, required this.onBuy});

  final _CareItem item;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return _ItemCardShell(
      icon: item.icon,
      color: item.color,
      name: item.name,
      priceLabel: _PriceRow(price: item.price),
      buttonLabel: 'Buy · +${item.grants}',
      onPressed: onBuy,
    );
  }
}

class _PreviewItemCard extends StatelessWidget {
  const _PreviewItemCard({required this.item, required this.onPressed});

  final _PreviewItem item;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _ItemCardShell(
      icon: item.icon,
      color: item.color,
      name: item.name,
      badge: item.badge,
      badgeColor: item.badgeColor,
      badgeTextColor: item.badgeTextColor,
      priceLabel: Row(
        children: [
          const Icon(Icons.monetization_on, color: AppColors.mustardDark, size: 16),
          const SizedBox(width: 4),
          Text(item.price, style: AppTextStyles.labelLg.copyWith(color: AppColors.mustardDark)),
        ],
      ),
      buttonLabel: 'Buy',
      onPressed: onPressed,
    );
  }
}
