import 'package:cloud_firestore/cloud_firestore.dart';

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

/// Real Firestore-backed [HabitCategoryRepository]. Per docs/BACKEND.md,
/// `habitCategories` lives as a plain string array on the *same*
/// `/users/{uid}` document [FirestoreUserRepository] reads/writes — there's
/// no separate collection — so this takes just a uid, not a whole user doc
/// dependency, to keep the two independently constructible the way
/// [MockHabitCategoryRepository] and [MockUserRepository] are today.
///
/// NOT WIRED INTO [AppData] yet, for the same reason as
/// FirestoreUserRepository: the `/users/{uid}` doc this reads/writes isn't
/// created by anything until `onUserCreate` (a still-unbuilt Cloud
/// Function) exists. See firestore_user_repository.dart's doc comment.
class FirestoreHabitCategoryRepository implements HabitCategoryRepository {
  FirestoreHabitCategoryRepository({
    required String uid,
    FirebaseFirestore? firestore,
  }) : _uid = uid,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final String _uid;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('users').doc(_uid);

  @override
  Future<List<String>> getCategories() async {
    final snapshot = await _doc.get();
    final raw = snapshot.data()?['habitCategories'] as List<dynamic>?;
    // Empty rather than throwing on a missing field, unlike
    // FirestoreUserRepository.getCurrentUser() -- onUserCreate's exact
    // provisioning values are still being worked out (docs/BACKEND.md
    // doesn't list a habitCategories default in its provisioning table),
    // so treat "field not there yet" as "no categories yet", not an error.
    return List.unmodifiable(raw?.cast<String>() ?? const <String>[]);
  }

  @override
  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    // arrayUnion is a no-op if the value's already present, so this
    // doesn't need its own "already exists" check the way the mock does.
    await _doc.update({
      'habitCategories': FieldValue.arrayUnion([trimmed]),
    });
  }

  @override
  Future<void> renameCategory(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    // No atomic "replace element N" op on a Firestore array -- read the
    // whole list, edit it in Dart, write the whole list back inside a
    // transaction so a concurrent add/delete from another device can't be
    // silently overwritten by a stale read.
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(_doc);
      final categories = List<String>.from(
        (snapshot.data()?['habitCategories'] as List<dynamic>?)?.cast<String>() ??
            const <String>[],
      );
      final index = categories.indexOf(oldName);
      if (index == -1) return;
      categories[index] = trimmed;
      transaction.update(_doc, {'habitCategories': categories});
    });
  }

  @override
  Future<void> deleteCategory(String name) async {
    // Matches the mock's "keep at least one category" guard -- read first
    // rather than blindly arrayRemove-ing down to zero.
    final categories = await getCategories();
    if (categories.length <= 1) return;
    await _doc.update({
      'habitCategories': FieldValue.arrayRemove([name]),
    });
  }
}
