import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/screens/social/friend_profile_screen.dart';
import 'package:nori/screens/social/invite_friends_screen.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/widgets/nori_list_row.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/nori_text_field.dart';
import 'package:nori/widgets/section_header.dart';
import 'package:nori/widgets/tactile_button.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});
  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen>
    with RemoteLoadState<AddFriendScreen>, SocialLoadState<AddFriendScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  int _searchVersion = 0;
  bool _searching = false;
  String? _searchError;
  List<SocialUser> _results = [], _suggestions = [];
  Set<String> _friendIds = {}, _requestedIds = {}, _incomingIds = {};
  final Set<String> _busy = {};

  @override
  Future<void> loadSocial() async {
    final friends = await AppData.social.getFriends();
    final requests = await AppData.social.getFriendRequests();
    final suggestions = await AppData.social.getSuggestions();
    if (!mounted) return;
    setState(() {
      _friendIds = friends.map((u) => u.id).toSet();
      _requestedIds = requests
          .where((r) => r.direction == FriendRequestDirection.outgoing)
          .map((r) => r.user.id)
          .toSet();
      _incomingIds = requests
          .where((r) => r.direction == FriendRequestDirection.incoming)
          .map((r) => r.user.id)
          .toSet();
      _suggestions = suggestions;
    });
  }

  void _changed(String value) {
    _debounce?.cancel();
    _searchVersion++;
    setState(() {
      _searching = value.trim().isNotEmpty;
      _searchError = null;
      _results = [];
    });
    if (value.trim().isNotEmpty) {
      _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
    }
  }

  Future<void> _runSearch() async {
    _debounce?.cancel();
    final query = _search.text.trim();
    final version = ++_searchVersion;
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final users = await AppData.social
          .searchUsers(query)
          .timeout(remoteTimeout);
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _results = users;
        _searching = false;
      });
    } catch (error) {
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _searchError = remoteErrorMessage(error);
        _searching = false;
      });
    }
  }

  Future<void> _request(SocialUser user) async {
    if (_busy.contains(user.id)) return;
    setState(() => _busy.add(user.id));
    final incoming = _incomingIds.contains(user.id);
    final success = await guardedAction(() async {
      if (incoming) {
        await AppData.social.acceptFriendRequest(user.id);
      } else {
        await AppData.social.sendFriendRequest(user.id);
      }
    });
    if (!mounted) return;
    setState(() => _busy.remove(user.id));
    if (success) {
      showSocialToast(
        context,
        incoming
            ? '${user.firstName} is now your friend'
            : 'Request sent to ${user.firstName}',
      );
    }
  }

  Widget _person(SocialUser user) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.stackSm),
    child: PersonRow(
      user: user,
      subtitle:
          '${user.mutualFriends} mutual ${user.mutualFriends == 1 ? 'friend' : 'friends'}',
      onTap: user.isMe
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FriendProfileScreen(userId: user.id),
              ),
            ),
      trailing: _friendIds.contains(user.id)
          ? NoriCard(
              radius: AppRadius.full,
              color: AppColors.mossLight,
              borderWidth: AppBorder.thin,
              padding: const EdgeInsets.all(AppSpacing.unit),
              child: Text('Friends', style: AppTextStyles.labelSm),
            )
          : TextButton(
              onPressed:
                  _requestedIds.contains(user.id) || _busy.contains(user.id)
                  ? null
                  : () => _request(user),
              child: Text(
                _requestedIds.contains(user.id)
                    ? 'Requested'
                    : _incomingIds.contains(user.id)
                    ? 'Accept'
                    : 'Add',
                style: AppTextStyles.labelLg,
              ),
            ),
    ),
  );

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: buildLoaded(
        (context) => NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: 'Add friends',
              titleStyle: AppTextStyles.headlineLgMobile,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            NoriTextField(
              controller: _search,
              label: 'Search by @username or friend code',
              hint: '@username or #NORI-4821',
              icon: Icons.search,
              textInputAction: TextInputAction.search,
              onChanged: _changed,
              onSubmitted: (_) => _runSearch(),
            ),
            TactileButton(
              label: 'Search',
              icon: Icons.search,
              onPressed: _search.text.trim().isEmpty ? null : _runSearch,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (_searching)
              const Center(child: CircularProgressIndicator())
            else if (_searchError != null)
              NoriEmptyState(
                icon: Icons.cloud_off,
                title: 'Search unavailable',
                message: _searchError!,
                actionLabel: 'Try again',
                onAction: _runSearch,
              )
            else if (_search.text.trim().isEmpty)
              Text(
                'Find a friend using their username or invite code.',
                style: AppTextStyles.bodyMd.copyWith(color: AppColors.inkFaint),
              )
            else if (_results.isEmpty)
              NoriEmptyState(
                icon: Icons.search_off,
                title: 'No one found for ${_search.text.trim()}',
                message:
                    'Check the username or ask your friend for an invite link.',
              )
            else ...[
              const SectionHeader(
                title: 'Search results',
                trailing: SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.stackSm),
              ..._results.map(_person),
            ],
            const SizedBox(height: AppSpacing.stackLg),
            const SectionHeader(
              title: 'People you may know',
              trailing: SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            if (_suggestions.isEmpty)
              const NoriEmptyState(
                icon: Icons.people_outline,
                title: 'No suggestions yet',
                message: 'Invite a friend to start your circle.',
              )
            else
              ..._suggestions.map(_person),
            const SizedBox(height: AppSpacing.stackMd),
            NoriListRow(
              icon: Icons.link,
              label: 'Invite friends by link',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InviteFriendsScreen()),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
