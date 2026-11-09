import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nori/data/accessory_catalog.dart';
import 'package:nori/data/care_item_catalog.dart';
import 'package:nori/data/habit_repository.dart' show kMaxDeletableActiveDays;
import 'package:nori/data/pet_repository.dart' show kPetDecayPerHour;
import 'package:nori/models/bucket_list_item.dart';

/// Prices, grants, item ids and a few limits are written out by hand in Dart,
/// TypeScript (Cloud Functions) and the Firestore rules. These tests read the
/// other copies as text and fail when one drifts, so a mismatch is caught here
/// instead of as a shop that charges a different price than it shows.
String _read(String path) => File(path).readAsStringSync();

/// The `{...}` body of `const <name> ... = {` up to its closing `};`.
String _tsBlock(String source, String name) {
  final start = source.indexOf('const $name');
  expect(start, isNonNegative, reason: '$name not found in shop.ts');
  final open = source.indexOf('= {', start);
  final end = source.indexOf('\n};', open);
  return source.substring(open, end);
}

void main() {
  final shop = _read('functions/src/shop.ts');

  test('care item prices and grants match functions/src/shop.ts', () {
    final entry = RegExp(
      r'"?([\w-]+)"?:\s*\{\s*price:\s*(\d+),\s*grants:\s*(\d+)\s*\}',
    );
    final server = {
      for (final m in entry.allMatches(_tsBlock(shop, 'CARE_ITEM_CATALOG')))
        m[1]!: (int.parse(m[2]!), int.parse(m[3]!)),
    };
    final app = {
      for (final item in kCareItemCatalog) item.id: (item.price, item.grants),
    };
    expect(server, app);
  });

  test('accessory prices match functions/src/shop.ts', () {
    final entry = RegExp(r'"?([\w-]+)"?:\s*\{\s*price:\s*(\d+)\s*\}');
    final server = {
      for (final m in entry.allMatches(_tsBlock(shop, 'ACCESSORY_CATALOG')))
        m[1]!: int.parse(m[2]!),
    };
    final app = {for (final item in kAccessoryCatalog) item.id: item.price};
    expect(server, app);
  });

  test('firestore.rules guards exactly the care item ids', () {
    final rules = _read('firestore.rules');
    final fn = rules.substring(
      rules.indexOf('function careItemCountsOnlyDecreased'),
      rules.indexOf('match /databases'),
    );
    final guarded = {
      for (final m in RegExp(
        r"newCounts(?:\.([\w]+)|\['([\w-]+)'\])\s*<=",
      ).allMatches(fn))
        (m[1] ?? m[2])!,
    };
    expect(guarded, {for (final item in kCareItemCatalog) item.id});
  });

  test('delete limit and pet decay rate match the server', () {
    final deleteHabit = _read('functions/src/deleteHabit.ts');
    final days = RegExp(
      r'MAX_DELETABLE_ACTIVE_DAYS\s*=\s*(\d+)',
    ).firstMatch(deleteHabit)![1]!;
    expect(int.parse(days), kMaxDeletableActiveDays);

    final notifications = _read('functions/src/notifications.ts');
    final decay = RegExp(
      r'PET_DECAY_PER_HOUR\s*=\s*([\d.]+)',
    ).firstMatch(notifications)![1]!;
    expect(double.parse(decay), kPetDecayPerHour);
  });

  test('bucket list caps and weekly limit match the server', () {
    final server = _read('functions/src/bucketRewards.ts');
    int constant(String name) =>
        int.parse(RegExp('$name\\s*=\\s*(\\d+)').firstMatch(server)![1]!);

    expect(constant('BUCKET_LIST_XP_CAP'), BucketListItem.maxXpReward);
    expect(constant('BUCKET_LIST_COIN_CAP'), BucketListItem.maxCoinReward);
    expect(
      constant('BUCKET_PAID_GOALS_PER_WEEK'),
      BucketListItem.paidGoalsPerWeek,
    );
    // The biggest goal size is what the caps promise.
    expect(BucketGoalSize.big.xp, BucketListItem.maxXpReward);
    expect(BucketGoalSize.big.coins, BucketListItem.maxCoinReward);
  });
}
