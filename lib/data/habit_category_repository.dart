/// The category list shown in the Add/Edit Habit screen's "Category"
/// dropdown (stored per-habit in [Habit.subtitle] — see add_habit_screen.dart).
/// Previously a hardcoded const list; now user-editable via Settings.
abstract class HabitCategoryRepository {
  Future<List<String>> getCategories();
  Future<void> addCategory(String name);
  Future<void> renameCategory(String oldName, String newName);

  /// Removes a category from the picker. Habits already using it keep their
  /// existing subtitle text — nothing cascades to in-flight habit data.
  Future<void> deleteCategory(String name);
}

class MockHabitCategoryRepository implements HabitCategoryRepository {
  final List<String> _categories = ['Health', 'Fitness', 'Learning', 'Mindfulness'];

  @override
  Future<List<String>> getCategories() async => List.unmodifiable(_categories);

  @override
  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _categories.contains(trimmed)) return;
    _categories.add(trimmed);
  }

  @override
  Future<void> renameCategory(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final index = _categories.indexOf(oldName);
    if (index == -1) return;
    _categories[index] = trimmed;
  }

  @override
  Future<void> deleteCategory(String name) async {
    if (_categories.length <= 1) return;
    _categories.remove(name);
  }
}
