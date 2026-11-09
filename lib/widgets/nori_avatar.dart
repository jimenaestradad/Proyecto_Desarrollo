import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../data/session_photos.dart';
import '../theme/app_theme.dart';

/// Renders [imageUrl], falling back to default art for the signed-in user.
/// For mock people, [imageAsset] (a bundled photo) wins when set; otherwise
/// [name] selects deterministic initials and color.
class NoriAvatar extends StatelessWidget {
  const NoriAvatar({
    super.key,
    this.imageUrl,
    this.imageAsset,
    this.name,
    this.size = 40,
    this.borderWidth = AppBorder.thick,
  });

  final String? imageUrl;
  final String? imageAsset;
  final String? name;
  final double size;
  final double borderWidth;

  static const _palette = [
    AppColors.mossLight,
    AppColors.blushPink,
    AppColors.mustardLight,
    AppColors.sky,
    AppColors.terracotta,
  ];

  Color _colorFor(String seed) {
    final hash = seed.codeUnits.fold<int>(0, (sum, c) => sum + c);
    return _palette[hash % _palette.length];
  }

  String _initialsFor(String seed) {
    final letters = seed
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .take(2);
    return letters.isEmpty ? '?' : letters.join();
  }

  Widget _fallback() => imageUrl != null
      ? Image.network(imageUrl!, fit: BoxFit.cover)
      : Image.asset('assets/images/default_avatar.png', fit: BoxFit.cover);

  @override
  Widget build(BuildContext context) {
    final seed = name;
    Widget child;
    if (seed == null) {
      // The signed-in user's avatar: a photo picked this session wins.
      child = ValueListenableBuilder<Uint8List?>(
        valueListenable: SessionPhotos.avatar,
        builder: (context, bytes, _) => bytes != null
            ? Image.memory(bytes, fit: BoxFit.cover)
            : _fallback(),
      );
    } else if (imageAsset != null) {
      child = Image.asset(imageAsset!, fit: BoxFit.cover);
    } else if (imageUrl != null) {
      child = Image.network(imageUrl!, fit: BoxFit.cover);
    } else if (seed.isNotEmpty) {
      child = Container(
        color: _colorFor(seed),
        alignment: Alignment.center,
        child: Text(
          _initialsFor(seed),
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      );
    } else {
      child = _fallback();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.blush,
        border: Border.all(color: AppColors.ink, width: borderWidth),
      ),
      // Relying on the decoration's own shape to clip the child is flaky for
      // an opaque Container child on Flutter web — an explicit ClipOval is
      // the robust way to guarantee a circle regardless of renderer.
      child: ClipOval(child: child),
    );
  }
}
