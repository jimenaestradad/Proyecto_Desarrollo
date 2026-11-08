import 'achievement_repository.dart';
import 'auth_repository.dart';
import 'firebase_auth_repository.dart';
import 'bucket_list_repository.dart';
import 'calendar_repository.dart';
import 'firestore_bucket_list_repository.dart';
import 'firestore_inventory_repository.dart';
import 'firestore_notification_repository.dart';
import 'firestore_pet_repository.dart';
import 'firestore_user_repository.dart';
import 'habit_category_repository.dart';
import 'habit_repository.dart';
import 'inventory_repository.dart';
import 'mock_social_repository.dart';
import 'social_account.dart';
import 'notification_repository.dart';
import 'pet_repository.dart';
import 'social_repository.dart';
import 'user_repository.dart';
import 'username_repository.dart';
import 'vacation_log.dart';
import 'session_photos.dart';

/// Single place every screen gets its data from; screens depend only on the
/// abstract repository interfaces. Auth, usernames, habits, calendar and the
/// vacation log are Firestore-backed from launch. The per-account repositories
/// start as signed-out mocks and become Firestore ones in [bindToUser].
/// Social stays a frontend-only mock.
class AppData {
  AppData._();

  static AuthRepository auth = FirebaseAuthRepository();
  static UsernameRepository usernames = FirestoreUsernameRepository();

  /// Concrete-typed so [calendar] below can be constructed with it —
  /// [habits] itself stays declared as the abstract [HabitRepository].
  static final FirestoreHabitRepository _habits = FirestoreHabitRepository();
  static HabitRepository habits = _habits;

  /// Like [habits], reads the signed-in uid lazily (see
  /// FirestoreVacationLog/FirestoreHabitRepository's own `_uid` getters) —
  /// not rebuilt in [bindToUser]/[unbindUser], unlike the repositories
  /// below that take a `uid` constructor argument.
  static VacationLog vacationLog = FirestoreVacationLog();
  static CalendarRepository calendar = FirestoreCalendarRepository(
    _habits,
    vacationLog,
  );
  static UserRepository user = MockUserRepository(calendar, vacationLog);
  static HabitCategoryRepository habitCategories =
      MockHabitCategoryRepository();
  static BucketListRepository bucketList = MockBucketListRepository();
  static NotificationRepository notifications = MockNotificationRepository();

  /// Social tab data — frontend-only, in-memory (docs/BACKEND.md lists social
  /// as a non-goal). Friends/posts/competitions are seed data; "you" is the
  /// signed-in account (see [LiveSocialAccount]). Not rebuilt in
  /// [bindToUser]/[unbindUser] — just told the account changed.
  static SocialRepository social = MockSocialRepository(
    account: LiveSocialAccount(
      user: () => user,
      pet: () => pet,
      habits: () => habits,
    ),
  );
  static PetRepository pet = MockPetRepository(inventory);
  static InventoryRepository inventory = MockInventoryRepository();
  static AchievementRepository achievements = _buildAchievements();

  /// [MockAchievementRepository] captures [bucketList]/[pet]/[inventory] at
  /// construction, so [bindToUser]/[unbindUser] must call this again after
  /// swapping any of them.
  static AchievementRepository _buildAchievements() =>
      MockAchievementRepository(
        habits,
        calendar,
        bucketList,
        pet,
        inventory,
        social,
      );

  /// Binds per-account repositories before screens read them after authentication.
  /// Rebuilds [achievements] to follow the new dependencies; lazy-uid repositories persist.
  /// Requires the user, pet and inventory documents provisioned by `onUserCreate`.
  static void bindToUser(String uid) {
    user = FirestoreUserRepository(
      uid: uid,
      calendar: calendar,
      vacationLog: vacationLog,
    );
    habitCategories = FirestoreHabitCategoryRepository(uid: uid);
    pet = FirestorePetRepository(uid: uid);
    inventory = FirestoreInventoryRepository(uid: uid);
    bucketList = FirestoreBucketListRepository(uid: uid);
    achievements = _buildAchievements();
    notifications = FirestoreNotificationRepository(
      uid: uid,
      user: user,
      achievements: achievements,
    );
    social.accountChanged();
  }

  /// Reverses [bindToUser] on sign-out, so a second account signing in on
  /// the same app session (or a stale screen still holding a reference)
  /// can't read the previous account's repositories.
  static void unbindUser() {
    SessionPhotos.clear();
    user = MockUserRepository(calendar, vacationLog);
    habitCategories = MockHabitCategoryRepository();
    inventory = MockInventoryRepository();
    pet = MockPetRepository(inventory);
    bucketList = MockBucketListRepository();
    achievements = _buildAchievements();
    notifications = MockNotificationRepository();
    social.accountChanged();
  }
}
