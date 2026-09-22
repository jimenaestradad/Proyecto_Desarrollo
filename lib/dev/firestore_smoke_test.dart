// TEMPORARY dev-only harness for manually exercising FirestoreHabitRepository
// against the live `nori-pet` project before Auth/UI exist to do it for real.
// Delete this file (and its call site in main.dart) once we're done testing.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/habit_repository.dart';
import '../models/habit.dart';
import '../theme/app_colors.dart';

const _testHabitId = 'smoke-test-habit';

Future<void> runFirestoreSmokeTest() async {
  debugPrint('[smoke] signing in test@nori.com...');
  final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: 'test@nori.com',
    password: 'test123',
  );
  debugPrint('[smoke] signed in as ${credential.user?.uid}');

  final repo = FirestoreHabitRepository();

  const original = Habit(
    id: _testHabitId,
    name: 'Smoke Test Habit',
    subtitle: 'Delete me after testing',
    icon: Icons.water_drop,
    color: AppColors.terracotta,
    xpReward: 10,
    coinReward: 5,
    repeat: HabitRepeat.daily,
    type: HabitType.quantity,
    targetValue: 100,
    unit: 'ml',
  );

  debugPrint('[smoke] addHabit...');
  await repo.addHabit(original);

  debugPrint('[smoke] getTodayHabits...');
  var habits = await repo.getTodayHabits();
  debugPrint('[smoke] fetched ${habits.length} habit(s): ${habits.map((h) => h.name).toList()}');

  debugPrint('[smoke] logProgress(+25)...');
  await repo.logProgress(_testHabitId, 25);
  habits = await repo.getTodayHabits();
  final afterLog = habits.firstWhere((h) => h.id == _testHabitId);
  debugPrint('[smoke] currentValue after log: ${afterLog.currentValue} (expect 25.0)');

  debugPrint('[smoke] updateHabit (rename, should NOT reset currentValue)...');
  final edited = Habit(
    id: _testHabitId,
    name: 'Smoke Test Habit (edited)',
    subtitle: original.subtitle,
    icon: original.icon,
    color: original.color,
    xpReward: original.xpReward,
    coinReward: original.coinReward,
    repeat: original.repeat,
    type: original.type,
    targetValue: original.targetValue,
    unit: original.unit,
  );
  await repo.updateHabit(edited);
  habits = await repo.getTodayHabits();
  final afterEdit = habits.firstWhere((h) => h.id == _testHabitId);
  debugPrint(
    '[smoke] after edit — name: ${afterEdit.name}, currentValue: '
    '${afterEdit.currentValue} (expect 25.0, unchanged)',
  );

  debugPrint('[smoke] reorderHabits...');
  await repo.reorderHabits([_testHabitId]);
  habits = await repo.getTodayHabits();
  debugPrint('[smoke] order after reorder: ${habits.firstWhere((h) => h.id == _testHabitId).order} (expect 0)');

  debugPrint('[smoke] DONE — check console.firebase.google.com/project/nori-pet/firestore');
}
