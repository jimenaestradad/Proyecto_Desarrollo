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
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final int price;
}

/// MVP set: three basic accessories. Prices are INFERRED placeholders, same
/// tier as the app's other mock economy numbers — see docs/OPEN_DECISIONS.md
/// "Economy" (shop item prices are explicitly undecided).
const List<AccessoryItem> kAccessoryCatalog = [
  AccessoryItem(
    id: 'wizard-hat',
    name: 'Wizard Hat',
    icon: Icons.auto_awesome,
    color: AppColors.mossLight,
    price: 350,
  ),
  AccessoryItem(
    id: 'propeller-beanie',
    name: 'Propeller Beanie',
    icon: Icons.toys,
    color: AppColors.mustardLight,
    price: 200,
  ),
  AccessoryItem(
    id: 'smart-glasses',
    name: 'Smart Glasses',
    icon: Icons.visibility,
    color: AppColors.linen,
    price: 150,
  ),
];

AccessoryItem accessoryById(String id) =>
    kAccessoryCatalog.firstWhere((item) => item.id == id);
