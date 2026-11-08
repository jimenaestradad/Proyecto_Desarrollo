import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/habit.dart';
import '../theme/app_theme.dart';
import 'reward_pill.dart';

/// The no-modal "that counted" cue for completing a habit: a reward chip
/// ("+13 XP · 5") rises from where the finger tapped and fades in about a
/// second, with a short haptic tap. Nothing to dismiss and nothing blocks the
/// next tap. See docs/DESIGN.md §9.
class RewardBurst {
  RewardBurst._();

  /// Where the last pointer went down, so the chip can start at the finger
  /// without every claim path having to pass the card's position along.
  static Offset? _lastPointer;

  /// Wrap the app (MaterialApp.builder) so taps are tracked.
  static Widget trackPointer({required Widget child}) => Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (event) => _lastPointer = event.position,
    child: child,
  );

  /// Shows the burst for a claim that is about to pay. Does nothing for an
  /// undo, an edit, or a day that already paid (a re-claim pays 0).
  static void showForClaim(
    BuildContext context, {
    required Habit before,
    required Habit after,
  }) {
    if (before.isCompletedToday ||
        !after.isCompletedToday ||
        before.rewardPaid) {
      return;
    }
    show(context, xp: after.lastAwardedXp, coins: after.lastAwardedCoins);
  }

  static void show(
    BuildContext context, {
    required int xp,
    required int coins,
  }) {
    if (xp <= 0 && coins <= 0) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    HapticFeedback.lightImpact();

    final size = MediaQuery.sizeOf(context);
    final pointer = _lastPointer ?? Offset(size.width / 2, size.height / 2);
    // Keep the ~140px chip on screen when the tap was near an edge.
    final x = pointer.dx.clamp(80.0, size.width - 80.0);
    final still = MediaQuery.disableAnimationsOf(context);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _BurstChip(
        x: x,
        y: pointer.dy - 24,
        xp: xp,
        coins: coins,
        still: still,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _BurstChip extends StatefulWidget {
  const _BurstChip({
    required this.x,
    required this.y,
    required this.xp,
    required this.coins,
    required this.still,
    required this.onDone,
  });

  final double x;
  final double y;
  final int xp;
  final int coins;

  /// Reduced motion: fade in place instead of rising.
  final bool still;
  final VoidCallback onDone;

  @override
  State<_BurstChip> createState() => _BurstChipState();
}

class _BurstChipState extends State<_BurstChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Positioned must sit directly under the overlay entry or a Stack, so the
    // IgnorePointer goes above a Stack that holds the moving chip.
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _controller.value;
                // In over the first 15%, hold, out over the last 30%.
                final opacity = t < 0.15
                    ? t / 0.15
                    : t > 0.7
                    ? (1 - t) / 0.3
                    : 1.0;
                final rise = widget.still
                    ? 0.0
                    : Curves.easeOut.transform(t) * 40;
                return Positioned(
                  left: widget.x,
                  top: widget.y - rise,
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, -1),
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: child,
                    ),
                  ),
                );
              },
              child: Material(
                type: MaterialType.transparency,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: AppColors.ink,
                      width: AppBorder.standard,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: RewardPill(xp: widget.xp, coins: widget.coins),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
