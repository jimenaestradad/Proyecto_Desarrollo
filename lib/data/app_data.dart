import 'achievement_repository.dart';
import 'auth_repository.dart';
import 'calendar_repository.dart';
import 'habit_repository.dart';
import 'inventory_repository.dart';
import 'notification_repository.dart';
import 'pet_repository.dart';
import 'user_repository.dart';

/// Single place every screen gets its data from. Each field is backed by an
/// in-memory mock today; wiring up a real backend later means replacing the
/// initializer on the right (e.g. `AuthRepository auth = ApiAuthRepository()`)
/// — screens depend only on the abstract interfaces, so nothing else changes.
class AppData {
  AppData._();

  static AuthRepository auth = MockAuthRepository();
  static UserRepository user = MockUserRepository();
  static HabitRepository habits = MockHabitRepository();
  static AchievementRepository achievements = MockAchievementRepository();
  static NotificationRepository notifications = MockNotificationRepository();
  static CalendarRepository calendar = MockCalendarRepository();
  static PetRepository pet = MockPetRepository();
  static InventoryRepository inventory = MockInventoryRepository();
}
