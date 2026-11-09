import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/screens/social/friends_screen.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/nori_bottom_sheet.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/nori_text_field.dart';
import 'package:nori/widgets/section_header.dart';
import 'package:nori/widgets/tactile_button.dart';

class CircleEditorScreen extends StatefulWidget {
  const CircleEditorScreen({super.key, this.circleId});
  final String? circleId;

  @override
  State<CircleEditorScreen> createState() => _CircleEditorScreenState();
}

class _CircleEditorScreenState extends State<CircleEditorScreen>
    with
        RemoteLoadState<CircleEditorScreen>,
        SocialLoadState<CircleEditorScreen> {
  static const _icons = <(IconData, String)>[
    (Icons.groups, 'Groups'),
    (Icons.cottage, 'Home'),
    (Icons.fitness_center, 'Fitness'),
    (Icons.menu_book, 'Reading'),
    (Icons.school, 'School'),
    (Icons.work, 'Work'),
    (Icons.sports_esports, 'Games'),
    (Icons.restaurant, 'Food'),
    (Icons.self_improvement, 'Mindfulness'),
    (Icons.pets, 'Pets'),
  ];
  static const _colors = <(Color, String)>[
    (AppColors.mossLight, 'Moss'),
    (AppColors.mustardLight, 'Mustard'),
    (AppColors.blushPink, 'Pink'),
    (AppColors.sky, 'Sky'),
    (AppColors.blush, 'Blush'),
  ];
  final _name = TextEditingController();
  final Set<String> _members = {};
  List<SocialUser> _friends = [];
  SocialCircle? _circle;
  IconData _icon = Icons.groups;
  Color _color = AppColors.mossLight;
  bool _initialized = false;
  bool _saving = false;
  bool get _editing => widget.circleId != null;

  @override
  Future<void> loadSocial() async {
    final friends = await AppData.social.getFriends();
    SocialCircle? circle;
    if (_editing) {
      final circles = await AppData.social.getCircles();
      for (final item in circles) {
        if (item.id == widget.circleId) circle = item;
      }
    }
    if (!mounted) return;
    setState(() {
      _friends = friends;
      _circle = circle;
      if (!_initialized) {
        if (circle != null) {
          _name.text = circle.name;
          _icon = circle.icon;
          _color = circle.color;
          _members.addAll(circle.memberIds.where((id) => id != 'me'));
        }
        _initialized = true;
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (_saving || name.isEmpty) return;
    setState(() => _saving = true);
    final success = await guardedAction(() async {
      if (_editing) {
        await AppData.social.updateCircle(
          _circle!.copyWith(
            name: name,
            icon: _icon,
            color: _color,
            memberIds: ['me', ..._members],
          ),
        );
      } else {
        await AppData.social.createCircle(
          name: name,
          icon: _icon,
          color: _color,
          memberIds: _members.toList(),
        );
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      showSocialToast(context, _editing ? 'Circle updated' : 'Circle created');
      Navigator.pop(context);
    }
  }

  Future<void> _leave() async {
    if (_saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
        ),
        title: Text(
          'Leave ${_circle!.name}?',
          style: AppTextStyles.headlineLgMobile,
        ),
        content: Text(
          'This circle will be removed from your circles.',
          style: AppTextStyles.bodyMd,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: AppTextStyles.labelLg),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Leave circle', style: AppTextStyles.labelLg),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    final success = await guardedAction(
      () => AppData.social.leaveCircle(widget.circleId!),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (success) {
      showSocialToast(context, 'Left circle');
      final navigator = Navigator.of(context);
      navigator.pop();
      if (navigator.canPop()) navigator.pop();
    }
  }

  void _toggleMember(String id) => setState(() {
    if (!_members.add(id)) _members.remove(id);
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: buildLoaded(
        (context) => NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: _editing ? 'Edit circle' : 'New circle',
              titleStyle: AppTextStyles.headlineLgMobile,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (_editing && _circle == null)
              const NoriEmptyState(
                icon: Icons.groups_outlined,
                title: 'Circle unavailable',
                message: 'This circle is no longer in your circles.',
              )
            else ...[
              NoriTextField(
                controller: _name,
                label: 'Circle name',
                hint: 'Give your circle a name',
                icon: Icons.groups,
                onChanged: (_) => setState(() {}),
              ),
              SectionHeader(
                title: 'Choose an icon',
                trailing: const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              Wrap(
                spacing: AppSpacing.unit,
                runSpacing: AppSpacing.unit,
                children: [
                  for (final (icon, label) in _icons)
                    Semantics(
                      button: true,
                      selected: _icon == icon,
                      label: label,
                      child: Tooltip(
                        message: label,
                        child: InkWell(
                          onTap: () => setState(() => _icon = icon),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: NoriCard(
                            padding: const EdgeInsets.all(AppSpacing.unit),
                            color: _icon == icon ? _color : AppColors.white,
                            borderWidth: _icon == icon
                                ? AppBorder.thick
                                : AppBorder.thin,
                            child: NoriIconBadge(
                              icon: icon,
                              background: _color,
                              size: 32,
                              iconSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.stackMd),
              SectionHeader(
                title: 'Choose a color',
                trailing: const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              Wrap(
                spacing: AppSpacing.stackSm,
                runSpacing: AppSpacing.unit,
                children: [
                  for (final (color, label) in _colors)
                    Semantics(
                      button: true,
                      selected: _color == color,
                      label: label,
                      child: Tooltip(
                        message: label,
                        child: InkWell(
                          onTap: () => setState(() => _color = color),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.ink,
                                width: _color == color
                                    ? AppBorder.thick
                                    : AppBorder.thin,
                              ),
                            ),
                            child: _color == color
                                ? const Icon(Icons.check, color: AppColors.ink)
                                : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.stackMd),
              SectionHeader(
                title: 'Members',
                trailing: Text(
                  '${_members.length} selected',
                  style: AppTextStyles.labelSm,
                ),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              Text(
                'You are always included.',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              if (_friends.isEmpty)
                NoriEmptyState(
                  icon: Icons.person_add_outlined,
                  title: 'No friends to add yet',
                  message: 'Find friends to invite into your circle.',
                  actionLabel: 'Find friends',
                  onAction: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const FriendsScreen(),
                    ),
                  ),
                )
              else
                for (final friend in _friends) ...[
                  PersonRow(
                    user: friend,
                    highlighted: _members.contains(friend.id),
                    onTap: () => _toggleMember(friend.id),
                    trailing: Checkbox(
                      value: _members.contains(friend.id),
                      activeColor: AppColors.moss,
                      checkColor: AppColors.ink,
                      side: const BorderSide(
                        color: AppColors.ink,
                        width: AppBorder.thin,
                      ),
                      onChanged: (_) => _toggleMember(friend.id),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.stackSm),
                ],
              const SizedBox(height: AppSpacing.stackMd),
              TactileButton(
                label: _saving
                    ? 'Saving...'
                    : _editing
                    ? 'Save changes'
                    : 'Create circle',
                onPressed: _saving || _name.text.trim().isEmpty ? null : _save,
              ),
              if (_editing) ...[
                const SizedBox(height: AppSpacing.stackMd),
                NoriSheetAction(
                  icon: Icons.logout,
                  label: 'Leave circle',
                  destructive: true,
                  onTap: _leave,
                ),
              ],
            ],
          ],
        ),
      ),
    ),
  );
}
