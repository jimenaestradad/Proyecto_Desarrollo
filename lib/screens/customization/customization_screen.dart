import 'package:flutter/material.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/future_feature_banner.dart';
import 'package:nori/widgets/tactile_button.dart';

class CustomizationScreen extends StatefulWidget {
  const CustomizationScreen({super.key});

  @override
  State<CustomizationScreen> createState() => _CustomizationScreenState();
}

class _CustomizationScreenState extends State<CustomizationScreen> {
  static const _tabs = ['Hats', 'Glasses', 'Outfits', 'Colors'];

  int _selectedTab = 0;
  int _equippedItem = 0;

  void _showUnavailable() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Not available yet')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            final horizontalPadding = isWide
                ? AppSpacing.containerPaddingDesktop
                : AppSpacing.containerPaddingMobile;

            return SingleChildScrollView(
              padding: EdgeInsets.only(bottom: AppSpacing.stackMd),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          AppSpacing.gutter,
                          horizontalPadding,
                          AppSpacing.stackSm,
                        ),
                        child: const _CustomizationHeader(),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: const FutureFeatureBanner(),
                      ),
                      const SizedBox(height: AppSpacing.stackMd),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: _PetPreview(height: isWide ? 340 : 280),
                      ),
                      const SizedBox(height: AppSpacing.stackMd),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        child: _InventoryPanel(
                          tabs: _tabs,
                          selectedTab: _selectedTab,
                          equippedItem: _equippedItem,
                          onTabSelected: (index) {
                            setState(() => _selectedTab = index);
                          },
                          onItemSelected: (index) {
                            setState(() => _equippedItem = index);
                          },
                          onSave: _showUnavailable,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CustomizationHeader extends StatelessWidget {
  const _CustomizationHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: AppColors.surfaceContainerHighest,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
        ),
        Expanded(
          child: Text(
            'Style Pet',
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineLgMobile,
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _PetPreview extends StatelessWidget {
  const _PetPreview({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.14),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: height * 0.2,
            child: Container(
              width: 170,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.onSurface.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          const Icon(Icons.pets, size: 118, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _InventoryPanel extends StatelessWidget {
  const _InventoryPanel({
    required this.tabs,
    required this.selectedTab,
    required this.equippedItem,
    required this.onTabSelected,
    required this.onItemSelected,
    required this.onSave,
  });

  final List<String> tabs;
  final int selectedTab;
  final int equippedItem;
  final ValueChanged<int> onTabSelected;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.09),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.stackSm),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          const SizedBox(height: AppSpacing.unit),
          Row(
            children: [
              for (var index = 0; index < tabs.length; index++)
                Expanded(
                  child: _InventoryTab(
                    label: tabs[index],
                    selected: selectedTab == index,
                    onTap: () => onTabSelected(index),
                  ),
                ),
            ],
          ),
          const Divider(height: 1, color: AppColors.surfaceContainerHigh),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.containerPaddingMobile),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth >= 620
                    ? 5
                    : constraints.maxWidth >= 440
                    ? 4
                    : 3;

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: AppSpacing.gutter,
                  mainAxisSpacing: AppSpacing.gutter,
                  children: [
                    _AccessorySlot(
                      icon: Icons.checkroom,
                      selected: equippedItem == 0,
                      onTap: () => onItemSelected(0),
                    ),
                    _AccessorySlot(
                      icon: Icons.emoji_events,
                      selected: equippedItem == 1,
                      color: AppColors.tertiaryFixed,
                      iconColor: AppColors.tertiary,
                      onTap: () => onItemSelected(1),
                    ),
                    _AccessorySlot(
                      icon: Icons.auto_awesome,
                      selected: equippedItem == 2,
                      color: AppColors.secondaryContainer,
                      iconColor: AppColors.secondary,
                      onTap: () => onItemSelected(2),
                    ),
                    const _LockedAccessorySlot(),
                    const _EmptyAccessorySlot(),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.surfaceContainerHigh),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.containerPaddingMobile),
            child: TactileButton(label: 'Save Look', onPressed: onSave),
          ),
        ],
      ),
    );
  }
}

class _InventoryTab extends StatelessWidget {
  const _InventoryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackSm),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLg.copyWith(
              color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessorySlot extends StatelessWidget {
  const _AccessorySlot({
    required this.icon,
    required this.selected,
    required this.onTap,
    this.color = AppColors.surfaceContainerHighest,
    this.iconColor = AppColors.primary,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryFixed : color,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(child: Icon(icon, size: 44, color: iconColor)),
                if (selected)
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        border: Border.all(
                          color: AppColors.surfaceContainerLowest,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LockedAccessorySlot extends StatelessWidget {
  const _LockedAccessorySlot();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Locked accessory',
      enabled: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.5,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.school,
                size: 44,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.lock, color: AppColors.outline),
          ),
        ],
      ),
    );
  }
}

class _EmptyAccessorySlot extends StatelessWidget {
  const _EmptyAccessorySlot();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Empty accessory slot',
      child: CustomPaint(
        painter: const _DashedBorderPainter(color: AppColors.outlineVariant),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: const Icon(Icons.close, color: AppColors.outlineVariant),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
          const Radius.circular(AppRadius.sm),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final dashEnd = distance + 7 < metric.length
            ? distance + 7
            : metric.length;
        canvas.drawPath(metric.extractPath(distance, dashEnd), paint);
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
