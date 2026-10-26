import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// User avatar. Renders [imageUrl] once profile photos exist server-side;
/// today every repository returns `null`.
///
/// For the signed-in user (no [name] passed) that falls back to the
/// illustrated default avatar art. For *other* mock people shown around the
/// app — social feed authors, leaderboard rows — pass [name] instead: it
/// picks a deterministic color + initials so a list of mock friends doesn't
/// visually read as the same person repeated (see `social_screen.dart`).
class NoriAvatar extends StatelessWidget {
  const NoriAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 40,
    this.borderWidth = AppBorder.thick,
  });

  final String? imageUrl;
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

  @override
  Widget build(BuildContext context) {
    final seed = name;
    Widget child;
    if (imageUrl != null) {
      child = Image.network(imageUrl!, fit: BoxFit.cover);
    } else if (seed != null && seed.isNotEmpty) {
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
      child = Image.asset(
        'assets/images/default_avatar.png',
        fit: BoxFit.cover,
      );
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
