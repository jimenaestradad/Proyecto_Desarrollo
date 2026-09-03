import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// User avatar. Renders [imageUrl] once profile photos exist server-side;
/// today every repository returns `null`, so this always shows the
/// placeholder glyph.
class NoriAvatar extends StatelessWidget {
  const NoriAvatar({
    super.key,
    this.imageUrl,
    this.size = 40,
    this.borderWidth = AppBorder.thick,
  });

  final String? imageUrl;
  final double size;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.blush,
        border: Border.all(color: AppColors.ink, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null
          ? Image.network(imageUrl!, fit: BoxFit.cover)
          : Icon(Icons.person, size: size * 0.55, color: AppColors.terracottaDark),
    );
  }
}
