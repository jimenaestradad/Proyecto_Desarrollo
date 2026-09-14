import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/habit.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/date_labels.dart';
import 'package:nori/utils/formatting.dart';
import 'package:nori/utils/id_generator.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/tactile_button.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key, this.habit});

  /// When set, the form opens pre-filled for editing this habit instead of
  /// creating a new one — see [_AddHabitScreenState.initState].
  final Habit? habit;

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
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _unitController = TextEditingController();
  final _minThresholdController = TextEditingController();
  final _quickLogController = TextEditingController();

  List<String> _categories = const [];
  IconData _selectedIcon = _icons.first;
  String? _selectedCategory;
  HabitType _selectedType = HabitType.quantity;
  HabitDifficulty _difficulty = HabitDifficulty.medium;
  HabitRepeat _repeat = HabitRepeat.daily;
  final Set<int> _customDays = {};

  bool _minThresholdEnabled = false;
  bool _endDateEnabled = false;
  bool _allowVacationFreeze = true;
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isSaving = false;

  bool get _isEditing => widget.habit != null;
  bool get _needsTarget => _selectedType != HabitType.binary;
  bool get _supportsThreshold =>
      _selectedType != HabitType.binary && _selectedType != HabitType.limit;

  @override
  void initState() {
    super.initState();
    _loadCategories();

    final habit = widget.habit;
    if (habit == null) return;

    _nameController.text = habit.name;
    _selectedIcon = habit.icon;
    _selectedCategory = habit.subtitle;
    _selectedType = habit.type;
    _difficulty = habit.difficulty;
    _repeat = habit.repeat;
    if (habit.customDays != null) _customDays.addAll(habit.customDays!);
    if (habit.targetValue != null) {
      _targetController.text = formatTrimmedNumber(habit.targetValue!);
    }
    _unitController.text = habit.unit ?? '';
    _minThresholdEnabled = habit.minThreshold != null;
    if (habit.minThreshold != null) {
      _minThresholdController.text = formatTrimmedNumber(habit.minThreshold!);
    }
    if (habit.quickLogAmount != null) {
      _quickLogController.text = formatTrimmedNumber(habit.quickLogAmount!);
    }
    _allowVacationFreeze = habit.allowVacationFreeze;
    _endDateEnabled = habit.startDate != null && habit.endDate != null;
    _startDate = habit.startDate;
    _endDate = habit.endDate;
  }

  Future<void> _loadCategories() async {
    final categories = await AppData.habitCategories.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      // Editing a habit whose subtitle isn't a known category (e.g. one of
      // the seed habits, which store free-text subtitles) keeps that text
      // selected rather than silently overwriting it on save.
      _selectedCategory ??= categories.contains(widget.habit?.subtitle)
          ? widget.habit!.subtitle
          : categories.first;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    _minThresholdController.dispose();
    _quickLogController.dispose();
    super.dispose();
  }

  /// Units auto-filled (and locked) for types with a fixed measurement —
  /// [HabitType.duration] is always minutes, [HabitType.multipleCompletion]
  /// is always a plain count. Quantity/cumulative stay free-text since their
  /// unit varies per habit (ml, pages, reps, ...).
  static const _fixedUnits = {
    HabitType.duration: 'min',
    HabitType.multipleCompletion: 'times',
  };

  void _selectType(HabitType type) {
    setState(() {
      final previousFixedUnit = _fixedUnits[_selectedType];
      final currentUnit = _unitController.text.trim();
      _selectedType = type;

      final newFixedUnit = _fixedUnits[type];
      if (newFixedUnit != null) {
        _unitController.text = newFixedUnit;
      } else if (previousFixedUnit != null && currentUnit == previousFixedUnit) {
        // Only clear it if it still holds the auto-filled value from the
        // previous type — don't wipe something the user typed themselves.
        _unitController.clear();
      }
      if (!_supportsThreshold) _minThresholdEnabled = false;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final start = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 2),
    );
    if (start == null || !mounted) return;
    final end = await showDatePicker(
      context: context,
      initialDate: _endDate ?? start.add(const Duration(days: 30)),
      firstDate: start,
      lastDate: DateTime(now.year + 2),
    );
    if (end == null || !mounted) return;
    setState(() {
      _startDate = start;
      _endDate = end;
    });
  }

  /// Preview of [Habit.quickLogStep]'s default heuristic for the form's
  /// current type/target — shown as the field's hint/helper text so users
  /// understand what "leave blank" means before they've saved anything.
  String _quickLogHint() {
    switch (_selectedType) {
      case HabitType.binary:
        return '';
      case HabitType.duration:
        return '+5 min';
      case HabitType.multipleCompletion:
        return '+1';
      case HabitType.quantity:
      case HabitType.limit:
        final target = double.tryParse(_targetController.text.trim());
        final unit = _unitController.text.trim();
        if (target == null || target <= 0) return '25% of target';
        final step = (target * 0.25).clamp(1, double.infinity).roundToDouble();
        return '+${formatTrimmedNumber(step)}${unit.isEmpty ? '' : ' $unit'}';
    }
  }

  String _dateRangeLabel() {
    if (_startDate == null || _endDate == null) {
      return 'Tap to choose a start & end date';
    }
    String format(DateTime d) => '${d.month}/${d.day}/${d.year}';
    return '${format(_startDate!)} – ${format(_endDate!)}';
  }

  Future<void> _saveHabit() async {
    if (_isSaving) return;

    if (_needsTarget && double.tryParse(_targetController.text.trim()) == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Enter a valid ideal target.')),
        );
      return;
    }

    setState(() => _isSaving = true);

    final enteredName = _nameController.text.trim();
    final target = _needsTarget
        ? double.tryParse(_targetController.text.trim())
        : null;
    final unit = _needsTarget ? _unitController.text.trim() : null;
    final minThreshold = (_minThresholdEnabled && _supportsThreshold)
        ? double.tryParse(_minThresholdController.text.trim())
        : null;
    final quickLogAmount = _needsTarget
        ? double.tryParse(_quickLogController.text.trim())
        : null;

    final existing = widget.habit;
    final habit = Habit(
      id: existing?.id ?? generateId(),
      name: enteredName.isEmpty ? 'New Habit' : enteredName,
      subtitle: _selectedCategory ?? (_categories.isEmpty ? '' : _categories.first),
      icon: _selectedIcon,
      color: existing?.color ?? AppColors.terracotta,
      xpReward: _difficulty.baseXp,
      coinReward: _difficulty.baseCoins,
      repeat: _repeat,
      type: _selectedType,
      difficulty: _difficulty,
      targetValue: target,
      unit: unit == null || unit.isEmpty ? null : unit,
      minThreshold: minThreshold,
      quickLogAmount: quickLogAmount,
      currentValue: existing?.currentValue ?? 0,
      customDays: _repeat == HabitRepeat.custom ? {..._customDays} : null,
      allowVacationFreeze: _allowVacationFreeze,
      lastAwardedXp: existing?.lastAwardedXp ?? 0,
      lastAwardedCoins: existing?.lastAwardedCoins ?? 0,
      startDate: _endDateEnabled ? _startDate : null,
      endDate: _endDateEnabled ? _endDate : null,
      isCompletedToday: existing?.isCompletedToday ?? false,
    );

    try {
      if (_isEditing) {
        await AppData.habits.updateHabit(habit);
      } else {
        await AppData.habits.addHabit(habit);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
          label: _isSaving
              ? 'Saving...'
              : (_isEditing ? 'Save Changes' : 'Save Habit'),
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
                              _isEditing ? 'Edit Habit' : 'New Habit',
                              style: AppTextStyles.headlineLgMobile,
                            ),
                          ),
                          IconButton.filled(
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.white,
                              foregroundColor: AppColors.ink,
                              side: const BorderSide(
                                color: AppColors.ink,
                                width: AppBorder.thin,
                              ),
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
                          // A habit's existing subtitle might not be a known
                          // category (e.g. a seeded demo habit's free-text
                          // subtitle, or one deleted later in Settings) —
                          // keep it selectable instead of silently
                          // overwriting it with the first category on save.
                          if (_selectedCategory != null &&
                              !_categories.contains(_selectedCategory))
                            DropdownMenuItem(
                              value: _selectedCategory,
                              child: Text(_selectedCategory!),
                            ),
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
                      _FieldLabel(label: 'Tracking Type'),
                      const SizedBox(height: AppSpacing.unit),
                      for (
                        var row = 0;
                        row < HabitType.values.length;
                        row += 2
                      ) ...[
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _TypeCard(
                                  type: HabitType.values[row],
                                  selected:
                                      _selectedType == HabitType.values[row],
                                  onTap: () =>
                                      _selectType(HabitType.values[row]),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.stackSm),
                              // An odd HabitType count (currently 5) leaves
                              // the last row with no pair — a blank spacer
                              // keeps that card at the grid's half-width
                              // instead of stretching to fill the row.
                              Expanded(
                                child: row + 1 < HabitType.values.length
                                    ? _TypeCard(
                                        type: HabitType.values[row + 1],
                                        selected:
                                            _selectedType ==
                                                HabitType.values[row + 1],
                                        onTap: () => _selectType(
                                          HabitType.values[row + 1],
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                        if (row + 2 < HabitType.values.length)
                          const SizedBox(height: AppSpacing.stackSm),
                      ],
                      if (_needsTarget) ...[
                        const SizedBox(height: AppSpacing.stackMd),
                        _FieldLabel(label: 'Ideal Target'),
                        const SizedBox(height: AppSpacing.unit),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _targetController,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                style: AppTextStyles.bodyLg,
                                decoration: _fieldDecoration(hintText: '1000'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.stackSm),
                            Expanded(
                              child: TextField(
                                controller: _unitController,
                                enabled: !_fixedUnits.containsKey(_selectedType),
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyLg,
                                decoration: _fieldDecoration(hintText: 'unit'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.stackMd),
                        _FieldLabel(label: 'Quick-Log Amount'),
                        const SizedBox(height: AppSpacing.unit),
                        TextField(
                          controller: _quickLogController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppTextStyles.bodyLg,
                          decoration: _fieldDecoration(hintText: _quickLogHint()),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'What the quick-log button on Home/Habits adds per tap. '
                          'Leave blank for the default (${_quickLogHint()}).',
                          style: AppTextStyles.labelSm.copyWith(color: AppColors.inkFaint),
                        ),
                      ],
                      if (_supportsThreshold) ...[
                        const SizedBox(height: AppSpacing.stackMd),
                        _ToggleRow(
                          title: 'Minimum Threshold',
                          subtitle: 'Partial credit protection',
                          value: _minThresholdEnabled,
                          onChanged: (value) =>
                              setState(() => _minThresholdEnabled = value),
                        ),
                        if (_minThresholdEnabled) ...[
                          const SizedBox(height: AppSpacing.stackSm),
                          TextField(
                            controller: _minThresholdController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: AppTextStyles.bodyLg,
                            decoration: _fieldDecoration(hintText: '750'),
                          ),
                          const SizedBox(height: AppSpacing.stackSm),
                          const _InfoBanner(
                            icon: Icons.eco,
                            message:
                                "Preserves streak & awards 75% XP if the ideal target isn't reached.",
                          ),
                        ],
                      ],
                      const SizedBox(height: AppSpacing.stackMd),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Expanded(
                            child: _FieldLabel(label: 'Difficulty'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.unit),
                      Wrap(
                        spacing: AppSpacing.stackSm,
                        runSpacing: AppSpacing.stackSm,
                        children: [
                          for (final difficulty in HabitDifficulty.values)
                            ChoiceChip(
                              label: Text(
                                '${difficulty.label} · ${difficulty.baseXp} XP',
                              ),
                              selected: _difficulty == difficulty,
                              showCheckmark: false,
                              selectedColor: AppColors.mossLight,
                              backgroundColor: AppColors.white,
                              side: const BorderSide(
                                color: AppColors.ink,
                                width: AppBorder.thin,
                              ),
                              labelStyle: AppTextStyles.labelLg.copyWith(
                                color: AppColors.ink,
                              ),
                              onSelected: (_) =>
                                  setState(() => _difficulty = difficulty),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.stackSm),
                      const _InfoBanner(
                        icon: Icons.bolt,
                        message:
                            'Adaptive XP scales between 0.5x–1.5x depending on your consistency over time.',
                      ),
                      const SizedBox(height: AppSpacing.stackSm),
                      _RewardPreview(
                        difficulty: _difficulty,
                        adaptiveMultiplier: widget.habit?.adaptiveMultiplier ?? 1.0,
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
                              selectedColor: AppColors.mossLight,
                              backgroundColor: AppColors.white,
                              side: const BorderSide(
                                color: AppColors.ink,
                                width: AppBorder.thin,
                              ),
                              labelStyle: AppTextStyles.labelLg.copyWith(
                                color: AppColors.ink,
                              ),
                              onSelected: (_) =>
                                  setState(() => _repeat = repeat),
                            ),
                        ],
                      ),
                      if (_repeat == HabitRepeat.custom) ...[
                        const SizedBox(height: AppSpacing.stackSm),
                        Wrap(
                          spacing: AppSpacing.unit,
                          runSpacing: AppSpacing.unit,
                          children: [
                            for (var day = 1; day <= 7; day++)
                              _DayCircle(
                                label: weekdayInitial(day),
                                selected: _customDays.contains(day),
                                onTap: () => setState(() {
                                  if (!_customDays.remove(day)) {
                                    _customDays.add(day);
                                  }
                                }),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.stackMd),
                      _ToggleRow(
                        title: 'Set End Date',
                        subtitle:
                            'Auto-archives history without deleting statistics or streak records.',
                        value: _endDateEnabled,
                        onChanged: (value) =>
                            setState(() => _endDateEnabled = value),
                      ),
                      if (_endDateEnabled) ...[
                        const SizedBox(height: AppSpacing.stackSm),
                        InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          onTap: _pickDateRange,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.containerPaddingMobile,
                              vertical: AppSpacing.gutter,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: AppColors.ink,
                                width: AppBorder.thin,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.date_range, color: AppColors.inkMuted),
                                const SizedBox(width: AppSpacing.stackSm),
                                Expanded(
                                  child: Text(
                                    _dateRangeLabel(),
                                    style: AppTextStyles.bodyMd,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.stackMd),
                      _ToggleRow(
                        title: 'Allow Vacation Mode Freeze',
                        subtitle: 'Pet health protected while paused.',
                        value: _allowVacationFreeze,
                        onChanged: (value) =>
                            setState(() => _allowVacationFreeze = value),
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
      hintStyle: AppTextStyles.bodyLg.copyWith(color: AppColors.inkFaint),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.containerPaddingMobile,
        vertical: AppSpacing.gutter,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.ink, width: AppBorder.standard),
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
      style: AppTextStyles.labelLg.copyWith(color: AppColors.inkMuted),
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
      color: selected ? AppColors.moss : AppColors.white,
      shape: CircleBorder(
        side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: 64,
          child: Icon(
            icon,
            size: 30,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

IconData _typeIcon(HabitType type) => switch (type) {
  HabitType.binary => Icons.check_circle,
  HabitType.quantity => Icons.show_chart,
  HabitType.duration => Icons.timer,
  HabitType.multipleCompletion => Icons.checklist,
  HabitType.limit => Icons.shield,
};

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final HabitType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.moss : AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.stackSm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.ink, width: AppBorder.thin),
          ),
          child: Row(
            children: [
              Icon(
                _typeIcon(type),
                color: AppColors.ink,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.stackSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      type.label,
                      style: AppTextStyles.labelLg.copyWith(
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      type.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelSm.copyWith(
                        color: selected
                            ? AppColors.ink.withValues(alpha: 0.75)
                            : AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.moss : AppColors.white,
      shape: CircleBorder(
        side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: 36,
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.labelLg.copyWith(
                color: AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.labelLg),
              Text(
                subtitle,
                style: AppTextStyles.labelSm.copyWith(color: AppColors.inkFaint),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.white,
          activeTrackColor: AppColors.moss,
          inactiveThumbColor: AppColors.white,
          inactiveTrackColor: AppColors.linenAlt,
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.stackSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.sky,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.ink, size: 20),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.labelLg.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardPreview extends StatelessWidget {
  const _RewardPreview({required this.difficulty, this.adaptiveMultiplier = 1.0});

  final HabitDifficulty difficulty;

  /// The habit's actual per-claim multiplier when editing an existing
  /// habit (1.0 for a new one). Folding this into the preview — instead of
  /// always showing the raw difficulty base — is what keeps this number in
  /// sync with the reward pill the Habits screen shows for the same habit;
  /// previously they could disagree once a habit's multiplier drifted from
  /// 1.0 (e.g. the seeded Gym Session habit, at 1.2x).
  final double adaptiveMultiplier;

  @override
  Widget build(BuildContext context) {
    final xp = (difficulty.baseXp * adaptiveMultiplier).round();
    final coins = difficulty.baseCoins;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      decoration: BoxDecoration(
        color: AppColors.mustardLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: AppBorder.thin),
      ),
      child: Row(
        children: [
          const NoriIconBadge(
            icon: Icons.card_giftcard,
            background: AppColors.white,
            size: 36,
            circle: true,
            iconSize: 18,
            iconColor: AppColors.mustardDark,
          ),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+$xp XP',
                  style: AppTextStyles.labelLg.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '+$coins Coins · Pet care & shop',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
