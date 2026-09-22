import 'achievement_repository.dart';
import 'auth_repository.dart';
import 'firebase_auth_repository.dart';
import 'bucket_list_repository.dart';
import 'calendar_repository.dart';
import 'habit_category_repository.dart';
import 'habit_repository.dart';
import 'inventory_repository.dart';
import 'notification_repository.dart';
import 'pet_repository.dart';
import 'user_repository.dart';
import 'vacation_log.dart';

/// Single place every screen gets its data from. Each field is backed by an
/// in-memory mock today; wiring up a real backend later means replacing the
/// initializer on the right (e.g. `AuthRepository auth = ApiAuthRepository()`)
/// — screens depend only on the abstract interfaces, so nothing else changes.
class AppData {
  AppData._();

  static AuthRepository auth = FirebaseAuthRepository();
  static HabitRepository habits = MockHabitRepository();
  static VacationLog vacationLog = VacationLog();
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
}
