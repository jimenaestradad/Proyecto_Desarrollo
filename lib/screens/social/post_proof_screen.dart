import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nori/utils/photo_picker.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/competition.dart';
import 'package:nori/models/social_content.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_choice_chip.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/widgets/nori_icon_badge.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/section_header.dart';
import 'package:nori/widgets/tactile_button.dart';

class PostProofScreen extends StatefulWidget {
  const PostProofScreen({super.key, this.competitionId});
  final String? competitionId;
  @override
  State<PostProofScreen> createState() => _PostProofScreenState();
}

class _PostProofScreenState extends State<PostProofScreen>
    with RemoteLoadState<PostProofScreen>, SocialLoadState<PostProofScreen> {
  List<ProofableHabit> _habits = [];
  List<SocialCircle> _circles = [];
  Competition? _competition;
  ProofableHabit? _habit;
  PostVisibility _visibility = PostVisibility.allFriends;
  String? _circleId;
  bool _initialized = false;
  bool _withPhoto = false;
  Uint8List? _photo;
  bool _publishing = false;
  final _caption = TextEditingController();

  @override
  Future<void> loadSocial() async {
    final habits = await AppData.social.getProofableHabits();
    final circles = await AppData.social.getCircles();
    final privacy = await AppData.social.getPrivacy();
    final id = widget.competitionId;
    final competition = id == null
        ? null
        : await AppData.social.getCompetition(id);
    if (!mounted) return;
    setState(() {
      _habits = habits;
      _circles = circles;
      _competition = competition;
      if (competition != null) {
        _habit = ProofableHabit(
          id: competition.id,
          name: competition.habitName,
          icon: competition.icon,
          color: competition.color,
        );
      } else if (_habit == null || !habits.any((h) => h.id == _habit!.id)) {
        _habit = habits.isEmpty ? null : habits.first;
      }
      if (!_initialized) {
        // Mock privacy scopes map to one selected circle for a new post.
        _visibility = switch (privacy.defaultPostVisibility) {
          ActivityVisibility.allFriends => PostVisibility.allFriends,
          ActivityVisibility.onlyMe => PostVisibility.onlyMe,
          ActivityVisibility.circlesOnly =>
            circles.isEmpty ? PostVisibility.onlyMe : PostVisibility.circle,
        };
        _circleId = _visibility == PostVisibility.circle
            ? circles.first.id
            : null;
        _initialized = true;
      }
      if (_visibility == PostVisibility.circle &&
          !circles.any((c) => c.id == _circleId)) {
        _visibility = PostVisibility.onlyMe;
        _circleId = null;
      }
    });
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final bytes = await pickPhoto(context);
    if (bytes == null || !mounted) return;
    setState(() {
      _photo = bytes;
      _withPhoto = true;
    });
  }

  Future<void> _publish() async {
    final habit = _habit;
    final competition = _competition;
    if (_publishing ||
        habit == null ||
        _habits.isEmpty ||
        (competition != null &&
            (!_withPhoto ||
                competition.submittedToday ||
                competition.status != CompetitionStatus.active))) {
      return;
    }
    setState(() => _publishing = true);
    final success = await guardedAction(() async {
      if (competition != null) {
        await AppData.social.submitCompetitionProof(
          competition.id,
          caption: _caption.text.trim(),
          withPhoto: _withPhoto,
          photo: _photo,
        );
      } else {
        await AppData.social.createPost(
          habit: habit,
          caption: _caption.text.trim(),
          withPhoto: _withPhoto,
          photo: _photo,
          visibility: _visibility,
          circleId: _visibility == PostVisibility.circle ? _circleId : null,
        );
      }
    });
    if (!mounted) return;
    if (success) {
      showSocialToast(
        context,
        competition == null ? 'Proof shared' : 'Counted!',
      );
      Navigator.pop(context);
    } else {
      setState(() => _publishing = false);
    }
  }

  void _shareWith(PostVisibility visibility, [String? circleId]) =>
      setState(() {
        _visibility = visibility;
        _circleId = circleId;
      });

  Widget _heading(String title, IconData icon) => SectionHeader(
    title: title,
    icon: icon,
    trailing: const SizedBox.shrink(),
  );

  Widget _habitTile(ProofableHabit habit, {bool locked = false}) {
    final selected = habit.id == _habit?.id;
    return Semantics(
      button: !locked,
      selected: selected,
      child: GestureDetector(
        onTap: locked || _publishing
            ? null
            : () => setState(() => _habit = habit),
        child: NoriCard(
          color: selected ? AppColors.mossLight : AppColors.white,
          borderWidth: selected ? AppBorder.thick : AppBorder.standard,
          padding: const EdgeInsets.all(AppSpacing.stackSm),
          child: Row(
            children: [
              NoriIconBadge(
                icon: habit.icon,
                background: habit.color,
                size: 40,
                iconSize: 24,
              ),
              const SizedBox(width: AppSpacing.stackSm),
              Expanded(child: Text(habit.name, style: AppTextStyles.labelLg)),
              const SizedBox(width: AppSpacing.unit),
              Icon(
                locked
                    ? Icons.lock_outline
                    : selected
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: AppColors.ink,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.linen,
    body: SafeArea(
      child: buildLoaded((context) {
        final competition = _competition;
        final habit = _habit;
        return NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: widget.competitionId == null
                  ? 'Share proof'
                  : 'Submit proof',
              titleStyle: AppTextStyles.headlineLgMobile,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (competition?.submittedToday == true)
              const NoriEmptyState(
                icon: Icons.check_circle_outline,
                title: 'Already submitted today',
                message: 'Your proof has counted. Come back tomorrow.',
              )
            else if (competition != null &&
                competition.status != CompetitionStatus.active)
              const NoriEmptyState(
                icon: Icons.event_busy,
                title: 'Submissions unavailable',
                message: 'Proof can be submitted to active competitions.',
              )
            else if (_habits.isEmpty)
              const NoriEmptyState(
                icon: Icons.task_alt,
                title: 'No completed habits yet',
                message:
                    'Complete a habit today, then come back to share your proof.',
              )
            else ...[
              _heading('Select completed habit', Icons.task_alt),
              const SizedBox(height: AppSpacing.stackSm),
              if (competition != null && habit != null) ...[
                _habitTile(habit, locked: true),
                const SizedBox(height: AppSpacing.unit),
                Text(
                  'Proof required for ${competition.title}',
                  style: AppTextStyles.bodyMd,
                ),
              ] else
                for (final h in _habits) ...[
                  _habitTile(h),
                  const SizedBox(height: AppSpacing.stackSm),
                ],
              const SizedBox(height: AppSpacing.stackMd),
              _heading('Proof photo', Icons.photo_camera_outlined),
              const SizedBox(height: AppSpacing.stackSm),
              if (_withPhoto && habit != null) ...[
                ProofPhoto(
                  icon: habit.icon,
                  color: habit.color,
                  label: 'Proof attached',
                  bytes: _photo,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _publishing
                        ? null
                        : () => setState(() {
                            _withPhoto = false;
                            _photo = null;
                          }),
                    icon: const Icon(Icons.close),
                    label: Text('Remove', style: AppTextStyles.labelLg),
                  ),
                ),
              ] else
                Semantics(
                  button: true,
                  label: 'Capture or upload proof',
                  child: InkWell(
                    onTap: _publishing ? null : _pickProof,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: NoriCard(
                      color: AppColors.linenAlt,
                      borderColor: AppColors.inkFaint,
                      borderWidth: AppBorder.thin,
                      padding: const EdgeInsets.all(AppSpacing.stackMd),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.add_a_photo_outlined,
                            size: 40,
                            color: AppColors.inkFaint,
                          ),
                          const SizedBox(height: AppSpacing.stackSm),
                          Text(
                            'Tap to capture or upload proof',
                            style: AppTextStyles.bodyMd,
                            textAlign: TextAlign.center,
                          ),
                          if (widget.competitionId != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'A timestamp is added automatically.',
                              style: AppTextStyles.labelSm,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.stackMd),
              _heading('Caption', Icons.edit_outlined),
              const SizedBox(height: AppSpacing.stackSm),
              TextField(
                controller: _caption,
                minLines: 3,
                maxLines: 5,
                enabled: !_publishing,
                style: AppTextStyles.bodyMd,
                decoration: InputDecoration(
                  hintText: 'How did this habit feel today?',
                  hintStyle: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.inkFaint,
                  ),
                  filled: true,
                  fillColor: AppColors.linenAlt,
                  contentPadding: const EdgeInsets.all(AppSpacing.gutter),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadius.sm),
                    ),
                    borderSide: BorderSide(
                      color: AppColors.ink,
                      width: AppBorder.standard,
                    ),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadius.sm),
                    ),
                    borderSide: BorderSide(
                      color: AppColors.ink,
                      width: AppBorder.standard,
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(AppRadius.sm),
                    ),
                    borderSide: BorderSide(
                      color: AppColors.ink,
                      width: AppBorder.thick,
                    ),
                  ),
                ),
              ),
              if (competition == null) ...[
                const SizedBox(height: AppSpacing.stackMd),
                _heading('Share with', Icons.people_outline),
                const SizedBox(height: AppSpacing.stackSm),
                AbsorbPointer(
                  absorbing: _publishing,
                  child: Wrap(
                    spacing: AppSpacing.unit,
                    runSpacing: AppSpacing.unit,
                    children: [
                      NoriChoiceChip(
                        label: 'All friends',
                        selected: _visibility == PostVisibility.allFriends,
                        onTap: () => _shareWith(PostVisibility.allFriends),
                      ),
                      for (final circle in _circles)
                        NoriChoiceChip(
                          label: circle.name,
                          icon: circle.icon,
                          selected:
                              _visibility == PostVisibility.circle &&
                              _circleId == circle.id,
                          onTap: () =>
                              _shareWith(PostVisibility.circle, circle.id),
                        ),
                      NoriChoiceChip(
                        label: 'Only me',
                        icon: Icons.lock_outline,
                        selected: _visibility == PostVisibility.onlyMe,
                        onTap: () => _shareWith(PostVisibility.onlyMe),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.stackMd),
              // Mock reward copy matches the social repository's photo-proof reward.
              TactileButton(
                label: _publishing
                    ? 'Sharing proof...'
                    : competition == null
                    ? 'Publish proof (+50 XP)'
                    : "Submit today's proof",
                icon: Icons.send,
                onPressed:
                    _publishing ||
                        habit == null ||
                        (competition != null && !_withPhoto)
                    ? null
                    : _publish,
              ),
            ],
          ],
        );
      }),
    ),
  );
}
