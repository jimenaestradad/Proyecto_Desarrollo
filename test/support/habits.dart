import 'package:nori/models/habit.dart';
import 'package:nori/models/habit_day_state.dart';

/// A habit definition built the way Firestore hands one back, for tests.
Habit testHabit(
  String id, {
  String type = 'binary',
  String repeat = 'daily',
  double? target,
  double? minThreshold,
  List<Map<String, dynamic>> archivedRanges = const [],
  DateTime? createdAt,
}) => Habit.fromJson(id, {
  'name': id,
  'subtitle': '',
  'iconKey': 'book',
  'colorKey': 'sky',
  'xpReward': 20,
  'coinReward': 10,
  'type': type,
  'repeat': repeat,
  'targetValue': target,
  'minThreshold': minThreshold,
  'archivedRanges': archivedRanges,
  'createdAt': createdAt,
});

/// [testHabit] as it looks on a day it was claimed.
Habit claimedHabit(String id) =>
    testHabit(id).hydrate(const HabitDayState(claimed: true));
