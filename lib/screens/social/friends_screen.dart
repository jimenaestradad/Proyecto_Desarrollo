import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/screens/social/add_friend_screen.dart';
import 'package:nori/screens/social/friend_profile_screen.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/circular_icon_button.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/nori_segmented_control.dart';
import 'package:nori/widgets/nori_text_field.dart';
import 'package:nori/widgets/section_header.dart';
import 'package:nori/widgets/tactile_button.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with RemoteLoadState<FriendsScreen>, SocialLoadState<FriendsScreen> {
  late int _tab = widget.initialTab.clamp(0, 1);
  final _search = TextEditingController();
  List<SocialUser> _friends = [];
  List<FriendRequest> _requests = [];
  Map<String, FriendStreak> _streaks = {};
  final Set<String> _busy = {};
  final Set<String> _nudged = {};

  @override
  Future<void> loadSocial() async {
    final friends = await AppData.social.getFriends();
    final requests = await AppData.social.getFriendRequests();
    final streaks = await AppData.social.getFriendStreaks();
    if (!mounted) return;
    setState(() {
      _friends = friends;
      _requests = requests;
      _streaks = {for (final s in streaks) s.friendId: s};
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _add() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AddFriendScreen()),
  );

  void _profile(SocialUser user) {
    if (user.isMe) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FriendProfileScreen(userId: user.id)),
    );
  }

  Future<void> _act(
    String id,
    Future<void> Function() action,
    String message, {
    bool nudge = false,
  }) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    final success = await guardedAction(action);
    if (!mounted) return;
    setState(() {
      _busy.remove(id);
      if (success && nudge) _nudged.add(id);
    });
    if (success) showSocialToast(context, message);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: buildLoaded((context) {
        final incoming = _requests
            .where((r) => r.direction == FriendRequestDirection.incoming)
            .toList();
        final outgoing = _requests
            .where((r) => r.direction == FriendRequestDirection.outgoing)
            .toList();
        final query = _search.text.trim().toLowerCase();
        final filtered = _friends
            .where((u) => '${u.name} ${u.handle}'.toLowerCase().contains(query))
            .toList();
        return NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: 'Friends',
              titleStyle: AppTextStyles.headlineLgMobile,
              trailing: CircularIconButton(
                icon: Icons.person_add,
                tooltip: 'Add friends',
                onPressed: _add,
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            NoriSegmentedControl(
              labels: ['Friends (${_friends.length})', 'Requests'],
              selectedIndex: _tab,
              badges: {1: incoming.length},
              onChanged: (value) => setState(() => _tab = value),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (_tab == 0) ...[
              NoriTextField(
                controller: _search,
                label: 'Search friends',
                hint: 'Filter by name or @username',
                icon: Icons.search,
                onChanged: (_) => setState(() {}),
              ),
              if (_friends.isEmpty)
                NoriEmptyState(
                  icon: Icons.people_outline,
                  title: 'Find your people',
                  message: 'Build habits together with friends.',
                  actionLabel: 'Find friends',
                  onAction: _add,
                )
              else if (filtered.isEmpty)
                const NoriEmptyState(
                  icon: Icons.search_off,
                  title: 'No matching friends',
                  message: 'Try another name or username.',
                )
              else
                for (final user in filtered) ...[
                  PersonRow(
                    user: user,
                    onTap: () => _profile(user),
                    subtitle:
                        'Level ${user.level} • ${_streaks[user.id] == null ? user.statusLine : '${_streaks[user.id]!.current}-day streak'}',
                    trailing: TextButton(
                      onPressed:
                          _busy.contains(user.id) || _nudged.contains(user.id)
                          ? null
                          : () => _act(
                              user.id,
                              () => AppData.social.nudge(user.id),
                              'Nudge sent to ${user.firstName}',
                              nudge: true,
                            ),
                      child: Text(
                        _nudged.contains(user.id) ? 'Nudged' : 'Nudge',
                        style: AppTextStyles.labelLg,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.stackSm),
                ],
            ] else ...[
              if (incoming.isEmpty && outgoing.isEmpty)
                const NoriEmptyState(
                  icon: Icons.mail_outline,
                  title: 'No requests yet',
                  message:
                      'Incoming and sent friend requests will appear here.',
                )
              else ...[
                const SectionHeader(
                  title: 'Incoming',
                  trailing: SizedBox.shrink(),
                ),
                const SizedBox(height: AppSpacing.stackSm),
                if (incoming.isEmpty)
                  Text(
                    'No incoming requests',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.inkFaint,
                    ),
                  ),
                for (final request in incoming) ...[
                  PersonRow(
                    user: request.user,
                    subtitle: request.note,
                    onTap: () => _profile(request.user),
                  ),
                  const SizedBox(height: AppSpacing.unit),
                  Row(
                    children: [
                      Expanded(
                        child: TactileButton(
                          label: 'Accept',
                          onPressed: _busy.contains(request.user.id)
                              ? null
                              : () => _act(
                                  request.user.id,
                                  () => AppData.social.acceptFriendRequest(
                                    request.user.id,
                                  ),
                                  '${request.user.firstName} is now your friend',
                                ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.stackSm),
                      TextButton(
                        onPressed: _busy.contains(request.user.id)
                            ? null
                            : () => _act(
                                request.user.id,
                                () => AppData.social.declineFriendRequest(
                                  request.user.id,
                                ),
                                'Request ignored',
                              ),
                        child: const Text('Ignore'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                ],
                const SizedBox(height: AppSpacing.stackMd),
                const SectionHeader(title: 'Sent', trailing: SizedBox.shrink()),
                const SizedBox(height: AppSpacing.stackSm),
                if (outgoing.isEmpty)
                  Text(
                    'No sent requests',
                    style: AppTextStyles.bodyMd.copyWith(
                      color: AppColors.inkFaint,
                    ),
                  ),
                for (final request in outgoing) ...[
                  PersonRow(
                    user: request.user,
                    subtitle: request.note.isEmpty
                        ? 'Request sent'
                        : request.note,
                    onTap: () => _profile(request.user),
                    trailing: TextButton(
                      onPressed: _busy.contains(request.user.id)
                          ? null
                          : () => _act(
                              request.user.id,
                              () => AppData.social.cancelFriendRequest(
                                request.user.id,
                              ),
                              'Request cancelled',
                            ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.stackSm),
                ],
              ],
            ],
          ],
        );
      }),
    ),
  );
}
