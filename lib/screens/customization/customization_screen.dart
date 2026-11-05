import 'package:flutter/material.dart';
import 'package:nori/data/accessory_catalog.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/inventory.dart';
import 'package:nori/models/pet.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/accessory_art.dart';
import 'package:nori/widgets/load_error_view.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_evolved_sprite.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/tactile_button.dart';

class CustomizationScreen extends StatefulWidget {
  const CustomizationScreen({super.key});

  @override
  State<CustomizationScreen> createState() => _CustomizationScreenState();
}

class _CustomizationScreenState extends State<CustomizationScreen>
    with RemoteLoadState<CustomizationScreen> {
  Inventory? _inventory;
  PetEvolutionStage _stage = PetEvolutionStage.baby;
  String? _draftEquippedId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    await guardedLoad(hasData: _inventory != null, () async {
      final inventory = await AppData.inventory.getInventory();
      final pet = await AppData.pet.getPet();
      if (!mounted) return;
      setState(() {
        _inventory = inventory;
        _stage = pet.stage;
        _draftEquippedId = inventory.equippedAccessoryId;
      });
    });
  }

  void _selectOwned(String id) {
    setState(() => _draftEquippedId = _draftEquippedId == id ? null : id);
  }

  void _clearEquipped() {
    setState(() => _draftEquippedId = null);
  }

  Future<void> _saveLook() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final ok = await guardedAction(
      () => AppData.inventory.setEquippedAccessory(_draftEquippedId),
    );
    if (mounted) setState(() => _isSaving = false);
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Look saved!')));
  }

  @override
  Widget build(BuildContext context) {
    final inventory = _inventory;
    final draftEquippedId = _draftEquippedId;
    final error = loadError;

    return Scaffold(
      backgroundColor: AppColors.linen,
      body: SafeArea(
        child: inventory == null
            ? error != null
                  ? LoadErrorView(error: error, onRetry: _loadInventory)
                  : const Center(child: CircularProgressIndicator())
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
                              child: _PetPreview(
                                height: isWide ? 340 : 280,
                                evolved: _stage != PetEvolutionStage.baby,
                                equippedItem: draftEquippedId == null
                                    ? null
                                    : accessoryById(draftEquippedId),
                              ),
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
    return NoriScreenHeader(
      leading: Material(
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
      title: 'Style Pet',
      titleStyle: AppTextStyles.headlineLgMobile,
      titleTextAlign: TextAlign.center,
      trailing: const SizedBox(width: 48),
    );
  }
}

/// The pet preview panel above the accessory grid. Renders the currently
/// selected (not-yet-saved) accessory as flat-illustration art near Nori's
/// head — see accessory_art.dart.
class _PetPreview extends StatelessWidget {
  const _PetPreview({
    required this.height,
    required this.evolved,
    this.equippedItem,
  });

  final double height;

  /// Show the winged form instead of the baby, so the preview matches the
  /// pet on Home.
  final bool evolved;
  final AccessoryItem? equippedItem;

  @override
  Widget build(BuildContext context) {
    final petHeight = height * 0.72;
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
          if (evolved)
            LayoutBuilder(
              builder: (context, constraints) {
                // The evolved canvas is mostly wing span, so size by the
                // panel's width as well as petHeight.
                final spriteWidth = (constraints.maxWidth - AppSpacing.stackMd)
                    .clamp(0.0, petHeight * 1.6 * 1.15);
                return NoriEvolvedSprite(
                  width: spriteWidth,
                  overlayBuilder: equippedItem == null
                      ? null
                      : (context, spriteWidth, anchors) =>
                            evolvedPositionedAccessoryArt(
                              item: equippedItem!,
                              spriteWidth: spriteWidth,
                              anchors: anchors,
                            ),
                );
              },
            )
          else
            NoriAccessoryPreview(height: petHeight, item: equippedItem),
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
    required this.onClearEquipped,
    required this.onSave,
  });

  final Inventory inventory;
  final String? draftEquippedId;
  final ValueChanged<String> onSelectOwned;
  final VoidCallback onClearEquipped;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return NoriCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.md,
      clipBehavior: Clip.antiAlias,
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
                    _EmptyAccessorySlot(
                      selected: draftEquippedId == null,
                      onTap: onClearEquipped,
                    ),
                    for (final item in kAccessoryCatalog)
                      if (inventory.ownedAccessoryIds.contains(item.id))
                        _AccessorySlot(
                          icon: item.icon,
                          image: item.image,
                          color: item.color,
                          selected: draftEquippedId == item.id,
                          onTap: () => onSelectOwned(item.id),
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
    this.image,
  });

  final IconData icon;
  final String? image;
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
                Center(
                  child: image != null
                      ? Padding(
                          padding: const EdgeInsets.all(AppSpacing.unit),
                          child: Image.asset(image!, fit: BoxFit.contain),
                        )
                      : Icon(icon, size: 44, color: AppColors.mossDark),
                ),
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
                        color: AppColors.ink,
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
