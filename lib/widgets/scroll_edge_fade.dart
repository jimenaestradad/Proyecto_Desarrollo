import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Fades the leading/trailing edge of a horizontal scroller so cards and chips
/// dissolve instead of being cut by a hard line.
///
/// Each edge fades only while there is more to scroll that way: nothing fades
/// at the start until you've scrolled, and nothing fades at the end once the
/// last item is in view (or when everything already fits).
class ScrollEdgeFade extends StatefulWidget {
  const ScrollEdgeFade({super.key, required this.child, this.fadeExtent = 24});

  /// A horizontal [ListView] / [SingleChildScrollView].
  final Widget child;

  /// Width of each fade, in logical pixels.
  final double fadeExtent;

  @override
  State<ScrollEdgeFade> createState() => _ScrollEdgeFadeState();
}

class _ScrollEdgeFadeState extends State<ScrollEdgeFade> {
  bool _fadeStart = false;
  bool _fadeEnd = false;

  void _update(ScrollMetrics metrics) {
    if (metrics.axis != Axis.horizontal) return;
    final start = metrics.extentBefore > 0.5;
    final end = metrics.extentAfter > 0.5;
    if (start == _fadeStart && end == _fadeEnd) return;
    // Notifications can arrive mid-layout, where setState isn't allowed.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _fadeStart = start;
        _fadeEnd = end;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) {
        _update(n.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          _update(n.metrics);
          return false;
        },
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) {
            final f = (widget.fadeExtent / rect.width).clamp(0.0, 0.5);
            return LinearGradient(
              colors: [
                _fadeStart ? Colors.transparent : Colors.black,
                Colors.black,
                Colors.black,
                _fadeEnd ? Colors.transparent : Colors.black,
              ],
              stops: [0, f, 1 - f, 1],
            ).createShader(rect);
          },
          child: widget.child,
        ),
      ),
    );
  }
}
