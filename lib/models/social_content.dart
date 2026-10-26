import 'package:flutter/material.dart';

/// Reactions are Material icons, never emoji (docs/DESIGN.md §6).
enum Reaction {
  love(Icons.favorite, Icons.favorite_border, 'Love'),
  celebrate(Icons.celebration, Icons.celebration_outlined, 'Celebrate'),
  thumbsUp(Icons.thumb_up, Icons.thumb_up_outlined, 'Nice'),
  fire(
    Icons.local_fire_department,
    Icons.local_fire_department_outlined,
    'On fire',
  ),
  strong(Icons.fitness_center, Icons.fitness_center_outlined, 'Strong');

  const Reaction(this.activeIcon, this.icon, this.label);

  final IconData activeIcon;
  final IconData icon;
  final String label;
}

enum PostVisibility { allFriends, circle, onlyMe }

class PostComment {
  const PostComment({
    required this.id,
    required this.authorId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String text;
  final DateTime createdAt;
}

class SocialPost {
  const SocialPost({
    required this.id,
    required this.authorId,
    required this.habitName,
    required this.habitIcon,
    required this.habitColor,
    required this.caption,
    required this.createdAt,
    this.hasProof = true,
    this.visibility = PostVisibility.allFriends,
    this.circleId,
    this.competitionId,
    this.xpEarned = 0,
    this.reactionCounts = const {},
    this.myReactions = const {},
    this.comments = const [],
  });

  final String id;

  /// A SocialUser id; 'me' for your own posts.
  final String authorId;
  final String habitName;
  final IconData habitIcon;
  final Color habitColor;
  final String caption;
  final DateTime createdAt;

  /// Proof photo attached (the mock renders a placeholder panel, not a
  /// real image — see ProofPhoto).
  final bool hasProof;
  final PostVisibility visibility;
  final String? circleId;

  /// Set when the post was submitted as a competition's proof.
  final String? competitionId;
  final int xpEarned;
  final Map<Reaction, int> reactionCounts;

  /// Which reactions *you* have added.
  final Set<Reaction> myReactions;
  final List<PostComment> comments;

  int get totalReactions =>
      reactionCounts.values.fold(0, (sum, count) => sum + count);

  SocialPost copyWith({
    Map<Reaction, int>? reactionCounts,
    Set<Reaction>? myReactions,
    List<PostComment>? comments,
  }) {
    return SocialPost(
      id: id,
      authorId: authorId,
      habitName: habitName,
      habitIcon: habitIcon,
      habitColor: habitColor,
      caption: caption,
      createdAt: createdAt,
      hasProof: hasProof,
      visibility: visibility,
      circleId: circleId,
      competitionId: competitionId,
      xpEarned: xpEarned,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      myReactions: myReactions ?? this.myReactions,
      comments: comments ?? this.comments,
    );
  }
}

/// A habit you completed today that can be turned into a proof post.
class ProofableHabit {
  const ProofableHabit({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;
}

enum SocialNotificationKind {
  reaction,
  comment,
  nudge,
  rank,
  friendRequest,
  competitionInvite,
  streakAtRisk,
  highFive,
}

class SocialNotification {
  const SocialNotification({
    required this.id,
    required this.kind,
    required this.message,
    required this.createdAt,
    required this.icon,
    required this.color,
    this.actorId,
    this.refId,
    this.isRead = false,
  });

  final String id;
  final SocialNotificationKind kind;

  /// Plain text; the actor's name is bolded by matching [actorName] in the UI
  /// only if the screen wants to — keep the sentence self-contained.
  final String message;
  final DateTime createdAt;
  final IconData icon;
  final Color color;
  final String? actorId;

  /// Post id, request user id, competition id, or streak friend id,
  /// depending on [kind].
  final String? refId;
  final bool isRead;

  SocialNotification copyWith({bool? isRead}) {
    return SocialNotification(
      id: id,
      kind: kind,
      message: message,
      createdAt: createdAt,
      icon: icon,
      color: color,
      actorId: actorId,
      refId: refId,
      isRead: isRead ?? this.isRead,
    );
  }

  /// Needs an Accept/Decline (or Join/Decline) answer rather than a tap-through.
  bool get isActionable =>
      kind == SocialNotificationKind.friendRequest ||
      kind == SocialNotificationKind.competitionInvite;
}

enum CheerKind { hug, treat, wave }

class CheerEntry {
  const CheerEntry({
    required this.fromId,
    required this.kind,
    required this.createdAt,
  });

  final String fromId;
  final CheerKind kind;
  final DateTime createdAt;
}

/// Counters behind the Social achievements (see achievement_repository.dart).
/// Mock-backed today — they come from the same in-memory data as the rest of
/// the Social tab.
class SocialActivity {
  const SocialActivity({
    required this.reactionsGiven,
    required this.challengesCompleted,
    required this.proofPosts,
    required this.circlesCreated,
    required this.friendCount,
  });

  /// Reactions you've added to other people's posts.
  final int reactionsGiven;

  /// Competitions you took part in that have finished.
  final int challengesCompleted;

  /// Your own posts that carry a proof photo.
  final int proofPosts;
  final int circlesCreated;
  final int friendCount;
}

enum ReportReason { spam, inappropriate, fakeProof, harassment, other }

extension ReportReasonLabel on ReportReason {
  String get label => switch (this) {
    ReportReason.spam => 'Spam',
    ReportReason.inappropriate => 'Inappropriate content',
    ReportReason.fakeProof => 'Fake or misleading proof',
    ReportReason.harassment => 'Harassment',
    ReportReason.other => 'Something else',
  };
}
