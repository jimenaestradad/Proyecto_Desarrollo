import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/achievement.dart';
import '../models/app_notification.dart';
import '../theme/app_colors.dart';
import 'achievement_repository.dart';
import 'habit_history_store.dart' show dayKey;
import 'notification_repository.dart';
import 'user_repository.dart';

/// Real Firestore-backed [NotificationRepository] for
/// `/users/{uid}/notifications/{id}` -- in-app only, no push (docs/BACKEND.md,
/// "In-app notifications").
///
/// Most notifications are written server-side, in the transaction of the
/// event itself: level-up, evolution and the first-completion gift by
/// claimHabit/completeBucketListItem, pet care by the hourly petCareCheck
/// (functions/src/notifications.ts). Streaks and achievements are only ever
/// computed here on the client, so [getNotifications] syncs those two first:
/// it compares them against the client's fields on
/// `/users/{uid}/notificationState/main` and writes what's new. Not
/// currency, so a direct rules-guarded write -- the worst a client can do
/// is spoof notifications into its own feed.
///
/// The first client sync only records a baseline, so an existing account
/// isn't flooded with one notification per past achievement.
class FirestoreNotificationRepository implements NotificationRepository {
  FirestoreNotificationRepository({
    required String uid,
    required UserRepository user,
    required AchievementRepository achievements,
    FirebaseFirestore? firestore,
  }) : _uid = uid,
       _user = user,
       _achievements = achievements,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final String _uid;
  final UserRepository _user;
  final AchievementRepository _achievements;
  final FirebaseFirestore _firestore;

  static const _streakMilestones = [3, 7, 14, 30, 60, 100, 180, 365];

  static const _pageSize = 50;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _userDoc.collection('notifications');

  DocumentReference<Map<String, dynamic>> get _stateDoc =>
      _userDoc.collection('notificationState').doc('main');

  @override
  Future<List<AppNotification>> getNotifications() async {
    await _sync();
    final snapshot = await _collection
        .orderBy('createdAt', descending: true)
        .limit(_pageSize)
        .get();
    return [for (final doc in snapshot.docs) _fromDoc(doc)];
  }

  @override
  Stream<bool> watchHasUnread() => _collection
      .where('isRead', isEqualTo: false)
      .limit(1)
      .snapshots()
      .map((snapshot) => snapshot.docs.isNotEmpty);

  @override
  Future<void> markAllRead() async {
    final unread = await _collection.where('isRead', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> _sync() async {
    // Gathered outside the transaction: these repositories do their own
    // reads, which can't join it.
    final user = await _user.getCurrentUser();
    final unlocked = {
      for (final list
          in (await _achievements.getAchievementsByCategory()).values)
        for (final a in list)
          if (a.status == AchievementStatus.unlocked) a.id: a,
    };
    final today = dayKey(DateTime.now());
    final streakMilestone = _streakMilestones.lastWhere(
      (m) => m <= user.currentStreak,
      orElse: () => 0,
    );

    // A transaction so two overlapping syncs can't both see the old state
    // and double-notify. Merge writes: the server owns the doc's other
    // fields (level, petEvolved, petCareAt).
    await _firestore.runTransaction((tx) async {
      final state = (await tx.get(_stateDoc)).data();
      if (state?['achievementIds'] == null) {
        tx.set(_stateDoc, {
          'achievementIds': unlocked.keys.toList(),
          'streakMilestone': streakMilestone,
          'streakMilestoneDay': today,
        }, SetOptions(merge: true));
        return;
      }

      void notify(String kind, String message) {
        tx.set(_collection.doc(), {
          'kind': kind,
          'message': message,
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      // Achievements only ratchet up, so losing one (unclaiming a day) and
      // earning it back doesn't notify twice.
      final notifiedAchievements = {
        ...((state!['achievementIds'] as List?) ?? const []).cast<String>(),
      };
      for (final entry in unlocked.entries) {
        if (notifiedAchievements.contains(entry.key)) continue;
        notify(
          'achievement',
          'You unlocked the "${entry.value.title}" achievement!',
        );
      }

      // The milestone resets when the streak breaks, so the next streak
      // earns its own milestones -- but not within the same day, so undoing
      // and redoing today's claim doesn't re-notify.
      var notifiedMilestone = (state['streakMilestone'] as num?)?.toInt() ?? 0;
      var milestoneDay = state['streakMilestoneDay'] as String?;
      if (streakMilestone > notifiedMilestone) {
        notify('streak', 'You hit a $streakMilestone-day streak! Keep going!');
        notifiedMilestone = streakMilestone;
        milestoneDay = today;
      } else if (streakMilestone < notifiedMilestone && milestoneDay != today) {
        notifiedMilestone = streakMilestone;
        milestoneDay = today;
      }

      tx.set(_stateDoc, {
        'achievementIds': {...notifiedAchievements, ...unlocked.keys}.toList(),
        'streakMilestone': notifiedMilestone,
        'streakMilestoneDay': milestoneDay,
      }, SetOptions(merge: true));
    });
  }

  AppNotification _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    // serverTimestamp is null in a pending local write; it's never pending
    // here since _sync's transaction has committed, but fall back anyway.
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final message = data['message'] as String? ?? '';
    final isRead = data['isRead'] as bool? ?? false;
    AppNotification build({
      required NotificationType type,
      required String label,
      required IconData icon,
      required Color color,
      String? ctaLabel,
      NotificationAction? action,
    }) => AppNotification(
      id: doc.id,
      type: type,
      label: label,
      message: message,
      createdAt: createdAt,
      icon: icon,
      color: color,
      isRead: isRead,
      ctaLabel: ctaLabel,
      action: action,
    );

    return switch (data['kind']) {
      'petCare' => build(
        type: NotificationType.petAction,
        label: 'Pet Needs You',
        icon: Icons.pets,
        color: AppColors.mustardDark,
        ctaLabel: 'Take care',
        action: NotificationAction.carePet,
      ),
      'streak' => build(
        type: NotificationType.milestone,
        label: 'Milestone',
        icon: Icons.local_fire_department,
        color: AppColors.terracotta,
      ),
      'petEvolved' => build(
        type: NotificationType.milestone,
        label: 'Evolution',
        icon: Icons.egg_alt,
        color: AppColors.moss,
        ctaLabel: 'See pet',
        action: NotificationAction.carePet,
      ),
      'gift' => build(
        type: NotificationType.achievement,
        label: 'Gift',
        icon: Icons.card_giftcard,
        color: AppColors.terracotta,
      ),
      'achievement' => build(
        type: NotificationType.achievement,
        label: 'Achievement',
        icon: Icons.emoji_events,
        color: AppColors.moss,
      ),
      _ => build(
        type: NotificationType.system,
        label: 'Level Up',
        icon: Icons.auto_awesome,
        color: AppColors.inkMuted,
      ),
    };
  }
}
