import 'package:flutter/material.dart';
import 'package:nori/data/accessory_catalog.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/care_item_catalog.dart';
import 'package:nori/data/cloud_functions_client.dart';
import 'package:nori/models/inventory.dart';
import 'package:nori/models/nori_user.dart';
import 'package:nori/models/pet.dart';
import 'package:nori/utils/ordered_queue.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/accessory_art.dart';
import 'package:nori/screens/customization/customization_screen.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/formatting.dart';
import 'package:nori/widgets/future_feature_banner.dart';
import 'package:nori/widgets/load_error_view.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import '../../widgets/scroll_edge_fade.dart';

class _PreviewItem {
  const _PreviewItem({
    required this.name,
    required this.icon,
    required this.color,
    required this.category,
    required this.price,
    this.image,
    this.badge,
    this.badgeColor = AppColors.linenAlt,
    this.badgeTextColor = AppColors.inkMuted,
  });

  final String name;
  final IconData icon;
  final Color color;
  final int category;
  final String price;

  /// Hand-drawn cutout shown instead of [icon] when set.
  final String? image;
  final String? badge;
  final Color badgeColor;
  final Color badgeTextColor;
}

class ShopScreen extends StatefulWidget {
  /// Opens on Food & care, the first chip; the Wardrobe's "go shopping" link
  /// passes [startOnAccessories] so it lands on the looks instead.
  const ShopScreen({super.key, this.startOnAccessories = false});

