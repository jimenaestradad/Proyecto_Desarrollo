import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/screens/social/friend_profile_screen.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';

class SocialPrivacyScreen extends StatefulWidget {
  const SocialPrivacyScreen({super.key});
  @override
  State<SocialPrivacyScreen> createState() => _SocialPrivacyScreenState();
}

class _SocialPrivacyScreenState extends State<SocialPrivacyScreen>
    with
        RemoteLoadState<SocialPrivacyScreen>,
        SocialLoadState<SocialPrivacyScreen> {
  SocialPrivacy? _privacy;
  List<SocialUser> _blocked = [];
  bool _busy = false;

  @override
  Future<void> loadSocial() async {
    final privacy = await AppData.social.getPrivacy();
    final blocked = await AppData.social.getBlockedUsers();
    if (!mounted) return;
    setState(() {
      _privacy = privacy;
      _blocked = blocked;
    });
  }

  Future<void> _save(SocialPrivacy privacy) async {
    if (_busy) return;
    setState(() => _busy = true);
    final success = await guardedAction(
      () => AppData.social.updatePrivacy(privacy),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (success) showSocialToast(context, 'Privacy updated');
  }

  Future<void> _unblock(SocialUser user) async {
    if (_busy) return;
    setState(() => _busy = true);
    final success = await guardedAction(
      () => AppData.social.unblockUser(user.id),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (success) showSocialToast(context, '${user.firstName} unblocked');
  }

  String _visibilityLabel(ActivityVisibility value) => switch (value) {
    ActivityVisibility.allFriends => 'All friends',
    ActivityVisibility.circlesOnly => 'Circles only',
    ActivityVisibility.onlyMe => 'Only me',
  };

  Widget _section(String title, List<Widget> children) => NoriCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppTextStyles.labelLg),
        const SizedBox(height: AppSpacing.stackSm),
        ...children,
      ],
    ),
  );

  Widget _choice(String label, bool selected, VoidCallback onTap) => Semantics(
    checked: selected,
    inMutuallyExclusiveGroup: true,
    enabled: !_busy,
    child: InkWell(
      onTap: _busy ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackSm),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.mossDark : AppColors.ink,
            ),
            const SizedBox(width: AppSpacing.stackSm),
            Expanded(child: Text(label, style: AppTextStyles.bodyMd)),
          ],
        ),
      ),
    ),
  );

  Widget _visibility(
    String title,
    ActivityVisibility selected,
    ValueChanged<ActivityVisibility> onChanged,
  ) => _section(title, [
    // Mock-only: these visibility options are placeholders for social privacy rules.
    for (final value in ActivityVisibility.values)
      _choice(
        _visibilityLabel(value),
        value == selected,
        () => onChanged(value),
      ),
  ]);

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) => Row(
    children: [
      Expanded(child: Text(label, style: AppTextStyles.bodyMd)),
      const SizedBox(width: AppSpacing.unit),
      Switch(value: value, onChanged: _busy ? null : onChanged),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: buildLoaded((context) {
        final privacy = _privacy!;
        return NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: 'Social privacy',
              titleStyle: AppTextStyles.headlineLgMobile,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            _visibility(
              'Who can see my activity',
              privacy.activityVisibility,
              (value) => _save(privacy.copyWith(activityVisibility: value)),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            _visibility(
              'Default post visibility',
              privacy.defaultPostVisibility,
              (value) => _save(privacy.copyWith(defaultPostVisibility: value)),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            _section('Profile visibility', [
              _switch(
                'Show my pet to friends',
                privacy.showPetToFriends,
                (value) => _save(privacy.copyWith(showPetToFriends: value)),
              ),
              const SizedBox(height: AppSpacing.unit),
              _switch(
                'Show me on leaderboards',
                privacy.showOnLeaderboards,
                (value) => _save(privacy.copyWith(showOnLeaderboards: value)),
              ),
            ]),
            const SizedBox(height: AppSpacing.stackMd),
            _section('Who can send me friend requests', [
              _choice(
                'Anyone with my username',
                privacy.requestPolicy == FriendRequestPolicy.anyoneWithUsername,
                () => _save(
                  privacy.copyWith(
                    requestPolicy: FriendRequestPolicy.anyoneWithUsername,
                  ),
                ),
              ),
              _choice(
                'Nobody',
                privacy.requestPolicy == FriendRequestPolicy.nobody,
                () => _save(
                  privacy.copyWith(requestPolicy: FriendRequestPolicy.nobody),
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.stackMd),
            _section('Blocked users', [
              if (_blocked.isEmpty)
                Text(
                  'No blocked users',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.inkFaint,
                  ),
                )
              else
                for (final user in _blocked) ...[
                  PersonRow(
                    user: user,
                    onTap: user.isMe
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  FriendProfileScreen(userId: user.id),
                            ),
                          ),
                    trailing: TextButton(
                      onPressed: _busy ? null : () => _unblock(user),
                      child: Text('Unblock', style: AppTextStyles.labelLg),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.stackSm),
                ],
            ]),
          ],
        );
      }),
    ),
  );
}
