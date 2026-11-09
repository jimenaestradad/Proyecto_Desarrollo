import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'session_photos.dart';

import '../models/competition.dart';
import '../models/social_content.dart';
import '../models/social_people.dart';
import '../theme/app_colors.dart';
import '../utils/id_generator.dart';
import 'social_account.dart';
import 'social_repository.dart';

/// In-memory stand-in for the Social backend: every list below is seed data
/// that screens read and mutate through [SocialRepository]. Resets on app
/// restart. See docs/technical/BACKEND.md (social is a non-goal there) — swap this for
/// a real implementation on `AppData.social` when it's built.
class MockSocialRepository extends ChangeNotifier implements SocialRepository {
  /// [account], when given, makes "you" the signed-in user (name, username,
  /// level, XP, streak, pet, last-7-days XP) and lets the proof composer offer
  /// the habits you actually completed today. Everyone else stays seed data.
  MockSocialRepository({SocialAccountSource? account}) : _account = account {
    _seed();
  }

  final SocialAccountSource? _account;

  /// Your real social profile once loaded; null until then (or if it can't be
  /// read), in which case [_seedMe] stands in.
  SocialUser? _liveMe;
  DateTime? _liveMeAt;
  Future<void>? _liveMeLoad;

  /// Bumped by [accountChanged], so a load still in flight for the previous
  /// account can't cache that account's profile as the new one's.
  int _accountGeneration = 0;

  /// Short cache: a screen often asks for you several times in one frame, and
  /// each refresh is a few Firestore reads.
  static const _liveMeTtl = Duration(seconds: 30);

  @override
  void accountChanged() {
    _accountGeneration++;
    _liveMeLoad = null;
    _liveMe = null;
    _liveMeAt = null;
    _users['me'] = _seedMe;
    notifyListeners();
  }

  /// Refreshes [_liveMe] from the account source if it's stale. Never throws:
  /// on any failure the previous (or seed) profile is kept so the tab still
  /// renders.
  Future<void> _refreshMe() {
    final account = _account;
    if (account == null) return Future.value();
    final at = _liveMeAt;
    if (at != null && DateTime.now().difference(at) < _liveMeTtl) {
      return Future.value();
    }
    final generation = _accountGeneration;
    return _liveMeLoad ??= () async {
      try {
        final me = await account.loadMe(_liveMe ?? _seedMe);
        if (generation != _accountGeneration) return;
        _liveMe = me;
        _users['me'] = me;
      } catch (_) {
        // Keep whatever "you" we already had.
      } finally {
        if (generation == _accountGeneration) {
          _liveMeAt = DateTime.now();
          _liveMeLoad = null;
        }
      }
    }();
  }

  @override
  Listenable get changes => this;

  // ── State ─────────────────────────────────────────────────────────────
  final Map<String, SocialUser> _users = {};
  final Set<String> _friendIds = {};
  final List<String> _incomingIds = [];
  final List<String> _outgoingIds = [];
  final Map<String, String> _requestNotes = {};
  List<SocialPost> _posts = [];
  List<SocialCircle> _circles = [];
  List<Competition> _competitions = [];
  final Map<String, FriendStreak> _streaks = {};
  List<SocialNotification> _notifications = [];
  SocialPrivacy _privacy = const SocialPrivacy();
  final Map<String, List<CheerEntry>> _cheers = {};
  int _reactionsGiven = 0;
  int _circlesCreated = 0;

  static const _seedMe = SocialUser(
    id: 'me',
    name: 'Hannah Walker',
    username: 'hannahw',
    level: 7,
    weeklyXp: 1320,
    totalXp: 3240,
    currentStreak: 8,
    proofCount: 11,
    petName: 'Nori',
    petStage: 1,
  );

  DateTime _ago({int minutes = 0, int hours = 0, int days = 0}) =>
      DateTime.now().subtract(
        Duration(minutes: minutes, hours: hours, days: days),
      );

