import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// One purchasable, equippable cosmetic. Shared between the Shop (buying)
/// and Customization (equipping) screens so both read the same item data
/// instead of maintaining two lists that can drift apart.
class AccessoryItem {
  const AccessoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.price,
    this.image,
    this.wornImage,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final int price;

  /// Hand-drawn cutout used throughout the UI; [wornImage] can override it on Nori.
  /// [icon] is the fallback when no cutout is available.
  final String? image;

  /// Overrides [image] only when worn on Nori; shop and equip grids keep [image].
  /// The tail charm uses a smaller ring-and-leaf cutout when worn.
  final String? wornImage;
}

/// Hand-drawn accessories from assets/source/accessories/; see its README.
/// Prices from the 2026-11-07 economy pass (OPEN_DECISIONS.md, "Economy"):
/// the five buyable pieces run 100-500 coins. Sunglasses are the free gift for
/// a first completed habit, so their price only matters before that.
const List<AccessoryItem> kAccessoryCatalog = [
  AccessoryItem(
    id: 'flower-crown',
    name: 'Flower Crown',
    icon: Icons.local_florist,
    color: AppColors.blush,
    price: 500,
    image: 'assets/images/accessories/flower-crown.png',
  ),
  AccessoryItem(
    id: 'horn-bow',
    name: 'Horn Bow',
    icon: Icons.emoji_nature,
    color: AppColors.blush,
    price: 180,
    image: 'assets/images/accessories/horn-bow.png',
  ),
  AccessoryItem(
    id: 'sunglasses',
    name: 'Sunglasses',
    icon: Icons.wb_sunny,
    color: AppColors.mustardLight,
    price: 140,
    image: 'assets/images/accessories/sunglasses.png',
  ),
  AccessoryItem(
    id: 'steampunk-goggles',
    name: 'Steampunk Goggles',
    icon: Icons.visibility,
    color: AppColors.linen,
    price: 350,
    image: 'assets/images/accessories/steampunk-goggles.png',
  ),
  AccessoryItem(
    id: 'chef-hat',
    name: 'Chef Hat',
    icon: Icons.checkroom,
    color: AppColors.linen,
    price: 250,
    image: 'assets/images/accessories/chef-hat.png',
  ),
  AccessoryItem(
    id: 'tail-charm-clasp',
    name: 'Tail Charm Clasp',
    icon: Icons.eco,
    color: AppColors.mossLight,
    price: 100,
    image: 'assets/images/accessories/tail-charm-clasp.png',
    wornImage: 'assets/images/accessories/tail-charm-clasp-worn.png',
  ),
];

/// Null if [id] doesn't match any entry — e.g. a stored id from an accessory
/// that's since been removed from the catalog.
AccessoryItem? accessoryById(String id) {
  for (final item in kAccessoryCatalog) {
    if (item.id == id) return item;
  }
  return null;
}
