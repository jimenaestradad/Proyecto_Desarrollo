import 'package:flutter/material.dart';
import 'package:nori/data/accessory_catalog.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/care_item_catalog.dart';
import 'package:nori/data/cloud_functions_client.dart';
import 'package:nori/models/inventory.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/widgets/accessory_art.dart';
import 'package:nori/screens/customization/customization_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/formatting.dart';
import 'package:nori/widgets/future_feature_banner.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';

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
  bool _isPurchasing = false;

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

  // purchaseCareItem/purchaseAccessory are Cloud-Function-only (see
  // docs/BACKEND.md's Architecture table: buying spends coins to mint an
  // owned item, which is exactly the currency-affecting write the
  // Cloud-Functions boundary exists to guard) -- AppData.user.addCoins and
  // AppData.inventory.addCareItem/addAccessory would just throw
  // UnsupportedError against the real Firestore-backed repositories now
  // that AppData.bindToUser wires them up, so these call the callable
  // directly through cloud_functions_client.dart's shared helper instead
  // of going through the repository interfaces for this one write.

  Future<void> _buyCareItem(CareItem item) async {
    if (_isPurchasing) return;
    _isPurchasing = true;
    try {
      final user = _user;
      if (user == null) return;
      if (user.coins < item.price) {
        _showSnack('Not enough coins.');
        return;
      }
      try {
        await callCloudFunction('purchaseCareItem', {
          'itemId': item.id,
          'quantity': 1,
        });
      } on CloudFunctionFailure catch (e) {
        if (!mounted) return;
        _showSnack(e.message);
        return;
      }
      await _reloadData();
      if (!mounted) return;
      _showSnack('Bought ${item.name} — head to Home to use it!');
    } finally {
      _isPurchasing = false;
    }
  }

  Future<void> _buyAccessory(AccessoryItem item) async {
    if (_isPurchasing) return;
    _isPurchasing = true;
    try {
      final user = _user;
      if (user == null) return;
      if (user.coins < item.price) {
        _showSnack('Not enough coins.');
        return;
      }
      try {
        await callCloudFunction('purchaseAccessory', {'accessoryId': item.id});
      } on CloudFunctionFailure catch (e) {
        if (!mounted) return;
        _showSnack(e.message);
        return;
      }
      await _reloadData();
      if (!mounted) return;
      _showSnack('Bought ${item.name}!');
    } finally {
      _isPurchasing = false;
    }
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
          : NoriScrollScaffold(
              maxWidth: 1120,
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
                _buildGrid(inventory),
              ],
            ),
    );
  }

  Widget _buildGrid(Inventory inventory) {
    if (_selectedCategory == _hatsCategory) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSpacing.gutter,
        mainAxisSpacing: AppSpacing.gutter,
        childAspectRatio: 0.61,
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
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSpacing.gutter,
        mainAxisSpacing: AppSpacing.gutter,
        childAspectRatio: 0.61,
        children: [
          for (final item in kCareItemCatalog)
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
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.gutter,
      mainAxisSpacing: AppSpacing.gutter,
      childAspectRatio: 0.61,
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
    return NoriCard(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      color: AppColors.mustardLight,
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
    this.image,
    this.previewBuilder,
    this.badge,
    this.badgeColor = AppColors.linenAlt,
    this.badgeTextColor = AppColors.inkMuted,
    this.dimmed = false,
  });

  final IconData icon;
  final String? image;
  final Color color;
  final String name;
  final Widget priceLabel;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final String? badge;
  final Color badgeColor;
  final Color badgeTextColor;
  final bool dimmed;

  /// When set, replaces the flat [image]/[icon] with a live render sized to
  /// whatever height this card's image area actually gets (see
  /// [NoriAccessoryPreview]) -- used by [_AccessoryCard] so the shopper
  /// sees the item on Nori himself instead of a disconnected cutout icon.
  final Widget Function(double height)? previewBuilder;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.78 : 1,
      child: NoriCard(
        padding: const EdgeInsets.all(AppSpacing.stackSm),
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
                      child: previewBuilder != null
                          ? Padding(
                              padding: const EdgeInsets.all(AppSpacing.unit),
                              child: LayoutBuilder(
                                builder: (context, inner) => Center(
                                  child: previewBuilder!(inner.maxHeight),
                                ),
                              ),
                            )
                          : image != null
                          ? Padding(
                              padding: const EdgeInsets.all(AppSpacing.stackSm),
                              child: Image.asset(image!, fit: BoxFit.contain),
                            )
                          : Icon(icon, size: 54, color: AppColors.ink),
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
        const Icon(
          Icons.monetization_on,
          color: AppColors.mustardDark,
          size: 16,
        ),
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
      previewBuilder: (height) =>
          NoriAccessoryPreview(height: height, item: item),
      priceLabel: owned
          ? Text(
              'Owned',
              style: AppTextStyles.labelLg.copyWith(color: AppColors.inkMuted),
            )
          : _PriceRow(price: item.price),
      buttonLabel: owned ? 'Equip' : 'Buy',
      onPressed: owned ? onEquip : onBuy,
    );
  }
}

class _CareItemCard extends StatelessWidget {
  const _CareItemCard({required this.item, required this.onBuy});

  final CareItem item;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return _ItemCardShell(
      icon: item.icon,
      image: item.image,
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
          const Icon(
            Icons.monetization_on,
            color: AppColors.mustardDark,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            item.price,
            style: AppTextStyles.labelLg.copyWith(color: AppColors.mustardDark),
          ),
        ],
      ),
      buttonLabel: 'Buy',
      onPressed: onPressed,
    );
  }
}