  void _seed() {
    _users
      ..clear()
      ..addAll({
        'me': _liveMe ?? _seedMe,
        'jimena': SocialUser(
          id: 'jimena',
          avatarAsset: 'assets/images/social/avatar_jimena.jpg',
          name: 'Jimena Vargas',
          username: 'jimena',
          level: 8,
          weeklyXp: 1180,
          totalXp: 4120,
          currentStreak: 12,
          proofCount: 34,
          petName: 'Matcha',
          petStage: 2,
          statusLine: 'Drank 8 glasses today',
          friendSince: _ago(days: 120),
        ),
        'alexh': SocialUser(
          id: 'alexh',
          avatarAsset: 'assets/images/social/avatar_alexh.jpg',
          name: 'Alex Hart',
          username: 'alexh',
          level: 7,
          weeklyXp: 1450,
          totalXp: 3610,
          currentStreak: 21,
          proofCount: 27,
          petName: 'Bruno',
          petStage: 1,
          statusLine: 'Finished a gym session',
          friendSince: _ago(days: 95),
        ),
        'sarahj': SocialUser(
          id: 'sarahj',
          avatarAsset: 'assets/images/social/avatar_sarahj.jpg',
          name: 'Sarah Jenkins',
          username: 'sarahj',
          level: 6,
          weeklyXp: 980,
          totalXp: 2700,
          currentStreak: 5,
          proofCount: 15,
          petName: 'Pip',
          petStage: 1,
          statusLine: 'Read 10 pages',
          friendSince: _ago(days: 80),
        ),
        'miked': SocialUser(
          id: 'miked',
          avatarAsset: 'assets/images/social/avatar_miked.jpg',
          name: 'Mike Dalton',
          username: 'miked',
          level: 5,
          weeklyXp: 740,
          totalXp: 2050,
          currentStreak: 3,
          proofCount: 9,
          petName: 'Waffles',
          petStage: 0,
          statusLine: '4 habits today',
          friendSince: _ago(days: 60),
        ),
        'priya': SocialUser(
          id: 'priya',
          avatarAsset: 'assets/images/social/avatar_priya.jpg',
          name: 'Priya Patel',
          username: 'priya',
          level: 6,
          weeklyXp: 610,
          totalXp: 2380,
          currentStreak: 6,
          proofCount: 12,
          petName: 'Mochi',
          petStage: 1,
          statusLine: 'Meditated this morning',
          friendSince: _ago(days: 45),
        ),
        'tomas': SocialUser(
          id: 'tomas',
          avatarAsset: 'assets/images/social/avatar_tomas.jpg',
          name: 'Tomas Rivera',
          username: 'tomas',
          level: 4,
          weeklyXp: 420,
          totalXp: 1330,
          currentStreak: 2,
          proofCount: 4,
          petName: 'Clover',
          petStage: 0,
          statusLine: 'Joined last week',
          friendSince: _ago(days: 7),
        ),
        // Not friends yet: pending requests and discoverable people.
        'leochen': const SocialUser(
          id: 'leochen',
          avatarAsset: 'assets/images/social/avatar_leochen.jpg',
          name: 'Leo Chen',
          username: 'leochen',
          level: 6,
          weeklyXp: 700,
          totalXp: 2200,
          currentStreak: 4,
          proofCount: 8,
          petName: 'Tofu',
          petStage: 1,
          mutualFriends: 1,
        ),
        'clarab': const SocialUser(
          id: 'clarab',
          avatarAsset: 'assets/images/social/avatar_clarab.jpg',
          name: 'Clara Brooks',
          username: 'clarab',
          level: 5,
          weeklyXp: 540,
          totalXp: 1800,
          currentStreak: 7,
          proofCount: 6,
          petName: 'Biscuit',
          petStage: 0,
          mutualFriends: 2,
        ),
        'koawood': const SocialUser(
          id: 'koawood',
          avatarAsset: 'assets/images/social/avatar_koawood.jpg',
          name: 'Koa Wood',
          username: 'koawood',
          level: 6,
          weeklyXp: 650,
          totalXp: 2100,
          currentStreak: 9,
          proofCount: 10,
          petName: 'Sprout',
          petStage: 1,
          mutualFriends: 3,
        ),
        'elenar': const SocialUser(
          id: 'elenar',
          avatarAsset: 'assets/images/social/avatar_elenar.jpg',
          name: 'Elena Rostova',
          username: 'elenar',
          level: 7,
          weeklyXp: 900,
          totalXp: 3000,
          currentStreak: 14,
          proofCount: 20,
          petName: 'Juniper',
          petStage: 2,
          mutualFriends: 2,
        ),
        'samura': const SocialUser(
          id: 'samura',
          avatarAsset: 'assets/images/social/avatar_samura.jpg',
          name: 'Sam Aura',
          username: 'samura',
          level: 3,
          weeklyXp: 210,
          totalXp: 600,
          currentStreak: 1,
          proofCount: 1,
          petName: 'Dot',
          petStage: 0,
        ),
      });

    _friendIds
      ..clear()
      ..addAll(['jimena', 'alexh', 'sarahj', 'miked', 'priya', 'tomas']);
    _incomingIds
      ..clear()
      ..addAll(['leochen', 'clarab']);
    _outgoingIds.clear();
    _requestNotes
      ..clear()
      ..addAll({
        'leochen': 'Mutual friend with Alex',
        'clarab': 'Invited you to Hydration Sprint',
      });
    _privacy = const SocialPrivacy();
    _reactionsGiven = 3;
    _circlesCreated = 0;

    _circles = [
      SocialCircle(
        id: 'roommates',
        coverAsset: 'assets/images/social/cover_circle_roommates.jpg',
        name: 'Roommates',
        icon: Icons.cottage,
        color: AppColors.mossLight,
        memberIds: const ['me', 'sarahj', 'priya'],
        completionRate: 0.85,
        activityLine: '85% daily check-in',
      ),
      SocialCircle(
        id: 'gym',
        coverAsset: 'assets/images/social/cover_circle_gym.jpg',
        name: 'Gym Buddies',
        icon: Icons.fitness_center,
        color: AppColors.mustardLight,
        memberIds: const ['me', 'alexh', 'jimena', 'miked', 'tomas'],
        completionRate: 0.72,
        activityLine: 'Hydration Sprint live',
      ),
    ];

    _seedPosts();
    _seedCompetitions();
    _seedStreaks();
    _seedNotifications();
    _cheers
      ..clear()
      ..addAll({
        'jimena': [
          CheerEntry(
            fromId: 'sarahj',
            kind: CheerKind.treat,
            createdAt: _ago(hours: 1),
          ),
          CheerEntry(
            fromId: 'me',
            kind: CheerKind.hug,
            createdAt: _ago(days: 1),
          ),
        ],
      });
  }

