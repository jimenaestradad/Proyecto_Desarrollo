import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/competition.dart';
import '../models/social_content.dart';
import '../models/social_people.dart';

/// Social tab contract backed by the in-memory [MockSocialRepository].
/// Future-based operations let screens handle loading and errors.
abstract class SocialRepository {
  /// Fires after any write. Screens that show social data listen to this so a
  /// change made on a pushed screen shows up when you come back (see
  /// SocialLoadState).
  Listenable get changes;

  // ── Identity & friends ────────────────────────────────────────────────
  /// Your own social profile — the signed-in account's real name, username,
  /// level, XP, streak and pet (the mock fills in the parts it can't read).
  Future<SocialUser> getMe();

  /// Drops anything cached about *you*. `AppData.bindToUser`/`unbindUser`
  /// call it so a second account never sees the first one's profile.
  void accountChanged();
  Future<List<SocialUser>> getFriends();
  Future<SocialUser> getUser(String id);

  /// Every person the screens might need to name (you, friends, requesters,
  /// search results), keyed by id — lets a post/standings list resolve
  /// `authorId`s without one call per row.
  Future<Map<String, SocialUser>> getUserDirectory();
  Future<List<FriendRequest>> getFriendRequests();
  Future<void> acceptFriendRequest(String userId);
  Future<void> declineFriendRequest(String userId);
  Future<void> sendFriendRequest(String userId);
  Future<void> cancelFriendRequest(String userId);
  Future<void> removeFriend(String userId);

  /// Matches name or @username (case-insensitive), excluding you and
  /// blocked users. Returns friends too so the UI can show "Already friends".
  Future<List<SocialUser>> searchUsers(String query);

  /// Friends-of-friends you could add (mutual friends only — no stranger
  /// discovery, per docs/FEATURES.md §10).
  Future<List<SocialUser>> getSuggestions();
  Future<bool> hasPendingRequestTo(String userId);

  /// Your @username and a shareable code/link for the invite screen.
  Future<({String username, String code, String link})> getInviteInfo();

  // ── Feed ──────────────────────────────────────────────────────────────
  /// [circleId] null = everyone you can see; otherwise only that circle's
  /// posts. Newest first.
  Future<List<SocialPost>> getPosts({String? circleId});
  Future<SocialPost> getPost(String id);
  Future<List<ProofableHabit>> getProofableHabits();
  Future<SocialPost> createPost({
    required ProofableHabit habit,
    required String caption,
    required bool withPhoto,
    Uint8List? photo,
    required PostVisibility visibility,
    String? circleId,
    String? competitionId,
  });
  Future<void> toggleReaction(String postId, Reaction reaction);
  Future<void> addComment(String postId, String text);
  Future<void> reportPost(String postId, ReportReason reason);

  // ── Circles ───────────────────────────────────────────────────────────
  Future<List<SocialCircle>> getCircles();
  Future<SocialCircle> getCircle(String id);
  Future<SocialCircle> createCircle({
    required String name,
    required IconData icon,
    required Color color,
    required List<String> memberIds,
  });
  Future<void> updateCircle(SocialCircle circle);
  Future<void> leaveCircle(String id);

  /// Sends a nudge to every other member; returns how many were nudged.
  Future<int> nudgeCircle(String id);

  // ── Leaderboard ───────────────────────────────────────────────────────
  Future<List<LeaderboardEntry>> getLeaderboard({
    String? circleId,
    LeaderboardPeriod period = LeaderboardPeriod.week,
  });

  // ── Competitions ──────────────────────────────────────────────────────
  Future<List<Competition>> getCompetitions();
  Future<Competition> getCompetition(String id);
  Future<Competition> createCompetition(CompetitionDraft draft);
  Future<void> acceptCompetitionInvite(String id);
  Future<void> declineCompetitionInvite(String id);
  Future<void> leaveCompetition(String id);

  /// Records today's proof (also posts it to the feed).
  Future<void> submitCompetitionProof(
    String id, {
    required String caption,
    required bool withPhoto,
    Uint8List? photo,
  });

  // ── Streaks, nudges, pets ─────────────────────────────────────────────
  Future<List<FriendStreak>> getFriendStreaks();
  Future<FriendStreak?> getFriendStreak(String friendId);
  Future<void> nudge(String friendId);
  Future<void> sendHighFive(String friendId);
  Future<List<CheerEntry>> getCheerLog(String friendId);
  Future<void> cheerPet(String friendId, CheerKind kind);

  // ── Notifications ─────────────────────────────────────────────────────
  Future<List<SocialNotification>> getNotifications();
  Future<int> getUnreadNotificationCount();
  Future<void> markAllNotificationsRead();
  Future<void> clearNotifications();

  // ── Privacy & blocking ────────────────────────────────────────────────
  Future<SocialPrivacy> getPrivacy();
  Future<void> updatePrivacy(SocialPrivacy privacy);
  Future<void> blockUser(String userId);
  Future<void> unblockUser(String userId);
  Future<List<SocialUser>> getBlockedUsers();

  // ── Achievements ──────────────────────────────────────────────────────
  /// Counters the Social achievements are computed from.
  Future<SocialActivity> getSocialActivity();

  // ── Mock-only ─────────────────────────────────────────────────────────
  /// Preview aid so the "no friends yet" first-run state can be seen without
  /// deleting every friend by hand. Delete with the mock.
  Future<void> resetDemo({required bool empty});
}
