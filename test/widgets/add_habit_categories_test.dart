import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/app_data.dart';
import 'package:nori/data/habit_category_repository.dart';
import 'package:nori/screens/habits/add_habit_screen.dart';

/// What a brand-new account has: `onUserCreate` writes `habitCategories: []`.
class _Categories implements HabitCategoryRepository {
  final List<String> names = [];

  @override
  Future<List<String>> getCategories() async => List.unmodifiable(names);

  @override
  Future<void> addCategory(String name) async => names.add(name);

  @override
  Future<void> renameCategory(String oldName, String newName) async {}

  @override
  Future<void> deleteCategory(String name) async => names.remove(name);
}

void main() {
  late HabitCategoryRepository original;
  late _Categories categories;

  setUp(() {
    original = AppData.habitCategories;
    categories = _Categories();
    AppData.habitCategories = categories;
  });
  tearDown(() => AppData.habitCategories = original);

  testWidgets('a new account can add its first category from Add Habit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1236, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: AddHabitScreen()));
    await tester.pumpAndSettle();

    // Not blank: the field says what to do.
    expect(find.text('Choose or add a category'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    // Only the add entry exists (the closed field's hint is also on screen).
    expect(find.text('Add Category'), findsOneWidget);

    await tester.tap(find.text('Add Category'));
    await tester.pumpAndSettle();
    expect(find.text('New Category'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Finance');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(categories.names, ['Finance']);
    expect(find.text('Finance'), findsOneWidget);
    expect(find.text('Choose or add a category'), findsNothing);
  });

  testWidgets('cancelling the prompt leaves the field as it was', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1236, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: AddHabitScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(categories.names, isEmpty);
    expect(find.text('Choose or add a category'), findsOneWidget);
  });
}
