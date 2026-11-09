import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Which vital a [CareItem] restores — matches the three rings on Home
/// (Fed/Clean/Happy in `_RoomHud`).
enum CareCategory { hunger, hygiene, love }

/// How a stat is named and coloured everywhere it appears. The colour is the
/// one on Home's vital ring, so a shop tile matches the ring it refills.
extension CareCategoryStyle on CareCategory {
  String get statLabel => switch (this) {
    CareCategory.hunger => 'Fullness',
    CareCategory.hygiene => 'Hygiene',
    CareCategory.love => 'Happiness',
  };

  Color get statColor => switch (this) {
    CareCategory.hunger => AppColors.terracotta,
    CareCategory.hygiene => AppColors.skyBlue,
    CareCategory.love => AppColors.moss,
  };
}

/// Consumable pet-care item sold in Shop and selected from Home's vital rings.
/// Two tiers per stat provide a choice within the MVP's basic care economy.
class CareItem {
  const CareItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.price,
    required this.category,
    required this.restoreAmount,
    required this.grants,
    this.image,
  });

  final String id;
  final String name;
  final IconData icon;
  final String? image;
  final int price;
  final CareCategory category;

  /// Tile colour: the ring colour of the stat this item refills.
  Color get color => category.statColor;

  /// Points the matching vital recovers per use. Pricier items restore
  /// more — an INFERRED rule (valevasqc's own suggestion, not a tuned
  /// balance decision); see docs/product/OPEN_DECISIONS.md "Economy".
  final double restoreAmount;

  /// Uses granted per purchase.
  final int grants;
}

const List<CareItem> kCareItemCatalog = [
  CareItem(
    id: 'food',
    name: 'Food',
    icon: Icons.restaurant,
    image: 'assets/images/accessories/food.png',
    price: 10,
    category: CareCategory.hunger,
    restoreAmount: 25,
    grants: 3,
  ),
  CareItem(
    id: 'cake',
    name: 'Cake',
    icon: Icons.cake,
    image: 'assets/images/accessories/cake.png',
    price: 18,
    category: CareCategory.hunger,
    restoreAmount: 50,
    grants: 3,
  ),
  CareItem(
    id: 'shampoo',
    name: 'Shampoo',
    icon: Icons.soap,
    image: 'assets/images/accessories/shampoo.png',
    price: 10,
    category: CareCategory.hygiene,
    restoreAmount: 25,
    grants: 3,
  ),
  CareItem(
    id: 'hair-brush',
    name: 'Hair Brush',
    icon: Icons.brush,
    image: 'assets/images/accessories/hair-brush.png',
    price: 18,
    category: CareCategory.hygiene,
    restoreAmount: 50,
    grants: 3,
  ),
  CareItem(
    id: 'plushie',
    name: 'Plushie',
    icon: Icons.sports_baseball,
    image: 'assets/images/accessories/plushie.png',
    price: 10,
    category: CareCategory.love,
    restoreAmount: 25,
    grants: 3,
  ),
  CareItem(
    id: 'blanket',
    name: 'Blanket',
    icon: Icons.bed,
    image: 'assets/images/accessories/blanket.png',
    price: 18,
    category: CareCategory.love,
    restoreAmount: 50,
    grants: 3,
  ),
];

List<CareItem> careItemsForCategory(CareCategory category) =>
    kCareItemCatalog.where((item) => item.category == category).toList();