  void _seedPosts() {
    _posts = [
      SocialPost(
        id: 'p1',
        photoAsset: 'assets/images/social/proof_water.jpg',
        authorId: 'jimena',
        habitName: 'Drink 8 glasses of water',
        habitIcon: Icons.water_drop,
        habitColor: AppColors.sky,
        caption:
            'Morning 1.5L jug crushed before 9am! Matcha is watered and happy.',
        createdAt: _ago(minutes: 25),
        circleId: 'gym',
        competitionId: 'hydration',
        xpEarned: 45,
        reactionCounts: const {
          Reaction.love: 7,
          Reaction.celebrate: 4,
          Reaction.thumbsUp: 2,
        },
        comments: [
          PostComment(
            id: 'c1',
            authorId: 'alexh',
            text: 'Crushing it Jimena! Catching up right behind you.',
            createdAt: _ago(minutes: 18),
          ),
          PostComment(
            id: 'c2',
            authorId: 'sarahj',
            text: 'Matcha looks so happy!',
            createdAt: _ago(minutes: 10),
          ),
        ],
      ),
      SocialPost(
        id: 'p2',
        photoAsset: 'assets/images/social/proof_gym.jpg',
        authorId: 'alexh',
        habitName: 'Gym Session: Upper Body',
        habitIcon: Icons.fitness_center,
        habitColor: AppColors.mustardLight,
        caption:
            'Consistency beat motivation this morning. Set a personal record on pull-ups!',
        createdAt: _ago(hours: 2),
        circleId: 'gym',
        competitionId: 'gym-warriors',
        xpEarned: 50,
        reactionCounts: const {
          Reaction.love: 12,
          Reaction.celebrate: 9,
          Reaction.strong: 4,
        },
        comments: [
          PostComment(
            id: 'c3',
            authorId: 'miked',
            text: 'Beast. Spot me tomorrow?',
            createdAt: _ago(hours: 1),
          ),
        ],
      ),
      SocialPost(
        id: 'p3',
        photoAsset: 'assets/images/social/proof_read.jpg',
        authorId: 'sarahj',
        habitName: 'Read 10 mins',
        habitIcon: Icons.menu_book,
        habitColor: AppColors.blushPink,
        caption: 'Finished another chapter of Atomic Habits.',
        createdAt: _ago(hours: 5),
        circleId: 'roommates',
        reactionCounts: const {Reaction.thumbsUp: 2},
      ),
      SocialPost(
        id: 'p4',
        photoAsset: 'assets/images/social/cover_circle_gym.jpg',
        authorId: 'me',
        habitName: 'Gym Session: Upper Body',
        habitIcon: Icons.fitness_center,
        habitColor: AppColors.mustardLight,
        caption: 'Upper body day, done.',
        createdAt: _ago(days: 1),
        circleId: 'gym',
        xpEarned: 50,
        reactionCounts: const {Reaction.love: 3, Reaction.fire: 1},
        comments: [
          PostComment(
            id: 'c4',
            authorId: 'jimena',
            text: 'Nice work!',
            createdAt: _ago(hours: 20),
          ),
        ],
      ),
      SocialPost(
        id: 'p5',
        photoAsset: 'assets/images/social/proof_run.jpg',
        authorId: 'miked',
        habitName: 'Morning Run',
        habitIcon: Icons.directions_run,
        habitColor: AppColors.mossLight,
        caption: '5k before work. Legs are jelly.',
        createdAt: _ago(days: 1, hours: 3),
        reactionCounts: const {Reaction.strong: 5, Reaction.love: 2},
      ),
      SocialPost(
        id: 'p6',
        photoAsset: 'assets/images/social/proof_meditate.jpg',
        authorId: 'priya',
        habitName: 'Meditate',
        habitIcon: Icons.self_improvement,
        habitColor: AppColors.sky,
        caption: '10 quiet minutes before the day starts.',
        createdAt: _ago(days: 2),
        circleId: 'roommates',
        reactionCounts: const {Reaction.love: 4},
      ),
      SocialPost(
        id: 'p7',
        authorId: 'tomas',
        photoAsset: 'assets/images/social/proof_nosocial.jpg',
        habitName: 'No social media',
        habitIcon: Icons.phonelink_off,
        habitColor: AppColors.blushPink,
        caption: 'Phone face-down until Monday. Notebook out instead.',
        createdAt: _ago(hours: 9),
        reactionCounts: const {Reaction.thumbsUp: 3, Reaction.celebrate: 1},
      ),
    ];
  }

