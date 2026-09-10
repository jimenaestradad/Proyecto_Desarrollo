import 'package:flutter/material.dart';
import 'package:nori/data/accessory_catalog.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/inventory.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/tactile_button.dart';

class CustomizationScreen extends StatefulWidget {
  const CustomizationScreen({super.key});

  @override
  State<CustomizationScreen> createState() => _CustomizationScreenState();
}

class _CustomizationScreenState extends State<CustomizationScreen> {
  Inventory? _inventory;
  String? _draftEquippedId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    final inventory = await AppData.inventory.getInventory();
    if (!mounted) return;
    setState(() {
      _inventory = inventory;
      _draftEquippedId = inventory.equippedAccessoryId;
    });
  }

  void _selectOwned(String id) {
    setState(() => _draftEquippedId = _draftEquippedId == id ? null : id);
  }

  void _clearEquipped() {
    setState(() => _draftEquippedId = null);
  }

  void _promptBuyInShop() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Buy this in the Shop to equip it.')),
      );
  }

  Future<void> _saveLook() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    await AppData.inventory.setEquippedAccessory(_draftEquippedId);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Look saved!')));
  }

  @override
  Widget build(BuildContext context) {
    final inventory = _inventory;

    return Scaffold(
      backgroundColor: AppColors.linen,
      body: SafeArea(
        child: inventory == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
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
                            const SizedBox(height: AppSpacing.stackSm),
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
                                inventory: inventory,
                                draftEquippedId: _draftEquippedId,
                                onSelectOwned: _selectOwned,
                                onSelectLocked: _promptBuyInShop,
                                onClearEquipped: _clearEquipped,
                                onSave: _saveLook,
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
          Image.asset(
            'assets/images/nori_front.png',
            height: height * 0.72,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}

class _InventoryPanel extends StatelessWidget {
  const _InventoryPanel({
    required this.inventory,
    required this.draftEquippedId,
    required this.onSelectOwned,
    required this.onSelectLocked,
    required this.onClearEquipped,
    required this.onSave,
  });

  final Inventory inventory;
  final String? draftEquippedId;
  final ValueChanged<String> onSelectOwned;
  final VoidCallback onSelectLocked;
  final VoidCallback onClearEquipped;
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
          const SizedBox(height: AppSpacing.stackSm),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.containerPaddingMobile,
              ),
              child: Text('Accessories', style: AppTextStyles.headlineMd),
            ),
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
                    for (final item in kAccessoryCatalog)
                      if (inventory.ownedAccessoryIds.contains(item.id))
                        _AccessorySlot(
                          icon: item.icon,
                          color: item.color,
                          selected: draftEquippedId == item.id,
                          onTap: () => onSelectOwned(item.id),
                        )
                      else
                        _LockedAccessorySlot(onTap: onSelectLocked),
                    _EmptyAccessorySlot(
                      selected: draftEquippedId == null,
                      onTap: onClearEquipped,
                    ),
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

class _AccessorySlot extends StatelessWidget {
  const _AccessorySlot({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

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
                Center(child: Icon(icon, size: 44, color: AppColors.mossDark)),
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

/// A catalog accessory the user doesn't own yet — tapping points to the Shop
/// rather than opening a purchase flow in-context (see plan: this screen's
/// scope is "equip what you own", not a second place to buy).
class _LockedAccessorySlot extends StatelessWidget {
  const _LockedAccessorySlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Locked accessory — buy in Shop',
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
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
                  Icons.shopping_bag,
                  size: 40,
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
      ),
    );
  }
}

class _EmptyAccessorySlot extends StatelessWidget {
  const _EmptyAccessorySlot({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'No accessory',
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? AppColors.mossLight : AppColors.linenAlt,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.ink, width: AppBorder.thin),
          ),
          child: const Icon(Icons.close, color: AppColors.ink),
        ),
      ),
    );
  }
}
