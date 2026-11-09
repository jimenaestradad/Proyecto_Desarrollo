import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/habit_history_store.dart' show addDays, dateOnly;
import 'package:nori/data/habit_repository.dart' show kMaxDeletableActiveDays;
import 'package:nori/models/habit.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/date_labels.dart';
import 'package:nori/utils/formatting.dart';
import 'package:nori/utils/id_generator.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/delete_habit_dialog.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/data/tips_store.dart';
import 'package:nori/widgets/nori_info_banner.dart';
import 'package:nori/widgets/one_time_hint.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_text_prompt.dart';
import 'package:nori/widgets/tactile_button.dart';
import '../../widgets/scroll_edge_fade.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key, this.habit});

  /// When set, the form opens pre-filled for editing this habit instead of
  /// creating a new one — see [_AddHabitScreenState.initState].
  final Habit? habit;

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen>
    with RemoteLoadState<AddHabitScreen> {
  static const _icons = [
    Icons.water_drop,
    Icons.book,
    Icons.fitness_center,
    Icons.self_improvement,
    Icons.savings,
    Icons.bedtime,
  ];
  // All registered in ColorRegistry, so whatever is picked round-trips
  // through Firestore.
  static const _colors = [
    AppColors.terracotta,
    AppColors.sky,
    AppColors.mossLight,
    AppColors.blushPink,
    AppColors.mustardLight,
    AppColors.blush,
  ];
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _unitController = TextEditingController();
  final _minThresholdController = TextEditingController();
  final _quickLogController = TextEditingController();

  /// Lets a failed Save take the person to the field the message is about
  /// (the form is one long scroll, so it is usually out of sight).
  final _targetFocus = FocusNode();
  final _quickLogFocus = FocusNode();
  final _minThresholdFocus = FocusNode();
  final _customDaysKey = GlobalKey();

  /// The message a refused Save left on each field, shown under it in red
  /// until the person edits it (or picks a day, for the custom schedule).
  final Map<FocusNode, String> _fieldErrors = {};
  String? _customDaysError;

  /// Dropdown value for the trailing "Add Category" entry. Never a real
  /// category: it opens a prompt, and the field is put back right after.
  static const _addCategoryValue = '\u0000add-category';
  final _categoryFieldKey = GlobalKey<FormFieldState<String>>();

  List<String> _categories = const [];
  bool _categoriesLoaded = false;
  IconData _selectedIcon = _icons.first;
  Color _selectedColor = _colors.first;
  String? _selectedCategory;
  HabitType _selectedType = HabitType.quantity;
  HabitDifficulty _difficulty = HabitDifficulty.medium;
  HabitRepeat _repeat = HabitRepeat.daily;
  final Set<int> _customDays = {};

  bool _minThresholdEnabled = false;
  bool _endDateEnabled = false;
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isSaving = false;

  bool get _isEditing => widget.habit != null;

  /// Days with any activity — decides whether Delete is offered next to
  /// Archive (see kMaxDeletableActiveDays). Null until loaded, and while
  /// null only Archive shows.
  int? _activeDays;
  bool _isManaging = false;

  /// One id per screen, not per Save tap: if a save times out but still
  /// commits, retrying overwrites that same doc instead of creating a
  /// duplicate habit.
  final String _newHabitId = generateId();

  bool get _needsTarget => _selectedType != HabitType.binary;
  bool get _supportsThreshold =>
      _selectedType != HabitType.binary && _selectedType != HabitType.limit;

  @override
  void initState() {
    super.initState();
    _loadCategories();

    final habit = widget.habit;
    if (habit == null) return;
    guardedLoad(hasData: true, () async {
      final count = await AppData.habits.activeDayCount(habit.id);
      if (mounted) setState(() => _activeDays = count);
    });

    _nameController.text = habit.name;
    _selectedIcon = habit.icon;
    _selectedColor = habit.color;
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
    _endDateEnabled = habit.startDate != null && habit.endDate != null;
    _startDate = habit.startDate;
    _endDate = habit.endDate;
  }

  /// The form is usable without categories (no spinner gates it), so a
  /// failed load only needs the snackbar — hence `hasData: true`.
  Future<void> _loadCategories() =>
      guardedLoad(_fetchCategories, hasData: true);

  Future<void> _fetchCategories() async {
    final categories = await AppData.habitCategories.getCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _categoriesLoaded = true;
      // Editing a habit whose subtitle isn't a known category (e.g. one of
      // the seed habits, which store free-text subtitles) keeps that text
      // selected rather than silently overwriting it on save.
      _selectedCategory ??= categories.contains(widget.habit?.subtitle)
          ? widget.habit!.subtitle
          : (categories.isEmpty ? null : categories.first);
    });
  }

  /// Same add-category prompt and repository call as Settings, so a new
  /// user doesn't have to leave this form to make their first category.
  Future<void> _addCategory() async {
    final name = (await showNoriTextPrompt(
      context,
      title: 'New category',
      hint: 'e.g. Finance',
    ))?.trim();
    if (!mounted) return;
    var added = false;
    if (name != null && name.isNotEmpty) {
      added = await guardedAction(
        () => AppData.habitCategories.addCategory(name),
      );
      if (!mounted) return;
    }
    if (added) {
      setState(() {
        if (!_categories.contains(name)) _categories = [..._categories, name!];
        _selectedCategory = name;
      });
    }
    // The dropdown shows whatever it last emitted, i.e. "Add Category".
    _categoryFieldKey.currentState?.didChange(_selectedCategory);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    _minThresholdController.dispose();
    _quickLogController.dispose();
    _targetFocus.dispose();
    _quickLogFocus.dispose();
    _minThresholdFocus.dispose();
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
      } else if (previousFixedUnit != null &&
          currentUnit == previousFixedUnit) {
        // Only clear it if it still holds the auto-filled value from the
        // previous type — don't wipe something the user typed themselves.
        _unitController.clear();
      }
      if (!_supportsThreshold) _minThresholdEnabled = false;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final firstStart = addDays(dateOnly(now), -1);
    final lastDate = DateTime(now.year + 2);
    // showDatePicker asserts initialDate is within [firstDate, lastDate]:
    // an existing habit can have a start older than yesterday, and a new
    // start can land after the old end.
    DateTime within(DateTime? date, DateTime first, DateTime fallback) =>
        date == null || date.isBefore(first) || date.isAfter(lastDate)
        ? fallback
        : date;
    final start = await showDatePicker(
      context: context,
      initialDate: within(_startDate, firstStart, now),
      firstDate: firstStart,
      lastDate: lastDate,
    );
    if (start == null || !mounted) return;
    final defaultEnd = addDays(start, 30);
    final end = await showDatePicker(
      context: context,
      initialDate: within(
        _endDate,
        start,
        defaultEnd.isAfter(lastDate) ? lastDate : defaultEnd,
      ),
      firstDate: start,
      lastDate: lastDate,
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
        final step = defaultQuickLogStep(target);
        return '+${formatTrimmedNumber(step)}${unit.isEmpty ? '' : ' $unit'}';
    }
  }

  /// A plain amount ("250") or a share of [target] ("25%", which the
  /// field's own hint suggests). Stored as the absolute amount either way.
  /// Null if it isn't a positive number.
  double? _parseQuickLog(String text, double target) {
    final isPercent = text.endsWith('%');
    final number = _positiveNumber(
      isPercent ? text.substring(0, text.length - 1).trim() : text,
    );
    if (number == null) return null;
    final amount = isPercent ? target * number / 100 : number;
    return amount.isFinite ? amount : null;
  }

  String _dateRangeLabel() {
    if (_startDate == null || _endDate == null) {
      return 'Tap to choose a start & end date';
    }
    String format(DateTime d) => '${d.month}/${d.day}/${d.year}';
    return '${format(_startDate!)} – ${format(_endDate!)}';
  }

  /// [text] as a finite number above 0, else null. `double.tryParse`
  /// happily returns NaN or Infinity for "NaN"/"Infinity", and NaN slips
  /// past a plain `<= 0` check.
  static double? _positiveNumber(String text) {
    final value = double.tryParse(text);
    return value != null && value.isFinite && value > 0 ? value : null;
  }

  Future<void> _saveHabit() async {
    // Not while archive/delete is running: both end by popping this route.
    if (_isSaving || _isManaging) return;

    // The snackbar names the problem; [focus] (a text field) or [section] (a
    // non-text control) is then scrolled into view, and a text field also
    // takes focus so it shows its active border.
    void showError(String message, {FocusNode? focus, GlobalKey? section}) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      setState(() {
        _fieldErrors.clear();
        _customDaysError = null;
        if (focus != null) _fieldErrors[focus] = message;
        if (section == _customDaysKey) _customDaysError = message;
      });
      focus?.requestFocus();
      final target = focus?.context ?? section?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.25,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }

    final target = _positiveNumber(_targetController.text.trim());
    if (_needsTarget && target == null) {
      showError('Enter an ideal target greater than 0.', focus: _targetFocus);
      return;
    }

    // Optional fields: blank means "use the default", but anything typed
    // that doesn't parse is rejected rather than silently dropped.
    final quickLogText = _quickLogController.text.trim();
    double? quickLogAmount;
    if (_needsTarget && quickLogText.isNotEmpty) {
      quickLogAmount = _parseQuickLog(quickLogText, target!);
      if (quickLogAmount == null) {
        showError(
          'Quick-log amount must be a number above 0, like 250 or 25%.',
          focus: _quickLogFocus,
        );
        return;
      }
    }

    final minThresholdText = _minThresholdController.text.trim();
    double? minThreshold;
    if (_minThresholdEnabled &&
        _supportsThreshold &&
        minThresholdText.isNotEmpty) {
      minThreshold = _positiveNumber(minThresholdText);
      if (minThreshold == null) {
        showError(
          'Minimum threshold must be a number above 0.',
          focus: _minThresholdFocus,
        );
        return;
      }
      // Logging is capped at the target, so a minimum at or above it could
      // never be reached on its own.
      if (target != null && minThreshold >= target) {
        showError(
          'Minimum threshold must be below the ideal target.',
          focus: _minThresholdFocus,
        );
        return;
      }
    }

    if (_repeat == HabitRepeat.custom && _customDays.isEmpty) {
      showError(
        'Pick at least one day for a custom schedule.',
        section: _customDaysKey,
      );
      return;
    }

    setState(() => _isSaving = true);

    final enteredName = _nameController.text.trim();
    final unit = _needsTarget ? _unitController.text.trim() : null;

    final existing = widget.habit;
    final habit = Habit(
      id: existing?.id ?? _newHabitId,
      name: enteredName.isEmpty ? 'New Habit' : enteredName,
      subtitle:
          _selectedCategory ?? (_categories.isEmpty ? '' : _categories.first),
      icon: _selectedIcon,
      color: _selectedColor,
      xpReward: _difficulty.baseXp,
      coinReward: _difficulty.baseCoins,
      repeat: _repeat,
      type: _selectedType,
      difficulty: _difficulty,
      targetValue: _needsTarget ? target : null,
      unit: unit == null || unit.isEmpty ? null : unit,
      minThreshold: minThreshold,
      quickLogAmount: quickLogAmount,
      currentValue: existing?.currentValue ?? 0,
      customDays: _repeat == HabitRepeat.custom ? {..._customDays} : null,
      // No per-habit pause in the MVP (the global Vacation Mode in Settings
      // is the only one), so there's no control for this; an existing
      // habit's stored value just rides along.
      allowVacationFreeze: existing?.allowVacationFreeze ?? true,
      lastAwardedXp: existing?.lastAwardedXp ?? 0,
      lastAwardedCoins: existing?.lastAwardedCoins ?? 0,
      startDate: _endDateEnabled ? _startDate : null,
      endDate: _endDateEnabled ? _endDate : null,
      isCompletedToday: existing?.isCompletedToday ?? false,
    );

    final ok = await guardedAction(() async {
      if (_isEditing) {
        await AppData.habits.updateHabit(habit);
      } else {
        await AppData.habits.addHabit(habit);
      }
    });
    if (mounted) setState(() => _isSaving = false);
    if (!ok || !mounted) return;
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
              : (_isEditing ? 'Save changes' : 'Save habit'),
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
                      NoriScreenHeader(
                        leading: NoriScreenHeader.backButton(context),
                        title: _isEditing ? 'Edit habit' : 'New habit',
                        titleStyle: AppTextStyles.headlineLgMobile,
                      ),
                      const SizedBox(height: AppSpacing.stackMd),
                      _FieldLabel(label: 'Habit name'),
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
                      ScrollEdgeFade(
                        child: SingleChildScrollView(
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
                                  selectedColor: _selectedColor,
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
                      ),
                      const SizedBox(height: AppSpacing.stackMd),
                      _FieldLabel(label: 'Color'),
                      const SizedBox(height: AppSpacing.unit),
                      Wrap(
                        spacing: AppSpacing.stackSm,
                        runSpacing: AppSpacing.stackSm,
                        children: [
                          for (final color in _colors)
                            _ColorChoice(
                              color: color,
                              selected: _selectedColor == color,
                              onTap: () =>
                                  setState(() => _selectedColor = color),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.stackMd),
                      _FieldLabel(label: 'Category'),
                      const SizedBox(height: AppSpacing.unit),
                      DropdownButtonFormField<String>(
                        key: _categoryFieldKey,
                        initialValue: _selectedCategory,
                        isExpanded: true,
                        icon: const Icon(Icons.expand_more),
                        // New accounts start with no categories, so this is
                        // what a first-time user sees until they add one.
                        hint: Text(
                          'Choose or add a category',
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.inkFaint,
                          ),
                        ),
                        decoration: _fieldDecoration(),
                        items: [
                          // Keep an existing unknown subtitle selectable, including deleted categories,
                          // so saving does not silently replace it with the first category.
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
                          const DropdownMenuItem(
                            value: _addCategoryValue,
                            child: Row(
                              children: [
                                Icon(Icons.add, size: 18),
                                SizedBox(width: AppSpacing.unit),
                                Text('Add category'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (category) {
                          if (category == null) return;
                          if (category == _addCategoryValue) {
                            _addCategory();
                            return;
                          }
                          setState(() => _selectedCategory = category);
                        },
                      ),
                      // Only while there are none: it goes away the moment
                      // one is added, so it isn't a dismissible tip.
                      if (_categoriesLoaded && _categories.isEmpty) ...[
                        const SizedBox(height: AppSpacing.stackSm),
                        NoriInfoBanner(
                          icon: Icons.label_outline,
                          message:
                              'No categories yet. Add one to group your habits.',
                          actionLabel: 'Add one',
                          onAction: _addCategory,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.stackMd),
                      _FieldLabel(label: 'Tracking type'),
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
                        _FieldLabel(label: 'Ideal target'),
                        const SizedBox(height: AppSpacing.unit),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _targetController,
                                focusNode: _targetFocus,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(9),
                                ],
                                style: AppTextStyles.bodyLg,
                                onChanged: (_) => _clearError(_targetFocus),
                                decoration: _fieldDecoration(
                                  hintText: 'e.g. 1000',
                                  errorText: _fieldErrors[_targetFocus],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.stackSm),
                            Expanded(
                              child: TextField(
                                controller: _unitController,
                                enabled: !_fixedUnits.containsKey(
                                  _selectedType,
                                ),
                                textAlign: TextAlign.center,
                                style: AppTextStyles.bodyLg,
                                decoration: _fieldDecoration(hintText: 'unit'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.stackMd),
                        _FieldLabel(label: 'Quick-log amount'),
                        const SizedBox(height: AppSpacing.unit),
                        TextField(
                          controller: _quickLogController,
                          focusNode: _quickLogFocus,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppTextStyles.bodyLg,
                          onChanged: (_) => _clearError(_quickLogFocus),
                          decoration: _fieldDecoration(
                            hintText: _quickLogHint(),
                            errorText: _fieldErrors[_quickLogFocus],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'What the quick-log button on Home/Habits adds per tap. '
                          'Leave blank for the default (${_quickLogHint()}).',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.inkFaint,
                          ),
                        ),
                      ],
                      if (_supportsThreshold) ...[
                        const SizedBox(height: AppSpacing.stackMd),
                        _ToggleRow(
                          title: 'Minimum threshold',
                          subtitle: 'Streak protection',
                          value: _minThresholdEnabled,
                          onChanged: (value) =>
                              setState(() => _minThresholdEnabled = value),
                        ),
                        if (_minThresholdEnabled) ...[
                          const SizedBox(height: AppSpacing.stackSm),
                          TextField(
                            controller: _minThresholdController,
                            focusNode: _minThresholdFocus,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: AppTextStyles.bodyLg,
                            onChanged: (_) => _clearError(_minThresholdFocus),
                            decoration: _fieldDecoration(
                              hintText: 'e.g. 750',
                              errorText: _fieldErrors[_minThresholdFocus],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.stackSm),
                          const NoriInfoBanner(
                            icon: Icons.eco,
                            message:
                                "Keeps your streak alive on days you reach this but not the full target. No XP on its own — claim the habit to earn that.",
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
                      // Dismissable once per account, like the other hints.
                      const OneTimeHint(
                        tip: Tip.adaptiveXp,
                        icon: Icons.bolt,
                        message:
                            'Adaptive XP: a habit pays a bit more while you struggle with it and a bit less once it comes easy (Easy 9–13, Medium 16–24, Hard 26–36 XP).',
                      ),
                      _RewardPreview(
                        difficulty: _difficulty,
                        adaptiveMultiplier:
                            widget.habit?.adaptiveMultiplier ?? 1.0,
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
                          key: _customDaysKey,
                          spacing: AppSpacing.unit,
                          runSpacing: AppSpacing.unit,
                          children: [
                            for (var day = 1; day <= 7; day++)
                              _DayCircle(
                                label: weekdayInitial(day),
                                selected: _customDays.contains(day),
                                onTap: () => setState(() {
                                  _customDaysError = null;
                                  if (!_customDays.remove(day)) {
                                    _customDays.add(day);
                                  }
                                }),
                              ),
                          ],
                        ),
                        if (_customDaysError != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _customDaysError!,
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: AppSpacing.stackMd),
                      _ToggleRow(
                        title: 'Set end date',
                        subtitle:
                            'Hides the habit from your list after this date.',
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
                                const Icon(
                                  Icons.date_range,
                                  color: AppColors.inkMuted,
                                ),
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
                      if (_isEditing) ...[
                        const SizedBox(height: AppSpacing.stackLg),
                        _ManageHabitSection(
                          canDelete:
                              (_activeDays ?? kMaxDeletableActiveDays + 1) <=
                              kMaxDeletableActiveDays,
                          busy: _isManaging || _isSaving,
                          onArchive: _archiveHabit,
                          onDelete: _deleteHabit,
                        ),
                      ],
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

  Future<void> _archiveHabit() async {
    final habit = widget.habit;
    if (habit == null) return;
    setState(() => _isManaging = true);
    final ok = await guardedAction(() => AppData.habits.archiveHabit(habit.id));
    if (!mounted) return;
    setState(() => _isManaging = false);
    if (!ok) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Archived "${habit.name}" — restore it from Settings > Archived habits.',
          ),
        ),
      );
    Navigator.pop(context, true);
  }

  Future<void> _deleteHabit() async {
    final habit = widget.habit;
    if (habit == null || !await confirmDeleteHabit(context, habit)) return;
    if (!mounted) return;
    setState(() => _isManaging = true);
    final ok = await guardedAction(() => AppData.habits.deleteHabit(habit.id));
    if (!mounted) return;
    setState(() => _isManaging = false);
    if (ok) Navigator.pop(context, true);
  }

  InputDecoration _fieldDecoration({String? hintText, String? errorText}) {
    return InputDecoration(
      hintText: hintText,
      errorText: errorText,
      errorMaxLines: 3,
      errorStyle: AppTextStyles.labelSm.copyWith(color: AppColors.error),
      hintStyle: AppTextStyles.bodyLg.copyWith(color: AppColors.inkFaint),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.containerPaddingMobile,
        vertical: AppSpacing.gutter,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(
          color: AppColors.ink,
          width: AppBorder.thin,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(
          color: AppColors.ink,
          width: AppBorder.thin,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(
          color: AppColors.ink,
          width: AppBorder.standard,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: AppBorder.standard,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: AppBorder.standard,
        ),
      ),
    );
  }

  /// Drops the red message under [focus]'s field once the person edits it.
  void _clearError(FocusNode focus) {
    if (_fieldErrors.containsKey(focus)) {
      setState(() => _fieldErrors.remove(focus));
    }
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
    required this.selectedColor,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  // The habit's chosen color, so the selected icon previews its badge.
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor : AppColors.white,
      shape: CircleBorder(
        side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: 64,
          child: Icon(icon, size: 30, color: AppColors.ink),
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: CircleBorder(
        side: BorderSide(
          color: AppColors.ink,
          width: selected ? AppBorder.thick : AppBorder.thin,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: const SizedBox.square(dimension: 40)),
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
      // DESIGN.md §4: selection = mossLight fill + thicker border. This was
      // the one picker on the screen using solid moss, which also dropped
      // the muted description text to ~3.5:1.
      color: selected ? AppColors.mossLight : AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.stackSm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: AppColors.ink,
              width: selected ? AppBorder.thick : AppBorder.thin,
            ),
          ),
          child: Row(
            children: [
              Icon(_typeIcon(type), color: AppColors.ink, size: 22),
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
                      // 3 lines: "Track an amount, e.g. ml, pages, or
                      // minutes" was being cut to "minut…" at 2.
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.inkFaint,
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
      color: selected ? AppColors.mossLight : AppColors.white,
      shape: CircleBorder(
        side: BorderSide(
          color: AppColors.ink,
          width: selected ? AppBorder.thick : AppBorder.thin,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox.square(
          dimension: 36,
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.labelLg.copyWith(color: AppColors.ink),
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
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _RewardPreview extends StatelessWidget {
  const _RewardPreview({
    required this.difficulty,
    this.adaptiveMultiplier = 1.0,
  });

  final HabitDifficulty difficulty;

  /// Existing habit's per-claim multiplier, or 1.0 for a new habit.
  /// Keeps the preview aligned with the Habits screen's reward pill.
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
                  '+$coins coins · Pet care & shop',
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

/// Archive (always) and Delete (only for a habit with almost no history) at
/// the bottom of the edit form. See docs/technical/BACKEND.md, "Deleting vs.
/// archiving a habit".
class _ManageHabitSection extends StatelessWidget {
  const _ManageHabitSection({
    required this.canDelete,
    required this.busy,
    required this.onArchive,
    required this.onDelete,
  });

  final bool canDelete;
  final bool busy;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TactileButton(
          label: 'Archive habit',
          icon: Icons.archive_outlined,
          backgroundColor: AppColors.white,
          onPressed: busy ? null : onArchive,
        ),
        const SizedBox(height: AppSpacing.unit),
        Text(
          'Hides it from today on. Its history stays, and you can restore it '
          'from Settings > Archived habits.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.inkMuted),
          textAlign: TextAlign.center,
        ),
        if (canDelete) ...[
          const SizedBox(height: AppSpacing.stackMd),
          TactileButton(
            label: 'Delete habit',
            icon: Icons.delete_outline,
            backgroundColor: AppColors.errorContainer,
            foregroundColor: AppColors.onErrorContainer,
            onPressed: busy ? null : onDelete,
          ),
        ],
      ],
    );
  }
}
