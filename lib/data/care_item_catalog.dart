import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Which vital a [CareItem] restores — matches the three rings on Home
/// (Fed/Clean/Happy in `_RoomHud`).
enum CareCategory { hunger, hygiene, love }

/// Consumable pet-care item sold in Shop and selected from Home's vital rings.
/// Two tiers per stat provide a choice within the MVP's basic care economy.
class CareItem {
  const CareItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
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
  final Color color;
  final int price;
  final CareCategory category;

  /// Points the matching vital recovers per use. Pricier items restore
  /// more — an INFERRED rule (valevasqc's own suggestion, not a tuned
  /// balance decision); see docs/OPEN_DECISIONS.md "Economy".
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
    color: AppColors.blush,
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
    color: AppColors.blush,
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
    color: AppColors.sky,
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
    color: AppColors.sky,
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
    color: AppColors.mustardLight,
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
    color: AppColors.mustardLight,
    price: 18,
    category: CareCategory.love,
    restoreAmount: 50,
    grants: 3,
  ),
];

List<CareItem> careItemsForCategory(CareCategory category) =>
    kCareItemCatalog.where((item) => item.category == category).toList();
