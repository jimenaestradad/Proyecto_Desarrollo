import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/competition.dart';
import 'package:nori/models/social_content.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/screens/social/friend_profile_screen.dart';
import 'package:nori/screens/social/post_actions_sheet.dart';
import 'package:nori/screens/social/post_detail_screen.dart';
import 'package:nori/screens/social/post_proof_screen.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/circular_icon_button.dart';
import 'package:nori/widgets/nori_choice_chip.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, this.initialCircleId});
  final String? initialCircleId;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with RemoteLoadState<FeedScreen>, SocialLoadState<FeedScreen> {
  List<SocialCircle> _circles = [];
  List<SocialPost> _posts = [];
  Map<String, SocialUser> _users = {};
  Map<String, String> _competitionTitles = {};
  String? _circleId;
  bool _initialized = false;
  int _loadVersion = 0;

  @override
  Future<void> loadSocial() async {
    final version = ++_loadVersion;
    final circles = await AppData.social.getCircles();
    if (!_initialized) {
      _circleId = widget.initialCircleId;
      _initialized = true;
    }
    final circleId = circles.any((c) => c.id == _circleId) ? _circleId : null;
    final posts = await AppData.social.getPosts(circleId: circleId);
    final users = await AppData.social.getUserDirectory();
    final List<Competition> competitions = await AppData.social
        .getCompetitions();
    if (!mounted || version != _loadVersion) return;
    setState(() {
      _circleId = circleId;
      _circles = circles;
      _posts = posts;
      _users = users;
      _competitionTitles = {for (final c in competitions) c.id: c.title};
    });
  }

  void _compose() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const PostProofScreen()));

  void _selectCircle(String? id) {
    if (_circleId == id) return;
    setState(() => _circleId = id);
    reload();
  }

  String? _contextLabel(SocialPost post) {
    if (post.competitionId != null) {
      final title = _competitionTitles[post.competitionId];
      if (title != null) return title;
    }
    for (final circle in _circles) {
      if (circle.id == post.circleId) return circle.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.linen,
    body: SafeArea(
      child: buildLoaded(
        (context) => NoriScrollScaffold(
          maxWidth: 800,
          children: [
            NoriScreenHeader(
              leading: NoriScreenHeader.backButton(context),
              title: 'Activity',
              titleStyle: AppTextStyles.headlineLgMobile,
              trailing: CircularIconButton(
                icon: Icons.add_a_photo,
                tooltip: 'Share habit proof',
                onPressed: _compose,
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  NoriChoiceChip(
                    label: 'All',
                    selected: _circleId == null,
                    onTap: () => _selectCircle(null),
                  ),
                  for (final circle in _circles) ...[
                    const SizedBox(width: AppSpacing.unit),
                    NoriChoiceChip(
                      label: circle.name,
                      icon: circle.icon,
                      selected: _circleId == circle.id,
                      onTap: () => _selectCircle(circle.id),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            if (_posts.isEmpty)
              NoriEmptyState(
                icon: Icons.photo_camera_outlined,
                title: 'No proofs yet',
                message: 'Share a completed habit and cheer each other on.',
                actionLabel: 'Share habit proof',
                onAction: _compose,
              ),
            for (final post in _posts)
              if (_users[post.authorId] case final author?) ...[
                PostCard(
                  post: post,
                  author: author,
                  contextLabel: _contextLabel(post),
                  onReactionToggle: (reaction) => guardedAction(() async {
                    await AppData.social.toggleReaction(post.id, reaction);
                  }),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PostDetailScreen(postId: post.id),
                    ),
                  ),
                  onAuthorTap: author.isMe
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                FriendProfileScreen(userId: author.id),
                          ),
                        ),
                  onMenu: () =>
                      showPostActionsSheet(context, post: post, author: author),
                ),
                const SizedBox(height: AppSpacing.stackSm),
              ],
          ],
        ),
      ),
    ),
  );
}