  final bool startOnAccessories;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with RemoteLoadState<ShopScreen> {
  // Chip order: consumables first, then looks, then the rest.
  static const _categories = [
    (label: 'Food & care', icon: Icons.restaurant),
    (label: 'Accessories', icon: Icons.checkroom),
    (label: 'Clothes', icon: Icons.dry_cleaning),
    (label: 'Furniture', icon: Icons.chair),
    (label: 'Premium', icon: Icons.diamond),
  ];

  static const _foodCategory = 0;
  static const _hatsCategory = 1;

  static const _previewItems = [
    _PreviewItem(
      name: 'Royal Crown',
      icon: Icons.emoji_events,
      color: AppColors.mustardLight,
      category: 4,
      price: '800',
      image: 'assets/images/accessories/royal-crown.png',
      badge: 'New',
      badgeColor: AppColors.errorContainer,
      badgeTextColor: AppColors.onErrorContainer,
    ),
  ];

  late int _selectedCategory = widget.startOnAccessories
      ? _hatsCategory
      : _foodCategory;
  NoriUser? _user;
  Inventory? _inventory;

  /// Which form the Shop's accessory previews draw. Stays baby until the pet
  /// loads, and keeps the last known stage if a later read fails.
  PetEvolutionStage _stage = PetEvolutionStage.baby;

  /// Purchases and equips still waiting on the server; the screen re-syncs
  /// once the last one lands (or any one fails).
  int _pending = 0;

  /// Coins and inventory as they were before the first change now in flight.
  /// A failed call puts these back at once, so the undo doesn't depend on the
  /// re-read below (which fails too when the server is unreachable). Dropped
  /// once nothing is in flight.
  (NoriUser, Inventory)? _baseline;

  void _saveBaseline() {
    final user = _user;
    final inventory = _inventory;
    if (_pending == 0 && user != null && inventory != null) {
      _baseline = (user, inventory);
    }
  }

  /// Ends one change: on failure restores the baseline, and clears it once
  /// nothing is in flight.
  void _settle({required bool ok}) {
    _pending--;
    final baseline = _baseline;
    if (_pending == 0) _baseline = null;
    if (ok || baseline == null || !mounted) return;
    setState(() {
      _user = baseline.$1;
      _inventory = baseline.$2;
    });
  }

  /// Bumps with every local change, so a fetch that began before one is
  /// dropped instead of undoing it.
  int _edits = 0;

  /// Server calls run one after another, so equipping an accessory that was
  /// just bought waits for the purchase to land.
  final _serverQueue = OrderedQueue();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() => guardedLoad(_reloadData, hasData: _user != null);

  Future<void> _reloadData() async {
    final stamp = _edits;
    final (user, inventory, stage) = await (
      AppData.user.getCurrentUser(),
      AppData.inventory.getInventory(),
      // Only picks the preview art, so a failed read must not fail the Shop.
      AppData.pet.getPet().then<PetEvolutionStage?>(
        (pet) => pet.stage,
        onError: (_) => null,
      ),
    ).wait;
    if (!mounted || stamp != _edits) return;
    setState(() {
      _user = user;
      _inventory = inventory;
      _stage = stage ?? _stage;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showUnavailable() => _showSnack('Not available yet');

  // Purchases call Cloud Functions to spend coins and grant owned items.
  // The real user/inventory repositories reject these currency-affecting writes.

  /// Shows a purchase at once (coins down, item added, confirmation) and runs
  /// [call] in the background. A failure or the last purchase finishing
  /// re-syncs coins and inventory from the server.
  Future<void> _buy({
    required int price,
    required Inventory Function(Inventory) grant,
    required Future<void> Function() call,
    required String message,
  }) async {
    final user = _user;
    final inventory = _inventory;
    if (user == null || inventory == null) return;
    if (user.coins < price) {
      _showSnack('Not enough coins.');
      return;
    }
    _edits++;
    _saveBaseline();
    _pending++;
    setState(() {
      _user = user.copyWith(coins: user.coins - price);
      _inventory = grant(inventory);
    });
    _showSnack(message);
    final ok = await guardedAction(() => _serverQueue.run(call));
    _settle(ok: ok);
    if (mounted && (!ok || _pending == 0)) await guardedAction(_reloadData);
  }

  Future<void> _buyCareItem(CareItem item) => _buy(
    price: item.price,
    grant: (inventory) => inventory.copyWith(
      careItemCounts: {
        ...inventory.careItemCounts,
        item.id: inventory.countOf(item.id) + item.grants,
      },
    ),
    call: () => callCloudFunction('purchaseCareItem', {
      'itemId': item.id,
      'quantity': 1,
    }),
    message: 'Bought ${item.name} — head to Home to use it!',
  );

  Future<void> _buyAccessory(AccessoryItem item) => _buy(
    price: item.price,
    grant: (inventory) => inventory.copyWith(
      ownedAccessoryIds: {...inventory.ownedAccessoryIds, item.id},
    ),
    call: () =>
        callCloudFunction('purchaseAccessory', {'accessoryId': item.id}),
    message: 'Bought ${item.name}!',
  );

  /// Equips [item], or takes it off if it is already worn, right on the
  /// card. The card flips at once; a failed save re-reads the inventory.
  Future<void> _toggleEquip(AccessoryItem item) async {
    final inventory = _inventory;
    if (inventory == null) return;
    final accessoryId = inventory.equippedAccessoryId == item.id
        ? null
        : item.id;
    _edits++;
    _saveBaseline();
    _pending++;
    setState(() {
      _inventory = inventory.copyWith(equippedAccessoryId: accessoryId);
    });
    final ok = await guardedAction(
      () => _serverQueue.run(
        () => AppData.inventory.setEquippedAccessory(accessoryId),
      ),
    );
    _settle(ok: ok);
    if (mounted && !ok) await guardedAction(_reloadData);
  }

  Future<void> _openCustomization() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomizationScreen(openedFromShop: true),
      ),
    );
    if (mounted) await guardedAction(_reloadData);
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final inventory = _inventory;
    final error = loadError;

    return Scaffold(
      backgroundColor: AppColors.linen,
      body: SafeArea(
        child: user == null || inventory == null
            ? error != null
                  ? LoadErrorView(error: error, onRetry: _loadData)
                  : const Center(child: CircularProgressIndicator())
            : NoriScrollScaffold(
                maxWidth: 1120,
                children: [
                  NoriScreenHeader(
                    leading: NoriScreenHeader.backButton(context),
                    title: 'Shop',
                    titleStyle: AppTextStyles.headlineLgMobile,
                    trailing: TextButton.icon(
                      onPressed: _openCustomization,
                      icon: const Icon(Icons.checkroom),
                      label: const Text('Wardrobe'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                  Text(
                    'Spend your coins on looks and treats for Nori.',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                  _BalanceCard(coins: user.coins),
                  const SizedBox(height: AppSpacing.stackMd),
                  SizedBox(
                    height: 44,
                    child: ScrollEdgeFade(
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
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                  _buildGrid(inventory, user.coins),
                ],
              ),
      ),
    );
  }

  Widget _buildGrid(Inventory inventory, int coins) {
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
              evolved: _stage != PetEvolutionStage.baby,
              coins: coins,
              owned: inventory.ownedAccessoryIds.contains(item.id),
              equipped: inventory.equippedAccessoryId == item.id,
              onBuy: () => _buyAccessory(item),
              onEquip: () => _toggleEquip(item),
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
            _CareItemCard(
              item: item,
              coins: coins,
              onBuy: () => _buyCareItem(item),
            ),
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
                Text('$formatted coins', style: AppTextStyles.headlineMd),
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
    this.worn = false,
    this.secondary = false,
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

  /// The accessory Nori is wearing: green card, thicker border.
  final bool worn;

  /// A white button for an action on something you already own (Equip),
  /// so it doesn't read as the green "spend coins" Buy button.
  final bool secondary;

  /// When set, replaces the flat [image]/[icon] with a live render sized to
  /// whatever height this card's image area actually gets (see
  /// [NoriAccessoryPreview]) -- used by [_AccessoryCard] so the shopper
  /// sees the item on Nori himself instead of a disconnected cutout icon.
  final Widget Function(double height)? previewBuilder;

  @override
  Widget build(BuildContext context) {
    return NoriCard(
      color: worn ? AppColors.mossLight : AppColors.white,
      borderWidth: worn ? AppBorder.thick : AppBorder.standard,
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
              backgroundColor: secondary ? AppColors.white : AppColors.moss,
              foregroundColor: AppColors.ink,
              // Set explicitly: the app theme gives FilledButtons a moss
              // background in every state, so "Need 45 more" stayed green.
              disabledBackgroundColor: AppColors.linenAlt,
              disabledForegroundColor: AppColors.inkFaint,
              textStyle: AppTextStyles.labelLg,
              elevation: 0,
              side: BorderSide(
                color: onPressed == null ? AppColors.inkFaint : AppColors.ink,
                width: AppBorder.standard,
              ),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.price, this.affordable = true});

  final int price;

  /// False turns the price red: you can't buy this yet.
  final bool affordable;

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
          style: AppTextStyles.labelLg.copyWith(
            color: affordable ? AppColors.mustardDark : AppColors.error,
          ),
        ),
      ],
    );
  }
}

/// Small status pill ("Owned", "Wearing") shown in a card's price row.
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.unit,
          vertical: 1,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.ink, width: AppBorder.thin),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSm.copyWith(color: textColor),
        ),
      ),
    );
  }
}

