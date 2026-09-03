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
      backgroundColor: AppColors.linen,
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
        Material(
          color: AppColors.white,
          shape: const CircleBorder(
            side: BorderSide(color: AppColors.ink, width: AppBorder.standard),
          ),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
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
        color: AppColors.mossLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.ink, width: AppBorder.thick),
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
                color: AppColors.ink.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          const Icon(Icons.pets, size: 118, color: AppColors.ink),
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.ink, width: AppBorder.standard),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.stackSm),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.65),
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
          const Divider(
            height: AppBorder.thin,
            thickness: AppBorder.thin,
            color: AppColors.ink,
          ),
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
                      color: AppColors.mustardLight,
                      iconColor: AppColors.mustardDark,
                      onTap: () => onItemSelected(1),
                    ),
                    _AccessorySlot(
                      icon: Icons.auto_awesome,
                      selected: equippedItem == 2,
                      color: AppColors.blush,
                      iconColor: AppColors.terracottaDark,
                      onTap: () => onItemSelected(2),
                    ),
                    const _LockedAccessorySlot(),
                    const _EmptyAccessorySlot(),
                  ],
                );
              },
            ),
          ),
          const Divider(
            height: AppBorder.thin,
            thickness: AppBorder.thin,
            color: AppColors.ink,
          ),
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
                color: selected ? AppColors.mossDark : Colors.transparent,
                width: AppBorder.thin,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelLg.copyWith(
              color: selected ? AppColors.mossDark : AppColors.inkMuted,
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
    this.color = AppColors.linen,
    this.iconColor = AppColors.mossDark,
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
              color: selected ? AppColors.mossLight : color,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.ink, width: AppBorder.thin),
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
                        color: AppColors.moss,
                        border: Border.all(
                          color: AppColors.ink,
                          width: AppBorder.thin,
                        ),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: AppColors.white,
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
                color: AppColors.linen,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.ink, width: AppBorder.thin),
              ),
              child: const Icon(
                Icons.school,
                size: 44,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.linen.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.lock, color: AppColors.ink),
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
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.linenAlt,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.ink, width: AppBorder.thin),
        ),
        child: const Icon(Icons.close, color: AppColors.ink),
      ),
    );
  }
}
