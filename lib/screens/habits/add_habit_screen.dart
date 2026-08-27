import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/widgets/tactile_button.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key});

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  static const _icons = [
    Icons.water_drop,
    Icons.book,
    Icons.fitness_center,
    Icons.self_improvement,
    Icons.savings,
    Icons.bedtime,
  ];
  static const _categories = ['Health', 'Fitness', 'Learning', 'Mindfulness'];

  final _nameController = TextEditingController();
  IconData _selectedIcon = _icons.first;
  String _selectedCategory = _categories.first;
  int _xpReward = 50;
  HabitRepeat _repeat = HabitRepeat.daily;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveHabit() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final enteredName = _nameController.text.trim();
    final habit = Habit(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: enteredName.isEmpty ? 'New Habit' : enteredName,
      subtitle: _selectedCategory,
      icon: _selectedIcon,
      color: AppColors.primary,
      xpReward: _xpReward,
      repeat: _repeat,
    );

    await AppData.habits.addHabit(habit);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.containerPaddingMobile,
          AppSpacing.unit,
          AppSpacing.containerPaddingMobile,
          AppSpacing.containerPaddingMobile,
        ),
        child: TactileButton(
          label: _isSaving ? 'Saving...' : 'Save Habit',
          icon: Icons.check_circle,
          onPressed: _isSaving ? null : _saveHabit,
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.containerPaddingMobile,
                AppSpacing.gutter,
                AppSpacing.containerPaddingMobile,
                AppSpacing.stackMd,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'New Habit',
                              style: AppTextStyles.headlineLgMobile,
                            ),
                          ),
                          IconButton.filled(
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  AppColors.surfaceContainerHighest,
                              foregroundColor: AppColors.onSurfaceVariant,
                            ),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.stackMd),
                      _FieldLabel(label: 'Habit Name'),
                      const SizedBox(height: AppSpacing.unit),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.sentences,
                        style: AppTextStyles.bodyLg,
                        decoration: _fieldDecoration(
                          hintText: 'e.g. Drink 2L of Water',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.stackMd),
                      _FieldLabel(label: 'Icon'),
                      const SizedBox(height: AppSpacing.unit),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (
                              var index = 0;
                              index < _icons.length;
                              index++
                            ) ...[
                              _IconChoice(
                                icon: _icons[index],
                                selected: _selectedIcon == _icons[index],
                                onTap: () => setState(
                                  () => _selectedIcon = _icons[index],
                                ),
                              ),
                              if (index != _icons.length - 1)
                                const SizedBox(width: AppSpacing.stackSm),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.stackMd),
                      _FieldLabel(label: 'Category'),
                      const SizedBox(height: AppSpacing.unit),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        isExpanded: true,
                        icon: const Icon(Icons.expand_more),
                        decoration: _fieldDecoration(),
                        items: [
                          for (final category in _categories)
                            DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                        ],
                        onChanged: (category) {
                          if (category == null) return;
                          setState(() => _selectedCategory = category);
                        },
                      ),
                      const SizedBox(height: AppSpacing.stackMd),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Expanded(
                            child: _FieldLabel(label: 'XP Reward'),
                          ),
                          Text(
                            '$_xpReward XP',
                            style: AppTextStyles.headlineMd.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.unit),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: AppColors.primaryFixed,
                          thumbColor: AppColors.primary,
                          overlayColor: AppColors.primary.withValues(
                            alpha: 0.12,
                          ),
                          trackHeight: 12,
                        ),
                        child: Slider(
                          min: 10,
                          max: 100,
                          divisions: 9,
                          value: _xpReward.toDouble(),
                          label: '$_xpReward XP',
                          onChanged: (value) =>
                              setState(() => _xpReward = value.round()),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.gutter,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Easy (10)', style: AppTextStyles.labelSm),
                            Text('Epic (100)', style: AppTextStyles.labelSm),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.stackMd),
                      _FieldLabel(label: 'Repeat'),
                      const SizedBox(height: AppSpacing.unit),
                      Wrap(
                        spacing: AppSpacing.stackSm,
                        runSpacing: AppSpacing.stackSm,
                        children: [
                          for (final repeat in HabitRepeat.values)
                            ChoiceChip(
                              label: Text(repeat.label),
                              selected: _repeat == repeat,
                              showCheckmark: false,
                              selectedColor: AppColors.secondaryContainer,
                              backgroundColor:
                                  AppColors.surfaceContainerHighest,
                              side: BorderSide.none,
                              labelStyle: AppTextStyles.labelLg.copyWith(
                                color: _repeat == repeat
                                    ? AppColors.onSecondaryContainer
                                    : AppColors.onSurfaceVariant,
                              ),
                              onSelected: (_) =>
                                  setState(() => _repeat = repeat),
                            ),
                        ],
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

  InputDecoration _fieldDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTextStyles.bodyLg.copyWith(color: AppColors.outline),
      filled: true,
      fillColor: AppColors.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.containerPaddingMobile,
        vertical: AppSpacing.gutter,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.labelLg.copyWith(color: AppColors.onSurfaceVariant),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceContainerHighest,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: 64,
          child: Icon(
            icon,
            size: 30,
            color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