/// Button label for something you can't afford yet.
String _needMore(int price, int coins) => 'Need ${price - coins} more';

class _AccessoryCard extends StatelessWidget {
  const _AccessoryCard({
    required this.item,
    required this.evolved,
    required this.coins,
    required this.owned,
    required this.equipped,
    required this.onBuy,
    required this.onEquip,
  });

  final AccessoryItem item;

  /// Draw the preview on the evolved pet instead of the baby.
  final bool evolved;
  final int coins;
  final bool owned;
  final bool equipped;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  @override
  Widget build(BuildContext context) {
    final affordable = coins >= item.price;
    return _ItemCardShell(
      icon: item.icon,
      color: item.color,
      name: item.name,
      worn: equipped,
      secondary: owned,
      previewBuilder: (height) =>
          NoriAccessoryPreview(height: height, item: item, evolved: evolved),
      // Owned items need no price, so the status pill takes the price row
      // instead of sitting on top of the item's picture.
      priceLabel: owned
          ? _StatusPill(
              label: equipped ? 'Wearing' : 'Owned',
              color: equipped ? AppColors.mossDark : AppColors.mossLight,
              textColor: equipped ? AppColors.white : AppColors.mossDark,
            )
          : _PriceRow(price: item.price, affordable: affordable),
      buttonLabel: owned
          ? (equipped ? 'Take off' : 'Equip')
          : affordable
          ? 'Buy'
          : _needMore(item.price, coins),
      onPressed: owned
          ? onEquip
          : affordable
          ? onBuy
          : null,
    );
  }
}

class _CareItemCard extends StatelessWidget {
  const _CareItemCard({
    required this.item,
    required this.coins,
    required this.onBuy,
  });

  final CareItem item;
  final int coins;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final affordable = coins >= item.price;
    return _ItemCardShell(
      icon: item.icon,
      image: item.image,
      color: item.color,
      name: item.name,
      // Names the stat the item refills; the tile colour is that stat's
      // ring colour on Home.
      badge: item.category.statLabel,
      badgeColor: AppColors.white,
      badgeTextColor: AppColors.ink,
      priceLabel: _PriceRow(price: item.price, affordable: affordable),
      buttonLabel: affordable
          ? 'Buy · +${item.grants}'
          : _needMore(item.price, coins),
      onPressed: affordable ? onBuy : null,
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
      image: item.image,
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
