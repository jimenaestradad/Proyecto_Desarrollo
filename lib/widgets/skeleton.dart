import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'nori_scroll_scaffold.dart';

/// Fades its [child] in and out, so placeholder shapes read as "loading"
/// rather than as empty content.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: widget.child,
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({this.width, required this.height, this.radius = 12});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.linenAlt,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.inkFaint, width: AppBorder.thin),
      ),
    );
  }
}

/// Stands in for the Habits tab while its first load is in flight: a title
/// bar and a few card-shaped blocks in the layout the real list will take.
class HabitListSkeleton extends StatelessWidget {
  const HabitListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: NoriScrollScaffold(
        maxWidth: 1200,
        children: [
          const _SkeletonBlock(height: 36, width: 140),
          const SizedBox(height: AppSpacing.stackMd),
          const _SkeletonBlock(height: 56, radius: AppRadius.full),
          const SizedBox(height: AppSpacing.stackMd),
          for (var i = 0; i < 4; i++) ...[
            const _SkeletonBlock(height: 96, radius: AppRadius.sm),
            const SizedBox(height: AppSpacing.stackSm),
          ],
        ],
      ),
    );
  }
}
