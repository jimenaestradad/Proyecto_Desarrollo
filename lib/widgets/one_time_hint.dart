import 'package:flutter/material.dart';
import '../data/tips_store.dart';
import '../theme/app_theme.dart';
import 'nori_info_banner.dart';

/// A [NoriInfoBanner] that shows once per account until dismissed, then
/// never again (see [TipsStore]). It takes no space while hidden or loading,
/// so a screen can drop it into a column without reserving room for it.
class OneTimeHint extends StatefulWidget {
  const OneTimeHint({
    super.key,
    required this.tip,
    required this.icon,
    required this.message,
    this.store,
  });

  final Tip tip;
  final IconData icon;
  final String message;

  /// Defaults to [TipsStore.current]; tests pass their own.
  final TipsStore? store;

  @override
  State<OneTimeHint> createState() => _OneTimeHintState();
}

class _OneTimeHintState extends State<OneTimeHint> {
  late final TipsStore _store = widget.store ?? TipsStore.current();
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    TipsStore.resets.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    TipsStore.resets.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final dismissed = await _store.isHintDismissed(widget.tip);
    if (!mounted) return;
    setState(() => _visible = !dismissed);
  }

  void _dismiss() {
    setState(() => _visible = false);
    _store.dismissHint(widget.tip);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.stackSm),
      child: NoriInfoBanner(
        icon: widget.icon,
        message: widget.message,
        onDismiss: _dismiss,
      ),
    );
  }
}
