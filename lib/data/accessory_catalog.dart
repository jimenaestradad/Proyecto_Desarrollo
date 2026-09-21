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

  /// Hand-drawn cutout asset path (e.g. 'assets/images/accessories/foo.png'),
  /// cut from Jimena's reference sheets in assets/source/. When set, this
  /// replaces [icon] everywhere the accessory is drawn — in the shop grid,
  /// the equip grid, and (unless [wornImage] overrides it) worn on Nori (see
  /// accessory_art.dart) — [icon] stays as a fallback only for accessories
  /// that don't have real art yet.
  final String? image;

  /// Overrides [image] only for the on-Nori render (AccessoryArt) — the shop
  /// card and equip-grid slot always show [image]. Most items only have one
  /// cutout, so this is null for them. `tail-charm-clasp` is the one
  /// exception found so far: its reference sheet's bold "display" cutout (a
  /// full lobster clasp + chain, [image]) is what reads well as a small shop
  /// icon, but the sheet's "worn on Nori" figure shows the clasp tucked out
  /// of sight — just a small ring and the leaf charm dangling from it. See
  /// assets/source/accessories/README.md.
  final String? wornImage;
}

/// Every entry is a hand-drawn cutout from Jimena's reference sheets
/// (assets/source/accessories/ — see that folder's README entry for which
/// sheet each one came from) — see accessory_art.dart for how these render
/// worn. Prices are INFERRED placeholders, same tier as the app's
/// other mock economy numbers — see docs/OPEN_DECISIONS.md "Economy" (shop
/// item prices are explicitly undecided).
///
/// Earlier MVP placeholders (wizard hat, propeller beanie, smart glasses,
/// cozy headphones) had no real art behind them — generic Material icons in
/// a flat color swatch — and were dropped once real accessories existed to
/// replace them, rather than kept alongside real art. Flower Crown kept its
/// id/price but swapped its placeholder painter for the real cutout below.
const List<AccessoryItem> kAccessoryCatalog = [
  AccessoryItem(
    id: 'flower-crown',
    name: 'Flower Crown',
    icon: Icons.local_florist,
    color: AppColors.blush,
    price: 180,
    image: 'assets/images/accessories/flower-crown.png',
  ),
  AccessoryItem(
    id: 'horn-bow',
    name: 'Horn Bow',
    icon: Icons.emoji_nature,
    color: AppColors.blush,
    price: 120,
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
    price: 180,
    image: 'assets/images/accessories/steampunk-goggles.png',
  ),
  AccessoryItem(
    id: 'chef-hat',
    name: 'Chef Hat',
    icon: Icons.checkroom,
    color: AppColors.linen,
    price: 160,
    image: 'assets/images/accessories/chef-hat.png',
  ),
  AccessoryItem(
    id: 'tail-charm-clasp',
    name: 'Tail Charm Clasp',
    icon: Icons.eco,
    color: AppColors.mossLight,
    price: 130,
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
