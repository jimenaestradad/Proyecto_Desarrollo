import 'package:flutter/material.dart';

/// A person in the social tab — a friend, a pending request, or a
/// not-yet-friend search result. `id == 'me'` is the signed-in user's own
/// social profile (the mock keeps it separate from [NoriUser]; see
/// SocialRepository.getMe).
class SocialUser {
  const SocialUser({
    required this.id,
    required this.name,
    required this.username,
    required this.level,
    required this.weeklyXp,
    required this.totalXp,
    required this.currentStreak,
    required this.proofCount,
    required this.petName,
    required this.petStage,
    this.statusLine = '',
    this.friendSince,
    this.mutualFriends = 0,
    this.avatarAsset,
  });

  final String id;
  final String name;

  /// Bundled profile picture for the showcase people; null falls back to the
  /// initials circle (see NoriAvatar).
  final String? avatarAsset;

  /// Without the leading "@".
  final String username;
  final int level;
  final int weeklyXp;
  final int totalXp;
  final int currentStreak;
  final int proofCount;
  final String petName;

  /// 0 = baby, 1 = evolution 1, 2 = evolution 2 (matches pet evolution stages).
  final int petStage;

  /// One-line "what they did lately", e.g. "Drank 8 glasses today".
  final String statusLine;
  final DateTime? friendSince;
  final int mutualFriends;

  bool get isMe => id == 'me';
  String get handle => '@$username';

  /// "Jimena V." — first name plus last initial, how names read in lists.
  String get shortName {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return name;
    return '${parts.first} ${parts.last[0]}.';
  }

  String get firstName => name.trim().split(RegExp(r'\s+')).first;
}

enum FriendRequestDirection { incoming, outgoing }

class FriendRequest {
  const FriendRequest({
    required this.user,
    required this.direction,
    this.note = '',
  });

  final SocialUser user;
  final FriendRequestDirection direction;

  /// e.g. "Mutual friend with Alex".
  final String note;
}

class SocialCircle {
  const SocialCircle({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.memberIds,
    required this.completionRate,
    this.activityLine = '',
    this.coverAsset,
  });

  final String id;
  final String name;
  final IconData icon;
  final Color color;

  /// Bundled cover photo for the showcase circles; null means no banner.
  final String? coverAsset;

  /// Includes 'me'.
  final List<String> memberIds;

  /// 0–1: share of members' scheduled habits completed this week.
  final double completionRate;
  final String activityLine;

  int get friendCount => memberIds.where((id) => id != 'me').length;

  SocialCircle copyWith({
    String? name,
    IconData? icon,
    Color? color,
    List<String>? memberIds,
  }) {
    return SocialCircle(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      memberIds: memberIds ?? this.memberIds,
      completionRate: completionRate,
      activityLine: activityLine,
      coverAsset: coverAsset,
    );
  }
}

/// One day of a friend streak: whether each side completed a habit.
class StreakDay {
  const StreakDay({required this.date, required this.me, required this.friend});

  final DateTime date;
  final bool me;
  final bool friend;

  bool get both => me && friend;
}

/// Mock rule (OPEN_DECISIONS.md still has friend-streak rules open): the
/// streak counts each day both friends completed at least one habit.
class FriendStreak {
  const FriendStreak({
    required this.friendId,
    required this.current,
    required this.best,
    required this.days,
    this.nextBadgeLabel = '',
    this.daysToBadge = 0,
  });

  final String friendId;
  final int current;
  final int best;

  /// Oldest first; the last entry is today.
  final List<StreakDay> days;
  final String nextBadgeLabel;
  final int daysToBadge;

  /// Today isn't done by both of you yet, and the streak is alive.
  bool get atRisk => current > 0 && !days.last.both;
}

enum ActivityVisibility { allFriends, circlesOnly, onlyMe }

enum FriendRequestPolicy { anyoneWithUsername, nobody }

class SocialPrivacy {
  const SocialPrivacy({
    this.activityVisibility = ActivityVisibility.allFriends,
    this.defaultPostVisibility = ActivityVisibility.allFriends,
    this.showPetToFriends = true,
    this.showOnLeaderboards = true,
    this.requestPolicy = FriendRequestPolicy.anyoneWithUsername,
    this.blockedIds = const [],
  });

  final ActivityVisibility activityVisibility;
  final ActivityVisibility defaultPostVisibility;
  final bool showPetToFriends;
  final bool showOnLeaderboards;
  final FriendRequestPolicy requestPolicy;
  final List<String> blockedIds;

  SocialPrivacy copyWith({
    ActivityVisibility? activityVisibility,
    ActivityVisibility? defaultPostVisibility,
    bool? showPetToFriends,
    bool? showOnLeaderboards,
    FriendRequestPolicy? requestPolicy,
    List<String>? blockedIds,
  }) {
    return SocialPrivacy(
      activityVisibility: activityVisibility ?? this.activityVisibility,
      defaultPostVisibility:
          defaultPostVisibility ?? this.defaultPostVisibility,
      showPetToFriends: showPetToFriends ?? this.showPetToFriends,
      showOnLeaderboards: showOnLeaderboards ?? this.showOnLeaderboards,
      requestPolicy: requestPolicy ?? this.requestPolicy,
      blockedIds: blockedIds ?? this.blockedIds,
    );
  }
}

enum LeaderboardPeriod { week, month, allTime }

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.user,
    required this.xp,
    this.rankChange = 0,
  });

  final int rank;
  final SocialUser user;
  final int xp;

  /// Positive = moved up since last period, negative = down, 0 = same.
  final int rankChange;
}
