import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nori/data/session_photos.dart';
import 'package:nori/models/social_content.dart';
import 'package:nori/models/social_people.dart';
import 'package:nori/theme/app_theme.dart';
import 'package:nori/utils/relative_time.dart';
import 'package:nori/widgets/nori_avatar.dart';
import 'package:nori/widgets/nori_card.dart';
import 'package:nori/widgets/nori_icon_badge.dart';

/// Avatar for a [SocialUser]: your own gets the illustrated default art,
/// everyone else their bundled photo, or a deterministic initials circle when
/// they have none.
class SocialAvatar extends StatelessWidget {
  const SocialAvatar({
    super.key,
    required this.user,
    this.size = 40,
    this.borderWidth = AppBorder.thick,
  });

  final SocialUser user;
  final double size;
  final double borderWidth;

  @override
  Widget build(BuildContext context) => NoriAvatar(
    size: size,
    borderWidth: borderWidth,
    name: user.isMe ? null : user.name,
    imageAsset: user.isMe ? null : user.avatarAsset,
  );
}

/// "Section title row" link, e.g. "See all >", for [SectionHeader.trailing].
class SectionLink extends StatelessWidget {
  const SectionLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(foregroundColor: AppColors.mossDark),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 2),
        const Icon(Icons.chevron_right, size: 18),
      ],
    ),
  );
}

/// Tappable white row for a person: avatar, name + @handle, subtitle, and an
/// optional trailing widget (button, chevron, chip).
class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    required this.user,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.highlighted = false,
    this.avatarSize = 44,
    this.footer,
  });

  final SocialUser user;
  final String? subtitle;
  final Widget? trailing;

  /// Shown inside the card under the row, e.g. a progress bar.
  final Widget? footer;
  final VoidCallback? onTap;

  /// Your own row in a list: mossLight fill.
  final bool highlighted;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: NoriCard(
        padding: const EdgeInsets.all(AppSpacing.stackSm),
        borderWidth: AppBorder.thin,
        color: highlighted ? AppColors.mossLight : AppColors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SocialAvatar(user: user, size: avatarSize),
                const SizedBox(width: AppSpacing.stackSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.shortName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.labelLg,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            user.handle,
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.inkMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.unit),
                  trailing!,
                ],
              ],
            ),
            if (footer != null) ...[
              const SizedBox(height: AppSpacing.stackSm),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Small green "Proof" pill with a verified icon.
class ProofBadge extends StatelessWidget {
  const ProofBadge({super.key, this.label = 'Proof'});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.mossLight,
      borderRadius: BorderRadius.circular(AppRadius.full),
      border: Border.all(color: AppColors.ink, width: AppBorder.thin),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.verified, size: 14, color: AppColors.mossDark),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppTextStyles.labelSm.copyWith(color: AppColors.mossDark),
        ),
      ],
    ),
  );
}

/// Proof photo for a post: a photo picked this session, else the showcase
/// post's bundled photo, else a tinted, ink-bordered panel showing the habit
/// icon (no image storage exists yet; swap for `Image.network` once uploads
/// exist).
class ProofPhoto extends StatelessWidget {
  const ProofPhoto({
    super.key,
    required this.icon,
    required this.color,
    this.height = 180,
    this.label = 'Proof photo',
    this.bytes,
    this.asset,
  });

  final IconData icon;
  final Color color;
  final double height;
  final String label;

  /// A photo picked this session; wins over [asset].
  final Uint8List? bytes;

  /// A bundled photo for the showcase posts.
  final String? asset;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    clipBehavior: Clip.antiAlias,
    width: double.infinity,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: AppColors.ink, width: AppBorder.thin),
    ),
    child: Stack(
      children: [
        if (bytes != null)
          Positioned.fill(child: Image.memory(bytes!, fit: BoxFit.cover))
        else if (asset != null)
          Positioned.fill(child: Image.asset(asset!, fit: BoxFit.cover))
        else
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: AppColors.ink),
                const SizedBox(height: 6),
                Text(label, style: AppTextStyles.labelSm),
              ],
            ),
          ),
        if (bytes == null && asset == null)
          const Positioned(
            right: 10,
            bottom: 10,
            child: Icon(
              Icons.photo_camera,
              size: 20,
              color: AppColors.inkMuted,
            ),
          ),
      ],
    ),
  );
}

/// A friend's pet as a still picture: the baby Nori for stage 0, the winged
/// form for anything later (the art exists for two forms only, so every friend's
/// pet looks the same apart from its name). Still frames, not the animated
/// sprites, so a profile card doesn't preload 64 frames.
class FriendPetPicture extends StatelessWidget {
  const FriendPetPicture({super.key, required this.stage, this.size = 144});

  /// SocialUser.petStage: 0 = baby, 1 and 2 = evolved.
  final int stage;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(AppSpacing.unit),
    decoration: BoxDecoration(
      color: AppColors.linenAlt,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: AppColors.ink, width: AppBorder.thin),
    ),
    child: Image.asset(
      stage == 0
          ? 'assets/images/nori_front.png'
          : 'assets/images/nori_evolved/frame_00.png',
      fit: BoxFit.contain,
    ),
  );
}

/// Banner photo for a showcase circle or competition: 16:9, ink-bordered,
/// same corner radius as [ProofPhoto].
class CoverPhoto extends StatelessWidget {
  const CoverPhoto({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: AppColors.ink, width: AppBorder.thin),
    ),
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: Image.asset(asset, fit: BoxFit.cover),
    ),
  );
}

