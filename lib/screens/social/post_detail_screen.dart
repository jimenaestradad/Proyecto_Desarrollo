import 'package:flutter/material.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/models/competition.dart';
import 'package:nori/models/social_content.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/screens/social/competition_detail_screen.dart';
import 'package:nori/screens/social/friend_profile_screen.dart';
import 'package:nori/screens/social/post_actions_sheet.dart';
import 'package:nori/screens/social/social_load_state.dart';
import 'package:nori/screens/social/widgets/social_widgets.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/relative_time.dart';
import 'package:nori/utils/remote_errors.dart';
import 'package:nori/widgets/circular_icon_button.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_empty_state.dart';
import 'package:nori/widgets/nori_screen_header.dart';
import 'package:nori/widgets/nori_scroll_scaffold.dart';
import 'package:nori/widgets/nori_text_field.dart';
import 'package:nori/widgets/section_header.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.postId});
  final String postId;
  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen>
    with RemoteLoadState<PostDetailScreen>, SocialLoadState<PostDetailScreen> {
  SocialPost? _post;
  Map<String, SocialUser> _users = {};
  Competition? _competition;
  final _comment = TextEditingController();
  bool _sending = false;
  bool _blocked = false;

  @override
  Future<void> loadSocial() async {
    final post = await AppData.social.getPost(widget.postId);
    final users = await AppData.social.getUserDirectory();
    final privacy = await AppData.social.getPrivacy();
    final competitions = await AppData.social.getCompetitions();
    Competition? competition;
    for (final c in competitions) {
      if (c.id == post.competitionId) competition = c;
    }
    if (!mounted) return;
    setState(() {
      _post = post;
      _users = users;
      _competition = competition;
      _blocked = privacy.blockedIds.contains(post.authorId);
    });
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _profile(SocialUser user) {
    if (user.isMe) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FriendProfileScreen(userId: user.id),
      ),
    );
  }

  Future<void> _actions(SocialPost post, SocialUser author) async {
    await showPostActionsSheet(context, post: post, author: author);
    if (!mounted) return;
    await guardedAction(() async {
      final privacy = await AppData.social.getPrivacy();
      if (!mounted) return;
      if (privacy.blockedIds.contains(author.id) &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    if (_sending || text.isEmpty || _blocked) return;
    setState(() => _sending = true);
    final success = await guardedAction(() async {
      await AppData.social.addComment(widget.postId, text);
    });
    if (!mounted) return;
    if (success) {
      _comment.clear();
      showSocialToast(context, 'Comment sent');
    }
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.linen,
    body: SafeArea(
      child: buildLoaded((context) {
        final post = _post!;
        final author = _users[post.authorId];
        return Column(
          children: [
            Expanded(
              child: NoriScrollScaffold(
                maxWidth: 800,
                children: [
                  NoriScreenHeader(
                    leading: NoriScreenHeader.backButton(context),
                    title: 'Post',
                    titleStyle: AppTextStyles.headlineLgMobile,
                    trailing: author == null || _blocked
                        ? null
                        : CircularIconButton(
                            icon: Icons.more_horiz,
                            tooltip: 'Post options',
                            onPressed: () => _actions(post, author),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                  if (_blocked || author == null)
                    const NoriEmptyState(
                      icon: Icons.hide_source,
                      title: 'Post unavailable',
                      message: 'This post is no longer visible.',
                    )
                  else ...[
                    PersonRow(
                      user: author,
                      subtitle:
                          '${relativeTimeLabel(post.createdAt)} · Level ${author.level}',
                      onTap: author.isMe ? null : () => _profile(author),
                    ),
                    const SizedBox(height: AppSpacing.stackSm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _PostTag(
                        label: post.habitName,
                        icon: post.habitIcon,
                        color: AppColors.mossLight,
                      ),
                    ),
                    if (post.hasProof) ...[
                      const SizedBox(height: AppSpacing.stackSm),
                      ProofPhoto(
                        icon: post.habitIcon,
                        color: post.habitColor,
                        height: 240,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.stackSm),
                    Text(post.caption, style: AppTextStyles.bodyMd),
                    const SizedBox(height: AppSpacing.stackSm),
                    ReactionBar(
                      post: post,
                      onToggle: (reaction) => guardedAction(() async {
                        await AppData.social.toggleReaction(post.id, reaction);
                      }),
                    ),
                    if (author.isMe && post.xpEarned > 0) ...[
                      const SizedBox(height: AppSpacing.stackSm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: NoriCard(
                          color: AppColors.mustard,
                          radius: AppRadius.full,
                          borderWidth: AppBorder.thin,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.stackSm,
                            vertical: AppSpacing.unit,
                          ),
                          child: Text(
                            '+${post.xpEarned} XP earned',
                            style: AppTextStyles.labelSm,
                          ),
                        ),
                      ),
                    ],
                    if (post.competitionId != null) ...[
                      const SizedBox(height: AppSpacing.stackSm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _PostTag(
                          label: _competition?.title ?? 'Competition',
                          icon: Icons.emoji_events,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CompetitionDetailScreen(
                                competitionId: post.competitionId!,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.stackLg),
                    SectionHeader(
                      title: 'Cheering comments (${post.comments.length})',
                      icon: Icons.chat_bubble_outline,
                      trailing: const SizedBox.shrink(),
                    ),
                    const SizedBox(height: AppSpacing.stackSm),
                    if (post.comments.isEmpty)
                      const NoriEmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'Be the first to cheer',
                        message: 'A few kind words can make their day.',
                      ),
                    for (final comment in post.comments) ...[
                      NoriCard(
                        padding: const EdgeInsets.all(AppSpacing.stackSm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_users[comment.authorId] case final user?)
                              InkWell(
                                onTap: user.isMe ? null : () => _profile(user),
                                child: Row(
                                  children: [
                                    SocialAvatar(user: user),
                                    const SizedBox(width: AppSpacing.unit),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.isMe ? 'You' : user.shortName,
                                            style: AppTextStyles.labelLg,
                                          ),
                                          Text(
                                            relativeTimeLabel(
                                              comment.createdAt,
                                            ),
                                            style: AppTextStyles.labelSm,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: AppSpacing.unit),
                            Text(comment.text, style: AppTextStyles.bodyMd),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.stackSm),
                    ],
                  ],
                ],
              ),
            ),
            if (!_blocked && author != null)
              Container(
                color: AppColors.linen,
                padding: const EdgeInsets.all(AppSpacing.gutter),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: NoriTextField(
                            controller: _comment,
                            label: 'Cheer them on',
                            hint: 'Write a comment',
                            icon: Icons.chat_bubble_outline,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.unit),
                        CircularIconButton(
                          icon: _sending ? Icons.hourglass_top : Icons.send,
                          tooltip: _sending
                              ? 'Sending comment'
                              : 'Send comment',
                          onPressed: _send,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    ),
  );
}

/// A wrapping pill keeps long habit and competition names within phone widths.
class _PostTag extends StatelessWidget {
  const _PostTag({
    required this.label,
    required this.icon,
    this.color = AppColors.white,
    this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(AppRadius.full),
    child: NoriCard(
      color: color,
      radius: AppRadius.full,
      borderWidth: AppBorder.thin,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.stackSm,
        vertical: AppSpacing.unit,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.ink, size: 20),
          const SizedBox(width: AppSpacing.unit),
          Flexible(child: Text(label, style: AppTextStyles.labelLg)),
        ],
      ),
    ),
  );
}