  void _seedCompetitions() {
    final now = DateTime.now();
    _competitions = [
      Competition(
        id: 'hydration',
        coverAsset: 'assets/images/social/cover_comp_hydration.jpg',
        title: 'Hydration Sprint',
        description: 'Drink 8 glasses of water every day for 7 days.',
        type: CompetitionType.total,
        habitName: 'Drink 8 glasses of water',
        icon: Icons.water_drop,
        color: AppColors.sky,
        hostId: 'jimena',
        participantIds: const ['jimena', 'me', 'alexh', 'tomas'],
        progress: const {'jimena': 7, 'me': 6, 'alexh': 5, 'tomas': 4},
        targetCount: 7,
        startsAt: now
            .add(const Duration(hours: 18))
            .subtract(const Duration(days: 7)),
        endsAt: now.add(const Duration(hours: 18)),
        status: CompetitionStatus.active,
        prizeXp: 100,
        circleId: 'gym',
      ),
      Competition(
        id: 'gym-warriors',
        coverAsset: 'assets/images/social/cover_comp_gym.jpg',
        title: 'Gym Warriors',
        description: 'Log at least 4 strength sessions this week.',
        type: CompetitionType.race,
        habitName: 'Gym Session',
        icon: Icons.fitness_center,
        color: AppColors.mustardLight,
        hostId: 'alexh',
        participantIds: const ['alexh', 'me', 'jimena', 'miked', 'tomas'],
        progress: const {
          'alexh': 4,
          'me': 3,
          'jimena': 3,
          'miked': 2,
          'tomas': 1,
        },
        targetCount: 4,
        startsAt: now.subtract(const Duration(days: 3)),
        endsAt: now.add(const Duration(days: 4)),
        status: CompetitionStatus.active,
        prizeXp: 150,
        circleId: 'gym',
      ),
      Competition(
        id: 'no-social',
        coverAsset: 'assets/images/social/cover_comp_nosocial.jpg',
        title: 'No Social Media Weekend',
        description: 'Stay under your social media limit for 2 days straight.',
        type: CompetitionType.streak,
        habitName: 'No social media',
        icon: Icons.phonelink_off,
        color: AppColors.blushPink,
        hostId: 'sarahj',
        participantIds: const ['sarahj', 'priya'],
        progress: const {'sarahj': 0, 'priya': 0},
        targetCount: 2,
        startsAt: now.add(const Duration(days: 1)),
        endsAt: now.add(const Duration(days: 3)),
        status: CompetitionStatus.invited,
        prizeXp: 80,
        circleId: 'roommates',
        invitedById: 'sarahj',
      ),
      Competition(
        id: 'morning-run',
        coverAsset: 'assets/images/social/cover_comp_run.jpg',
        title: 'Morning Run Streak',
        description: 'Run every morning for 5 days.',
        type: CompetitionType.streak,
        habitName: 'Morning Run',
        icon: Icons.directions_run,
        color: AppColors.mossLight,
        hostId: 'alexh',
        participantIds: const ['alexh', 'me', 'jimena'],
        progress: const {'alexh': 5, 'me': 4, 'jimena': 2},
        targetCount: 5,
        startsAt: now.subtract(const Duration(days: 11)),
        endsAt: now.subtract(const Duration(days: 6)),
        status: CompetitionStatus.past,
        prizeXp: 120,
      ),
    ];
  }

  List<StreakDay> _days({
    required int current,
    required bool todayBoth,
    bool todayFriend = false,
  }) {
    final today = DateTime.now();
    final days = <StreakDay>[];
    for (var ago = 13; ago >= 0; ago--) {
      final date = DateTime(today.year, today.month, today.day - ago);
      late final bool me;
      late final bool friend;
      if (ago == 0) {
        me = true;
        friend = todayBoth || todayFriend;
      } else {
        final inStreak = todayBoth ? ago < current : ago <= current;
        if (inStreak) {
          me = true;
          friend = true;
        } else if (ago == (todayBoth ? current : current + 1)) {
          me = true;
          friend = false;
        } else {
          me = ago.isEven;
          friend = ago % 3 == 0;
        }
      }
      days.add(StreakDay(date: date, me: me, friend: friend));
    }
    return days;
  }

  void _seedStreaks() {
    _streaks
      ..clear()
      ..addAll({
        'jimena': FriendStreak(
          friendId: 'jimena',
          current: 12,
          best: 12,
          days: _days(current: 12, todayBoth: true),
          nextBadgeLabel: 'Two Weeks Strong',
          daysToBadge: 2,
        ),
        'alexh': FriendStreak(
          friendId: 'alexh',
          current: 5,
          best: 9,
          days: _days(current: 5, todayBoth: false),
          nextBadgeLabel: 'One Week Strong',
          daysToBadge: 2,
        ),
        'priya': FriendStreak(
          friendId: 'priya',
          current: 2,
          best: 4,
          days: _days(current: 2, todayBoth: true),
          nextBadgeLabel: 'First Week',
          daysToBadge: 5,
        ),
      });
  }

