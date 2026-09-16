import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Which vital a [CareItem] restores — matches the three rings on Home
/// (Fed/Clean/Happy in `_RoomHud`).
enum CareCategory { hunger, hygiene, love }

/// One consumable pet-care item — shown in the Shop's Food & Care category
/// and, once owned, offered as a choice when the matching vital ring is
/// tapped on Home (see `_CareActionSheet` in home_screen.dart).
///
/// Two tiers per stat so "which item to use" is a real choice rather than a
/// single auto-applied item — the reference sheet
/// (assets/source/accessories/care_items_source.jpg) has 15 icons total (5
/// per stat); only 2 per stat are wired up so far, matching FEATURES.md §9's
/// MVP note ("a few basic care actions/items — not a full economy"). The
/// other 9 are cut-when-needed, same as the "not yet cut" accessories — see
/// that folder's README.
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
    price: 50,
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
    price: 90,
    category: CareCategory.hunger,
    restoreAmount: 45,
    grants: 3,
  ),
  CareItem(
    id: 'shampoo',
    name: 'Shampoo',
    icon: Icons.soap,
    image: 'assets/images/accessories/shampoo.png',
    color: AppColors.sky,
    price: 40,
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
    price: 70,
    category: CareCategory.hygiene,
    restoreAmount: 45,
    grants: 3,
  ),
  CareItem(
    id: 'plushie',
    name: 'Plushie',
    icon: Icons.sports_baseball,
    image: 'assets/images/accessories/plushie.png',
    color: AppColors.mustardLight,
    price: 60,
    category: CareCategory.love,
    restoreAmount: 20,
    grants: 3,
  ),
  CareItem(
    id: 'blanket',
    name: 'Blanket',
    icon: Icons.bed,
    image: 'assets/images/accessories/blanket.png',
    color: AppColors.mustardLight,
    price: 100,
    category: CareCategory.love,
    restoreAmount: 40,
    grants: 3,
  ),
];

List<CareItem> careItemsForCategory(CareCategory category) =>
    kCareItemCatalog.where((item) => item.category == category).toList();
