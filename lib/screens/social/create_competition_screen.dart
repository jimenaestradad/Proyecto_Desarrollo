import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/models/competition.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/widgets/circular_icon_button.dart';
import 'package:nori/widgets/nori_choice_chip.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_text_field.dart';
import 'package:nori/widgets/tactile_button.dart';
import 'package:nori/screens/social/add_friend_screen.dart';
import 'package:nori/screens/social/competition_detail_screen.dart';

class CreateCompetitionScreen extends StatefulWidget {
  const CreateCompetitionScreen({
    super.key,
    this.presetCircleId,
    this.rematchOf,
  });
  final String? presetCircleId;

  /// A finished competition to run again: its format and the people who
  /// were in it come pre-filled, opening on the final review step.
  final Competition? rematchOf;
  @override
  State<CreateCompetitionScreen> createState() =>
      _CreateCompetitionScreenState();
}

class _CreateCompetitionScreenState extends State<CreateCompetitionScreen>
    with
        RemoteLoadState<CreateCompetitionScreen>,
        SocialLoadState<CreateCompetitionScreen> {
  late final _name = TextEditingController(
    text: widget.rematchOf == null
        ? 'Water streak'
        : 'Rematch: ${widget.rematchOf!.title}',
  );
  List<SocialUser> _friends = [];
  List<SocialCircle> _circles = [];
  Set<String> _invitees = {};
  String? _circleId;
  String _audience = 'all';
  bool _initialized = false;
  bool _launching = false;
  late int _step = widget.rematchOf == null ? 0 : 3;
  late CompetitionType _type = widget.rematchOf?.type ?? CompetitionType.streak;
  late int _habitIndex = _rematchHabitIndex();
  late int _target = widget.rematchOf?.targetCount ?? 7;
  late int _duration = widget.rematchOf?.durationDays ?? 7;
  // Competition types, targets, and duration choices are mock product rules.
  static const _habits = [
    (name: 'Water', icon: Icons.water_drop, color: AppColors.sky),
    (name: 'Gym', icon: Icons.fitness_center, color: AppColors.blushPink),
    (name: 'Reading', icon: Icons.menu_book, color: AppColors.mustardLight),
    (
      name: 'Meditate',
      icon: Icons.self_improvement,
      color: AppColors.mossLight,
    ),
    (name: 'Running', icon: Icons.directions_run, color: AppColors.blush),
    (
      name: 'No social media',
      icon: Icons.phonelink_off,
      color: AppColors.linenAlt,
    ),
  ];
  int _rematchHabitIndex() {
    final index = _habits.indexWhere(
      (h) => h.name == widget.rematchOf?.habitName,
    );
    return index < 0 ? 0 : index;
  }

  @override
  Future<void> loadSocial() async {
    final friends = await AppData.social.getFriends();
    final circles = await AppData.social.getCircles();
    if (!mounted) return;
    setState(() {
      _friends = friends;
      _circles = circles;
      if (!_initialized) {
        final preset = circles
            .where((c) => c.id == widget.presetCircleId)
            .firstOrNull;
        final rematch = widget.rematchOf;
        if (rematch != null) {
          // The same people (only those still friends), under the same
          // circle when it still exists.
          final circle = circles
              .where((c) => c.id == rematch.circleId)
              .firstOrNull;
          _circleId = circle?.id;
          _audience = circle?.id ?? 'pick';
          _invitees = friends
              .where((f) => rematch.participantIds.contains(f.id))
              .map((f) => f.id)
              .toSet();
          _initialized = true;
          return;
        }
        _circleId = preset?.id;
        _audience = preset?.id ?? 'all';
        _invitees = preset == null
            ? friends.map((f) => f.id).toSet()
            : friends
                  .where((f) => preset.memberIds.contains(f.id))
                  .map((f) => f.id)
                  .toSet();
        _initialized = true;
      } else {
        if (_audience == 'all') {
          _invitees = friends.map((f) => f.id).toSet();
        } else if (_audience == 'pick') {
          _invitees.retainAll(friends.map((f) => f.id));
        } else {
          final circle = circles.where((c) => c.id == _circleId).firstOrNull;
          _invitees = friends
              .where((f) => circle?.memberIds.contains(f.id) ?? false)
              .map((f) => f.id)
              .toSet();
          if (circle == null) {
            _circleId = null;
            _audience = 'pick';
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _back() {
    if (_launching) return;
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  void _audienceChanged(String audience) => setState(() {
    _audience = audience;
    _circleId = audience == 'all' || audience == 'pick' ? null : audience;
    if (audience == 'all') _invitees = _friends.map((f) => f.id).toSet();
    if (_circleId != null) {
      final circle = _circles.firstWhere((c) => c.id == _circleId);
      _invitees = _friends
          .where((f) => circle.memberIds.contains(f.id))
          .map((f) => f.id)
          .toSet();
    }
  });
  Future<void> _launch() async {
    if (_launching || _name.text.trim().isEmpty || _invitees.isEmpty) return;
    setState(() => _launching = true);
    Competition? created;
    final habit = _habits[_habitIndex];
    final success = await guardedAction(() async {
      created = await AppData.social.createCompetition(
        CompetitionDraft(
          title: _name.text.trim(),
          type: _type,
          habitName: habit.name,
          icon: habit.icon,
          color: habit.color,
          targetCount: _target,
          durationDays: _duration,
          inviteeIds: _invitees.toList(),
          circleId: _circleId,
        ),
      );
    });
    if (!mounted) return;
    setState(() => _launching = false);
    if (success && created != null) {
      showSocialToast(context, 'Competition launched');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CompetitionDetailScreen(competitionId: created!.id),
        ),
      );
    }
  }

  Widget _title(String title) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.stackSm),
    child: Text(title, style: AppTextStyles.headlineLgMobile),
  );

  List<Widget> _stepContent() => switch (_step) {
    0 => [
      _title('Choose your challenge'),
      for (final type in CompetitionType.values) ...[
        Semantics(
          button: true,
          selected: _type == type,
          child: GestureDetector(
            onTap: () => setState(() {
              final oldSuggestion =
                  '${_habits[_habitIndex].name} ${_type.label.toLowerCase()}';
              _type = type;
              if (_name.text == oldSuggestion) {
                _name.text =
                    '${_habits[_habitIndex].name} ${type.label.toLowerCase()}';
              }
            }),
            child: NoriCard(
              color: _type == type ? AppColors.mossLight : AppColors.white,
              borderWidth: _type == type ? AppBorder.thick : AppBorder.standard,
              child: Row(
                children: [
                  NoriIconBadge(
                    icon: type.icon,
                    background: AppColors.mustardLight,
                    size: 40,
                    iconSize: 24,
                  ),
                  const SizedBox(width: AppSpacing.stackSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(type.label, style: AppTextStyles.labelLg),
                        Text(type.blurb, style: AppTextStyles.bodyMd),
                      ],
                    ),
                  ),
                  if (_type == type)
                    const Icon(Icons.check_circle, color: AppColors.mossDark),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.stackSm),
      ],
      NoriTextField(
        controller: _name,
        label: 'Competition name',
        hint: 'Name your challenge',
        icon: Icons.edit_outlined,
        onChanged: (_) => setState(() {}),
      ),
    ],
    1 => [
      _title('Habit & target'),
      Wrap(
        spacing: AppSpacing.unit,
        runSpacing: AppSpacing.unit,
        children: [
          for (var i = 0; i < _habits.length; i++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NoriIconBadge(
                  icon: _habits[i].icon,
                  background: _habits[i].color,
                  size: 32,
                  iconSize: 20,
                  circle: true,
                ),
                const SizedBox(width: AppSpacing.unit / 2),
                NoriChoiceChip(
                  label: _habits[i].name,
                  selected: _habitIndex == i,
                  onTap: () => setState(() {
                    final suggestion =
                        '${_habits[_habitIndex].name} ${_type.label.toLowerCase()}';
                    _habitIndex = i;
                    if (_name.text == suggestion) {
                      _name.text =
                          '${_habits[i].name} ${_type.label.toLowerCase()}';
                    }
                  }),
                ),
              ],
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.stackMd),
      NoriCard(
        color: _habits[_habitIndex].color,
        child: Column(
          children: [
            Text(switch (_type) {
              CompetitionType.streak => 'Days in a row',
              CompetitionType.total => 'Completions',
              CompetitionType.race => 'First to',
            }, style: AppTextStyles.labelLg),
            const SizedBox(height: AppSpacing.stackSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: 'Decrease target',
                  onPressed: _target > 1
                      ? () => setState(() => _target--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_target', style: AppTextStyles.display),
                CircularIconButton(
                  icon: Icons.add,
                  tooltip: 'Increase target',
                  onPressed: () => setState(() => _target++),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
    2 => [
      _title('Choose a duration'),
      Wrap(
        spacing: AppSpacing.unit,
        runSpacing: AppSpacing.unit,
        children: [
          for (final days in [3, 7, 14])
            NoriChoiceChip(
              label: '$days days',
              selected: _duration == days,
              onTap: () => setState(() => _duration = days),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.stackMd),
      NoriCard(
        color: AppColors.mossLight,
        child: Row(
          children: [
            const Icon(Icons.today),
            const SizedBox(width: AppSpacing.unit),
            Expanded(
              child: Text(
                'Starts today · Runs for $_duration days',
                style: AppTextStyles.bodyMd,
              ),
            ),
          ],
        ),
      ),
    ],
    _ => [
      _title('Invite your friends'),
      if (_friends.isEmpty)
        NoriEmptyState(
          icon: Icons.person_add_outlined,
          title: 'Find your competition crew',
          message: 'Add a friend before launching a competition.',
          actionLabel: 'Add friends',
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddFriendScreen()),
          ),
        )
      else ...[
        Wrap(
          spacing: AppSpacing.unit,
          runSpacing: AppSpacing.unit,
          children: [
            NoriChoiceChip(
              label: 'All friends',
              selected: _audience == 'all',
              onTap: () => _audienceChanged('all'),
            ),
            for (final circle in _circles)
              NoriChoiceChip(
                label: circle.name,
                icon: circle.icon,
                selected: _audience == circle.id,
                onTap: () => _audienceChanged(circle.id),
              ),
            NoriChoiceChip(
              label: 'Hand-pick friends',
              icon: Icons.checklist,
              selected: _audience == 'pick',
              onTap: () => _audienceChanged('pick'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.stackSm),
        if (_audience == 'pick')
          for (final friend in _friends) ...[
            PersonRow(
              user: friend,
              highlighted: _invitees.contains(friend.id),
              subtitle: _invitees.contains(friend.id)
                  ? 'Invited'
                  : 'Tap to invite',
              trailing: Icon(
                _invitees.contains(friend.id)
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: AppColors.ink,
              ),
              onTap: () => setState(() {
                if (!_invitees.remove(friend.id)) _invitees.add(friend.id);
              }),
            ),
            const SizedBox(height: AppSpacing.unit),
          ],
        Text(
          '${_invitees.length} friends selected',
          style: AppTextStyles.labelLg,
        ),
        if (_invitees.isEmpty)
          Text(
            'Select at least one friend to launch.',
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.error),
          ),
      ],
      const SizedBox(height: AppSpacing.stackMd),
      _title('Review competition'),
      NoriCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_name.text.trim(), style: AppTextStyles.headlineLgMobile),
            Text(
              '${_type.label} · ${_habits[_habitIndex].name}',
              style: AppTextStyles.bodyMd,
            ),
            Text(
              'Target: $_target · $_duration days · Starts today',
              style: AppTextStyles.bodyMd,
            ),
            Text(
              'Inviting: ${_friends.where((f) => _invitees.contains(f.id)).map((f) => f.firstName).join(', ')}',
              style: AppTextStyles.bodyMd,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.stackSm),
      NoriCard(
        color: AppColors.mustardLight,
        child: Row(
          children: [
            const Icon(Icons.photo_camera),
            const SizedBox(width: AppSpacing.unit),
            Expanded(
              child: Text(
                'Proof photo required to count',
                style: AppTextStyles.labelLg,
              ),
            ),
          ],
        ),
      ),
    ],
  };
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _step == 0 && !_launching,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _back();
    },
    child: Scaffold(
      body: SafeArea(
        child: buildLoaded(
          (context) => NoriScrollScaffold(
            maxWidth: 800,
            children: [
              NoriScreenHeader(
                leading: IconButton(
                  onPressed: _launching ? null : _back,
                  tooltip: _step == 0 ? 'Cancel' : 'Previous step',
                  icon: const Icon(Icons.arrow_back),
                ),
                title: 'New competition',
                titleStyle: AppTextStyles.headlineLgMobile,
              ),
              const SizedBox(height: AppSpacing.stackMd),
              Row(
                children: [
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.unit / 2,
                        ),
                        child: NoriCard(
                          radius: AppRadius.full,
                          color: i <= _step
                              ? AppColors.mossLight
                              : AppColors.linenAlt,
                          borderWidth: i == _step
                              ? AppBorder.thick
                              : AppBorder.thin,
                          padding: const EdgeInsets.all(AppSpacing.unit),
                          child: Center(
                            child: i < _step
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: AppColors.ink,
                                  )
                                : Text(
                                    '${i + 1}',
                                    style: AppTextStyles.labelSm,
                                  ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.unit),
              Text(
                'Step ${_step + 1} of 4',
                style: AppTextStyles.labelSm,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.stackMd),
              ..._stepContent(),
              const SizedBox(height: AppSpacing.stackMd),
              TactileButton(
                label: _launching
                    ? 'Launching...'
                    : _step == 3
                    ? 'Launch competition'
                    : 'Next',
                icon: _step == 3 ? Icons.rocket_launch : Icons.arrow_forward,
                onPressed:
                    _launching ||
                        _name.text.trim().isEmpty ||
                        (_step == 3 && _invitees.isEmpty)
                    ? null
                    : _step == 3
                    ? _launch
                    : () => setState(() => _step++),
              ),
              if (_step > 0)
                TextButton(
                  onPressed: _launching ? null : _back,
                  child: const Text('Back'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