  void _seedNotifications() {
    _notifications = [
      SocialNotification(
        id: 'n1',
        kind: SocialNotificationKind.reaction,
        message: 'Jimena loved your gym session proof.',
        createdAt: _ago(minutes: 12),
        icon: Icons.favorite,
        color: AppColors.blushPink,
        actorId: 'jimena',
        refId: 'p4',
      ),
      SocialNotification(
        id: 'n2',
        kind: SocialNotificationKind.friendRequest,
        message: 'Leo Chen wants to be your friend.',
        createdAt: _ago(minutes: 40),
        icon: Icons.person_add,
        color: AppColors.mossLight,
        actorId: 'leochen',
        refId: 'leochen',
      ),
      SocialNotification(
        id: 'n3',
        kind: SocialNotificationKind.competitionInvite,
        message: 'Sarah invited you to No Social Media Weekend.',
        createdAt: _ago(hours: 1),
        icon: Icons.emoji_events,
        color: AppColors.mustardLight,
        actorId: 'sarahj',
        refId: 'no-social',
      ),
      SocialNotification(
        id: 'n4',
        kind: SocialNotificationKind.nudge,
        message: 'Alex sent you an encouraging nudge.',
        createdAt: _ago(hours: 1, minutes: 20),
        icon: Icons.waving_hand,
        color: AppColors.sky,
        actorId: 'alexh',
      ),
      SocialNotification(
        id: 'n5',
        kind: SocialNotificationKind.streakAtRisk,
        message: 'Your streak with Alex is at risk. Do a habit today!',
        createdAt: _ago(hours: 2),
        icon: Icons.local_fire_department,
        color: AppColors.terracotta,
        actorId: 'alexh',
        refId: 'alexh',
      ),
      SocialNotification(
        id: 'n6',
        kind: SocialNotificationKind.rank,
        message: "You moved up to rank #2 on this week's leaderboard.",
        createdAt: _ago(hours: 3),
        icon: Icons.military_tech,
        color: AppColors.mustard,
        isRead: true,
      ),
      SocialNotification(
        id: 'n7',
        kind: SocialNotificationKind.comment,
        message: 'Sarah commented on Jimena\'s post.',
        createdAt: _ago(hours: 5),
        icon: Icons.chat_bubble,
        color: AppColors.blush,
        actorId: 'sarahj',
        refId: 'p1',
        isRead: true,
      ),
      SocialNotification(
        id: 'n8',
        kind: SocialNotificationKind.highFive,
        message: 'Jimena sent you a high-five for your 12-day streak.',
        createdAt: _ago(days: 1),
        icon: Icons.celebration,
        color: AppColors.mossLight,
        actorId: 'jimena',
        refId: 'jimena',
        isRead: true,
      ),
    ];
  }

  // ── Identity & friends ────────────────────────────────────────────────
  @override
  Future<SocialUser> getMe() async {
    await _refreshMe();
    return _users['me']!;
  }

  @override
  Future<List<SocialUser>> getFriends() async {
    final friends = _friendIds
        .map((id) => _users[id]!)
        .where((u) => !_privacy.blockedIds.contains(u.id))
        .toList();
    friends.sort((a, b) => a.name.compareTo(b.name));
    return friends;
  }

  @override
  Future<SocialUser> getUser(String id) async {
    if (id == 'me') await _refreshMe();
    final user = _users[id];
    if (user == null) throw StateError('Unknown social user: $id');
    return user;
  }

  @override
  Future<Map<String, SocialUser>> getUserDirectory() async {
    await _refreshMe();
    return Map.of(_users);
  }

  @override
  Future<List<FriendRequest>> getFriendRequests() async => [
    for (final id in _incomingIds)
      FriendRequest(
        user: _users[id]!,
        direction: FriendRequestDirection.incoming,
        note: _requestNotes[id] ?? '',
      ),
    for (final id in _outgoingIds)
      FriendRequest(
        user: _users[id]!,
        direction: FriendRequestDirection.outgoing,
        note: 'Request sent',
      ),
  ];

  @override
  Future<void> acceptFriendRequest(String userId) async {
    if (!_incomingIds.remove(userId)) return;
    _friendIds.add(userId);
    _users[userId] = _withFriendSince(_users[userId]!);
    _notifications = [
      for (final n in _notifications)
        if (!(n.kind == SocialNotificationKind.friendRequest &&
            n.refId == userId))
          n,
    ];
    notifyListeners();
  }

  SocialUser _withFriendSince(SocialUser u) => SocialUser(
    id: u.id,
    name: u.name,
    username: u.username,
    level: u.level,
    weeklyXp: u.weeklyXp,
    totalXp: u.totalXp,
    currentStreak: u.currentStreak,
    proofCount: u.proofCount,
    petName: u.petName,
    petStage: u.petStage,
    statusLine: u.statusLine,
    friendSince: DateTime.now(),
    mutualFriends: u.mutualFriends,
    avatarAsset: u.avatarAsset,
  );