/// Reaction pills for a post plus an "add reaction" picker and a comment
/// count. Existing reactions (or ones you've added) show as toggle pills.
class ReactionBar extends StatelessWidget {
  const ReactionBar({
    super.key,
    required this.post,
    required this.onToggle,
    this.onComment,
  });

  final SocialPost post;
  final ValueChanged<Reaction> onToggle;
  final VoidCallback? onComment;

  @override
  Widget build(BuildContext context) {
    final shown =
        Reaction.values
            .where(
              (r) =>
                  (post.reactionCounts[r] ?? 0) > 0 ||
                  post.myReactions.contains(r),
            )
            .toList()
          ..sort(
            (a, b) => (post.reactionCounts[b] ?? 0).compareTo(
              post.reactionCounts[a] ?? 0,
            ),
          );

    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final reaction in shown)
                _ReactionPill(
                  reaction: reaction,
                  count: post.reactionCounts[reaction] ?? 0,
                  selected: post.myReactions.contains(reaction),
                  onTap: () => onToggle(reaction),
                ),
              _AddReactionButton(post: post, onPick: onToggle),
            ],
          ),
        ),
        if (onComment != null)
          InkWell(
            onTap: onComment,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                    color: AppColors.inkMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.comments.length}',
                    style: AppTextStyles.labelLg.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    required this.reaction,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final Reaction reaction;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${reaction.label}, $count',
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.mossLight : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: AppColors.ink,
            width: selected ? AppBorder.standard : AppBorder.thin,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? reaction.activeIcon : reaction.icon,
              size: 16,
              color: selected ? AppColors.mossDark : AppColors.inkMuted,
            ),
            const SizedBox(width: 4),
            Text('$count', style: AppTextStyles.labelLg),
          ],
        ),
      ),
    ),
  );
}

class _AddReactionButton extends StatelessWidget {
  const _AddReactionButton({required this.post, required this.onPick});

  final SocialPost post;
  final ValueChanged<Reaction> onPick;

  @override
  Widget build(BuildContext context) => PopupMenuButton<Reaction>(
    tooltip: 'Add reaction',
    onSelected: onPick,
    color: AppColors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      side: const BorderSide(color: AppColors.ink, width: AppBorder.thin),
    ),
    itemBuilder: (_) => [
      for (final reaction in Reaction.values)
        PopupMenuItem(
          value: reaction,
          child: Row(
            children: [
              Icon(
                post.myReactions.contains(reaction)
                    ? reaction.activeIcon
                    : reaction.icon,
                size: 20,
                color: AppColors.ink,
              ),
              const SizedBox(width: AppSpacing.unit),
              Text(reaction.label, style: AppTextStyles.labelLg),
            ],
          ),
        ),
    ],
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.linenAlt,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.inkFaint, width: AppBorder.thin),
      ),
      child: const Icon(
        Icons.add_reaction_outlined,
        size: 18,
        color: AppColors.inkMuted,
      ),
    ),
  );
}

/// One feed post. Used by the hub preview, the feed, circle feeds, and a
/// friend's recent posts.
///
/// [compact] drops the habit chip and shrinks the proof photo (hub preview).
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.author,
    required this.onReactionToggle,
    this.onTap,
    this.onAuthorTap,
    this.onMenu,
    this.contextLabel,
    this.compact = false,
  });

  final SocialPost post;
  final SocialUser author;
  final ValueChanged<Reaction> onReactionToggle;

  /// Opens the post detail; also wired to the comment button.
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;

  /// Shows a "more" button in the header (report / hide).
  final VoidCallback? onMenu;

  /// Shown after the time, e.g. the circle or competition name.
  final String? contextLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final time = relativeTimeLabel(post.createdAt);
    final subtitle = contextLabel == null ? time : '$time • $contextLabel';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: NoriCard(
        padding: const EdgeInsets.all(AppSpacing.stackSm),
        borderWidth: AppBorder.thin,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onAuthorTap,
                  child: SocialAvatar(user: author, size: 40),
                ),
                const SizedBox(width: AppSpacing.unit),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author.isMe ? 'You' : author.shortName,
                        style: AppTextStyles.labelLg,
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.hasProof) const ProofBadge(),
                if (onMenu != null)
                  IconButton(
                    onPressed: onMenu,
                    tooltip: 'More',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.more_horiz,
                      color: AppColors.inkMuted,
                    ),
                  ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: AppSpacing.unit),
              Row(
                children: [
                  NoriIconBadge(
                    icon: post.habitIcon,
                    background: post.habitColor,
                    size: 28,
                    iconSize: 16,
                    circle: true,
                  ),
                  const SizedBox(width: AppSpacing.unit),
                  Expanded(
                    child: Text(
                      post.habitName,
                      style: AppTextStyles.labelLg.copyWith(
                        color: AppColors.mossDark,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.unit),
            Text(post.caption, style: AppTextStyles.bodyMd),
            if (post.hasProof) ...[
              const SizedBox(height: AppSpacing.stackSm),
              ProofPhoto(
                icon: post.habitIcon,
                color: post.habitColor,
                height: compact ? 130 : 180,
                bytes: SessionPhotos.proofFor(post.id),
                asset: post.photoAsset,
              ),
            ],
            const SizedBox(height: AppSpacing.stackSm),
            ReactionBar(
              post: post,
              onToggle: onReactionToggle,
              onComment: onTap,
            ),
          ],
        ),
      ),
    );
  }
}
