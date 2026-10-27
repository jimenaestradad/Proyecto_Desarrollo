import 'package:flutter/material.dart';
import 'package:nori/data/tips_store.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/tactile_button.dart';

/// Three swipeable cards explaining the loop (habits → XP and coins → care
/// for Nori → streaks), shown once after naming the pet — see
/// [NamePetScreen] — and again from Settings' "Replay intro and tips".
///
/// Counts as seen the moment it opens, so leaving by Skip, system back or
/// the last button all behave the same. Always pops back to its caller.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, this.store});

  /// Defaults to [TipsStore.current]; tests pass their own.
  final TipsStore? store;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  static const _pages = [
    _IntroPage(
      icon: Icons.check_circle,
      tint: AppColors.mossLight,
      title: 'Build habits that stick',
      body:
          'Add the habits you want to keep. Every time you complete one, you '
          'earn XP and coins.',
    ),
    _IntroPage(
      icon: Icons.pets,
      tint: AppColors.blush,
      title: 'Look after Nori',
      body:
          "Nori's Happy, Fed and Clean meters drop over time. Spend your "
          'coins in the shop on food, care items and accessories.',
    ),
    _IntroPage(
      icon: Icons.local_fire_department,
      tint: AppColors.mustardLight,
      title: 'Keep your streak going',
      body:
          'Show up day after day to build a streak and level up. The '
          "Calendar shows how you're doing.",
    ),
  ];

  final _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == _pages.length - 1;

  @override
  void initState() {
    super.initState();
    (widget.store ?? TipsStore.current()).markIntroSeen();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      Navigator.pop(context);
      return;
    }
    final target = _page + 1;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(target);
    } else {
      _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.containerPaddingMobile,
            vertical: AppSpacing.gutter,
          ),
          child: Column(
            children: [
              // Always laid out so the card doesn't jump when Skip goes away
              // on the last page.
              Align(
                alignment: Alignment.centerRight,
                child: Visibility(
                  visible: !_isLast,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Skip'),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (index) => setState(() => _page = index),
                  children: [for (final page in _pages) _IntroCard(page: page)],
                ),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              Semantics(
                label: 'Step ${_page + 1} of ${_pages.length}',
                excludeSemantics: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _pages.length; i++)
                      _Dot(selected: i == _page),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.stackMd),
              TactileButton(
                label: _isLast ? 'Start tracking' : 'Next',
                icon: Icons.arrow_forward,
                onPressed: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroPage {
  const _IntroPage({
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String body;
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.page});

  final _IntroPage page;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: NoriCard(
            padding: const EdgeInsets.all(AppSpacing.stackMd),
            radius: AppRadius.lg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NoriIconBadge(
                  icon: page.icon,
                  background: page.tint,
                  size: 96,
                  iconSize: 44,
                  circle: true,
                ),
                const SizedBox(height: AppSpacing.stackMd),
                Text(
                  page.title,
                  style: AppTextStyles.headlineLgMobile,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.unit),
                Text(
                  page.body,
                  style: AppTextStyles.bodyLg.copyWith(
                    color: AppColors.inkMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: selected ? 24 : 12,
      height: 12,
      decoration: BoxDecoration(
        color: selected ? AppColors.moss : AppColors.linenAlt,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
    );
  }
}
