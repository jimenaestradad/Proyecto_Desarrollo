import 'package:flutter/material.dart';

/// An [icon] that turns into a tiny spinner while [syncing], so a total
/// (XP, coins) that is still waiting on the server shows it is on its way.
class SyncingIcon extends StatelessWidget {
  const SyncingIcon({
    super.key,
    required this.icon,
    required this.size,
    required this.color,
    required this.syncing,
  });

  final IconData icon;
  final double size;
  final Color color;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: syncing
          ? Padding(
              padding: EdgeInsets.all(size * 0.15),
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(icon, size: size, color: color),
    );
  }
}
