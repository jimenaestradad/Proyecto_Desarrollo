import 'achievement_repository.dart';
import 'auth_repository.dart';
import 'firebase_auth_repository.dart';
import 'bucket_list_repository.dart';
import 'calendar_repository.dart';
import 'firestore_bucket_list_repository.dart';
import 'firestore_inventory_repository.dart';
import 'firestore_pet_repository.dart';
import 'firestore_user_repository.dart';
import 'habit_category_repository.dart';
import 'habit_repository.dart';
import 'inventory_repository.dart';
import 'notification_repository.dart';
import 'pet_repository.dart';
import 'user_repository.dart';
import 'username_repository.dart';
import 'vacation_log.dart';

/// Single place every screen gets its data from. Each field is backed by an
/// in-memory mock today; wiring up a real backend later means replacing the
/// initializer on the right (e.g. `AuthRepository auth = ApiAuthRepository()`)
/// — screens depend only on the abstract interfaces, so nothing else changes.
class AppData {
  AppData._();

  static AuthRepository auth = FirebaseAuthRepository();
  static UsernameRepository usernames = FirestoreUsernameRepository();
  static HabitRepository habits = MockHabitRepository();
  static VacationLog vacationLog = MockVacationLog();
  static CalendarRepository calendar = MockCalendarRepository(
    habits,
    vacationLog,
  );
  static UserRepository user = MockUserRepository(calendar, vacationLog);
  static HabitCategoryRepository habitCategories =
      MockHabitCategoryRepository();
  static BucketListRepository bucketList = MockBucketListRepository();
  static NotificationRepository notifications = MockNotificationRepository();
  static PetRepository pet = MockPetRepository();
  static InventoryRepository inventory = MockInventoryRepository();
  static AchievementRepository achievements = MockAchievementRepository(
    habits,
    calendar,
    bucketList,
    pet,
    inventory,
  );

  /// Points the per-account repositories at [uid]'s real Firestore data.
  /// Called right after a sign-up/login/auto-login succeeds (main.dart,
  /// sign_up_screen.dart, login_screen.dart) and before any screen reads
  /// AppData.user et al., so nothing is ever left pointed at another
  /// account's (or the Mock's demo) data.
  ///
  /// [habits] is the one repository still Mock — Valeria's
  /// FirestoreHabitRepository hasn't landed yet (docs/BACKEND.md's task
  /// checklist). Everything else now has a real implementation: [user] /
  /// [habitCategories] (firestore_user_repository.dart /
  /// habit_category_repository.dart's FirestoreHabitCategoryRepository),
  /// and [pet] / [inventory] / [bucketList] (firestore_pet_repository.dart
  /// / firestore_inventory_repository.dart /
  /// firestore_bucket_list_repository.dart). [achievements] is rebuilt
  /// here too — it holds direct references to [bucketList]/[pet]/
  /// [inventory] captured at construction time (see
  /// achievement_repository.dart), so swapping those without also
  /// rebuilding [achievements] would leave it silently reading the old
  /// Mock instances. This still depends on 'onUserCreate' (the
  /// Auth-trigger Cloud Function in functions/src/index.ts) actually
  /// being deployed to the `nori-pet` Firebase project — that's what
  /// creates the '/users/{uid}' doc (and its pet/inventory subdocs) these
  /// repositories read; until it's deployed, real accounts will hit each
  /// repository's own missing-document error instead.
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
    achievements = MockAchievementRepository(
      habits,
      calendar,
      bucketList,
      pet,
      inventory,
    );
  }

  /// Reverses [bindToUser] on sign-out, so a second account signing in on
  /// the same app session (or a stale screen still holding a reference)
  /// can't read the previous account's repositories.
  static void unbindUser() {
    user = MockUserRepository(calendar, vacationLog);
    habitCategories = MockHabitCategoryRepository();
    pet = MockPetRepository();
    inventory = MockInventoryRepository();
    bucketList = MockBucketListRepository();
    achievements = MockAchievementRepository(
      habits,
      calendar,
      bucketList,
      pet,
      inventory,
    );
  }
}