  @override
  Future<void> declineFriendRequest(String userId) async {
    _incomingIds.remove(userId);
    _notifications = [
      for (final n in _notifications)
        if (!(n.kind == SocialNotificationKind.friendRequest &&
            n.refId == userId))
          n,
    ];
    notifyListeners();
  }

  @override
  Future<void> sendFriendRequest(String userId) async {
    if (_friendIds.contains(userId) || _outgoingIds.contains(userId)) return;
    _outgoingIds.add(userId);
    notifyListeners();
  }

  @override
  Future<void> cancelFriendRequest(String userId) async {
    _outgoingIds.remove(userId);
    notifyListeners();
  }

  @override
  Future<void> removeFriend(String userId) async {
    _friendIds.remove(userId);
    _streaks.remove(userId);
    _circles = [
      for (final c in _circles)
        c.copyWith(memberIds: c.memberIds.where((id) => id != userId).toList()),
    ];
    notifyListeners();
  }

  @override
  Future<List<SocialUser>> searchUsers(String query) async {
    final q = query.trim().toLowerCase().replaceFirst('@', '');
    if (q.isEmpty) return [];
    return _users.values
        .where(
          (u) =>
              !u.isMe &&
              !_privacy.blockedIds.contains(u.id) &&
              (u.username.toLowerCase().contains(q) ||
                  u.name.toLowerCase().contains(q)),
        )
        .toList();
  }

  @override
  Future<List<SocialUser>> getSuggestions() async => [
    for (final id in ['koawood', 'elenar'])
      if (!_friendIds.contains(id) &&
          !_privacy.blockedIds.contains(id) &&
          _friendIds.isNotEmpty)
        _users[id]!,
  ];

  @override
  Future<bool> hasPendingRequestTo(String userId) async =>
      _outgoingIds.contains(userId);

  @override
  Future<({String username, String code, String link})> getInviteInfo() async {
    await _refreshMe();
    final username = _users['me']!.username;
    // Mock code, derived from the username so it's stable per account.
    final code = username.codeUnits.fold<int>(0, (sum, c) => sum + c) % 9000;
    return (
      username: username,
      code: '#NORI-${1000 + code}',
      link: 'nori-pet.web.app/add/$username',
    );
  }

  // ── Feed ──────────────────────────────────────────────────────────────
  @override
  Future<List<SocialPost>> getPosts({String? circleId}) async {
    final visible = _posts.where((p) {
      if (_privacy.blockedIds.contains(p.authorId)) return false;
      if (p.visibility == PostVisibility.onlyMe && p.authorId != 'me') {
        return false;
      }
      if (circleId != null) return p.circleId == circleId;
      return true;
    }).toList();
    visible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return visible;
  }

  @override
  Future<SocialPost> getPost(String id) async =>
      _posts.firstWhere((p) => p.id == id);

  @override
  Future<List<ProofableHabit>> getProofableHabits() async {
    // Your real completed-today habits when there are any; otherwise the
    // sample list below so the composer stays demoable (nothing here is
    // written to the backend either way).
    final real = await _account?.loadCompletedHabitsToday();
    if (real != null && real.isNotEmpty) return real;
    return _sampleProofHabits;
  }

  static const _sampleProofHabits = [
    ProofableHabit(
      id: 'water',
      name: 'Drink 8 glasses of water',
      icon: Icons.water_drop,
      color: AppColors.sky,
    ),
    ProofableHabit(
      id: 'gym',
      name: 'Gym Session: Upper Body',
      icon: Icons.fitness_center,
      color: AppColors.mustardLight,
    ),
    ProofableHabit(
      id: 'read',
      name: 'Mindful Reading (15 mins)',
      icon: Icons.menu_book,
      color: AppColors.blushPink,
    ),
  ];

  @override
  Future<SocialPost> createPost({
    required ProofableHabit habit,
    required String caption,
    required bool withPhoto,
    Uint8List? photo,
    required PostVisibility visibility,
    String? circleId,
    String? competitionId,
  }) async {
    final post = SocialPost(
      id: generateId(),
      authorId: 'me',
      habitName: habit.name,
      habitIcon: habit.icon,
      habitColor: habit.color,
      caption: caption.trim().isEmpty ? 'Done for today.' : caption.trim(),
      createdAt: DateTime.now(),
      hasProof: withPhoto,
      visibility: visibility,
      circleId: circleId,
      competitionId: competitionId,
      xpEarned: withPhoto ? 50 : 0,
    );
    if (photo != null) SessionPhotos.setProof(post.id, photo);
    _posts = [post, ..._posts];
    notifyListeners();
    return post;
  }

