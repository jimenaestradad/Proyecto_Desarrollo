import 'package:flutter/material.dart';

import '../data/accessory_catalog.dart';
import '../theme/app_theme.dart';

/// A small worn-accessory badge shown near Nori's head wherever the pet is
/// rendered (Customization preview, Home room).
///
/// Accessories in this app are catalog entries with just an icon + color
/// (see accessory_catalog.dart) — there's no illustrated art layer drawn to
/// fit onto the photographed/filmed sprite, so equipping can't literally
/// place a hat or headphones onto Nori's actual head. This badge is the
/// equip-feedback stand-in: the accessory's own icon in a small circle,
/// pinned where a real accessory would sit, so equipping something in
/// Customization actually shows up as "on" wherever Nori appears instead of
/// silently doing nothing.
class AccessoryBadge extends StatelessWidget {
  const AccessoryBadge({super.key, required this.item, this.size = 36});

  final AccessoryItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: item.color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: AppBorder.standard),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.25),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(item.icon, size: size * 0.56, color: AppColors.mossDark),
    );
  }
}