  @override
  Future<void> toggleReaction(String postId, Reaction reaction) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index < 0) return;
    final post = _posts[index];
    final mine = {...post.myReactions};
    final counts = {...post.reactionCounts};
    if (mine.remove(reaction)) {
      counts[reaction] = ((counts[reaction] ?? 1) - 1).clamp(0, 1 << 30);
      if (post.authorId != 'me') _reactionsGiven--;
    } else {
      mine.add(reaction);
      counts[reaction] = (counts[reaction] ?? 0) + 1;
      if (post.authorId != 'me') _reactionsGiven++;
    }
    _posts[index] = post.copyWith(reactionCounts: counts, myReactions: mine);
    notifyListeners();
  }

  @override
  Future<void> addComment(String postId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index < 0) return;
    final post = _posts[index];
    _posts[index] = post.copyWith(
      comments: [
        ...post.comments,
        PostComment(
          id: generateId(),
          authorId: 'me',
          text: trimmed,
          createdAt: DateTime.now(),
        ),
      ],
    );
    notifyListeners();
  }

  @override
  Future<void> reportPost(String postId, ReportReason reason) async {
    // Mock: reporting just hides the post for you.
    _posts = _posts.where((p) => p.id != postId).toList();
    notifyListeners();
  }

  // ── Circles ───────────────────────────────────────────────────────────
  @override
  Future<List<SocialCircle>> getCircles() async => List.of(_circles);

  @override
  Future<SocialCircle> getCircle(String id) async =>
      _circles.firstWhere((c) => c.id == id);

  @override
  Future<SocialCircle> createCircle({
    required String name,
    required IconData icon,
    required Color color,
    required List<String> memberIds,
  }) async {
    final circle = SocialCircle(
      id: generateId(),
      name: name.trim(),
      icon: icon,
      color: color,
      memberIds: ['me', ...memberIds.where((id) => id != 'me')],
      completionRate: 0,
      activityLine: 'Just created',
    );
    _circles = [..._circles, circle];
    _circlesCreated++;
    notifyListeners();
    return circle;
  }

  @override
  Future<void> updateCircle(SocialCircle circle) async {
    _circles = [for (final c in _circles) c.id == circle.id ? circle : c];
    notifyListeners();
  }

  @override
  Future<void> leaveCircle(String id) async {
    _circles = _circles.where((c) => c.id != id).toList();
    notifyListeners();
  }

  @override
  Future<int> nudgeCircle(String id) async => (await getCircle(id)).friendCount;

  // ── Leaderboard ───────────────────────────────────────────────────────
  @override
  Future<List<LeaderboardEntry>> getLeaderboard({
    String? circleId,
    LeaderboardPeriod period = LeaderboardPeriod.week,
  }) async {
    await _refreshMe();
    final memberIds = circleId == null
        ? {'me', ..._friendIds}
        : {..._circles.firstWhere((c) => c.id == circleId).memberIds};
    final users = memberIds
        .map((id) => _users[id]!)
        .where((u) => u.isMe || !_privacy.blockedIds.contains(u.id))
        .toList();
    int xpOf(SocialUser u) => switch (period) {
      LeaderboardPeriod.week => u.weeklyXp,
      LeaderboardPeriod.month => (u.weeklyXp * 3.6).round(),
      LeaderboardPeriod.allTime => u.totalXp,
    };
    users.sort((a, b) => xpOf(b).compareTo(xpOf(a)));
    const changes = {'me': 1, 'jimena': -1, 'alexh': 0, 'sarahj': 2};
    return [
      for (var i = 0; i < users.length; i++)
        LeaderboardEntry(
          rank: i + 1,
          user: users[i],
          xp: xpOf(users[i]),
          rankChange: changes[users[i].id] ?? 0,
        ),
    ];
  }

  // ── Competitions ──────────────────────────────────────────────────────
  @override
  Future<List<Competition>> getCompetitions() async => List.of(_competitions);

  @override
  Future<Competition> getCompetition(String id) async =>
      _competitions.firstWhere((c) => c.id == id);

  void _replaceCompetition(Competition updated) {
    _competitions = [
      for (final c in _competitions) c.id == updated.id ? updated : c,
    ];
  }

  @override
  Future<Competition> createCompetition(CompetitionDraft draft) async {
    final now = DateTime.now();
    final competition = Competition(
      id: generateId(),
      title: draft.title.trim(),
      description: '${draft.type.blurb} — ${draft.habitName}.',
      type: draft.type,
      habitName: draft.habitName,
      icon: draft.icon,
      color: draft.color,
      hostId: 'me',
      participantIds: ['me', ...draft.inviteeIds],
      progress: {'me': 0, for (final id in draft.inviteeIds) id: 0},
      targetCount: draft.targetCount,
      startsAt: now,
      endsAt: now.add(Duration(days: draft.durationDays)),
      status: CompetitionStatus.active,
      circleId: draft.circleId,
    );
    _competitions = [competition, ..._competitions];
    notifyListeners();
    return competition;
  }

  @override
  Future<void> acceptCompetitionInvite(String id) async {
    final c = _competitions.firstWhere((c) => c.id == id);
    _replaceCompetition(
      c.copyWith(
        status: CompetitionStatus.active,
        participantIds: [...c.participantIds, 'me'],
        progress: {...c.progress, 'me': 0},
      ),
    );
    _notifications = [
      for (final n in _notifications)
        if (!(n.kind == SocialNotificationKind.competitionInvite &&
            n.refId == id))
          n,
    ];
    notifyListeners();
  }

  @override
  Future<void> declineCompetitionInvite(String id) async {
    _competitions = _competitions.where((c) => c.id != id).toList();
    _notifications = [
      for (final n in _notifications)
        if (!(n.kind == SocialNotificationKind.competitionInvite &&
            n.refId == id))
          n,
    ];
    notifyListeners();
  }

  @override
  Future<void> leaveCompetition(String id) async {
    _competitions = _competitions.where((c) => c.id != id).toList();
    notifyListeners();
  }

  @override
  Future<void> submitCompetitionProof(
    String id, {
    required String caption,
    required bool withPhoto,
    Uint8List? photo,
  }) async {
    final c = _competitions.firstWhere((c) => c.id == id);
    if (c.submittedToday) return;
    _replaceCompetition(
      c.copyWith(
        progress: {...c.progress, 'me': c.myProgress + 1},
        submittedToday: true,
      ),
    );
    final postId = generateId();
    if (photo != null) SessionPhotos.setProof(postId, photo);
    _posts = [
      SocialPost(
        id: postId,
        authorId: 'me',
        habitName: c.habitName,
        habitIcon: c.icon,
        habitColor: c.color,
        caption: caption.trim().isEmpty
            ? 'Checked in for ${c.title}.'
            : caption,
        createdAt: DateTime.now(),
        hasProof: withPhoto,
        circleId: c.circleId,
        competitionId: c.id,
        xpEarned: 50,
      ),
      ..._posts,
    ];
    notifyListeners();
  }

  // ── Streaks, nudges, pets ─────────────────────────────────────────────
  @override
  Future<List<FriendStreak>> getFriendStreaks() async {
    final streaks = _streaks.values
        .where((s) => _friendIds.contains(s.friendId))
        .toList();
    streaks.sort((a, b) => b.current.compareTo(a.current));
    return streaks;
  }

  @override
  Future<FriendStreak?> getFriendStreak(String friendId) async =>
      _streaks[friendId];

  @override
  Future<void> nudge(String friendId) async {
    // Mock: nothing to deliver; the UI shows its own confirmation.
  }

  @override
  Future<void> sendHighFive(String friendId) async {}

  @override
  Future<List<CheerEntry>> getCheerLog(String friendId) async =>
      List.of(_cheers[friendId] ?? const []);

  @override
  Future<void> cheerPet(String friendId, CheerKind kind) async {
    _cheers[friendId] = [
      CheerEntry(fromId: 'me', kind: kind, createdAt: DateTime.now()),
      ...(_cheers[friendId] ?? const []),
    ];
    notifyListeners();
  }

  // ── Notifications ─────────────────────────────────────────────────────
  @override
  Future<List<SocialNotification>> getNotifications() async =>
      List.of(_notifications);

  @override
  Future<int> getUnreadNotificationCount() async =>
      _notifications.where((n) => !n.isRead).length;

  @override
  Future<void> markAllNotificationsRead() async {
    _notifications = [for (final n in _notifications) n.copyWith(isRead: true)];
    notifyListeners();
  }

  @override
  Future<void> clearNotifications() async {
    _notifications = [];
    notifyListeners();
  }

  // ── Privacy & blocking ────────────────────────────────────────────────
  @override
  Future<SocialPrivacy> getPrivacy() async => _privacy;

  @override
  Future<void> updatePrivacy(SocialPrivacy privacy) async {
    _privacy = privacy;
    notifyListeners();
  }

  @override
  Future<void> blockUser(String userId) async {
    _friendIds.remove(userId);
    _incomingIds.remove(userId);
    _outgoingIds.remove(userId);
    _streaks.remove(userId);
    _privacy = _privacy.copyWith(blockedIds: [..._privacy.blockedIds, userId]);
    notifyListeners();
  }

  @override
  Future<void> unblockUser(String userId) async {
    _privacy = _privacy.copyWith(
      blockedIds: _privacy.blockedIds.where((id) => id != userId).toList(),
    );
    notifyListeners();
  }

  @override
  Future<List<SocialUser>> getBlockedUsers() async => [
    for (final id in _privacy.blockedIds) _users[id]!,
  ];

  // ── Achievements ──────────────────────────────────────────────────────
  @override
  Future<SocialActivity> getSocialActivity() async => SocialActivity(
    reactionsGiven: _reactionsGiven,
    challengesCompleted: _competitions
        .where((c) => c.status == CompetitionStatus.past)
        .length,
    proofPosts: _posts.where((p) => p.authorId == 'me' && p.hasProof).length,
    circlesCreated: _circlesCreated,
    friendCount: _friendIds.length,
  );

  // ── Mock-only ─────────────────────────────────────────────────────────
  @override
  Future<void> resetDemo({required bool empty}) async {
    _seed();
    if (empty) {
      _friendIds.clear();
      _incomingIds.clear();
      _outgoingIds.clear();
      _posts = [];
      _circles = [];
      _competitions = [];
      _streaks.clear();
      _notifications = [];
      _cheers.clear();
      _reactionsGiven = 0;
    }
    notifyListeners();
  }
}
