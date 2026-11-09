import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bucket_list_item.dart';
import 'bucket_list_repository.dart';
import 'cloud_functions_client.dart';
import 'color_registry.dart';
import 'habit_repository.dart' show HabitRewardResult;
import 'icon_registry.dart';

/// Firestore bucket-list CRUD for `/users/{uid}/bucketList/{itemId}`.
/// Completion rewards and reward-reversing deletion require Cloud Functions;
/// client updates only change user-editable fields.
class FirestoreBucketListRepository implements BucketListRepository {
  FirestoreBucketListRepository({
    required String uid,
    FirebaseFirestore? firestore,
  }) : _uid = uid,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final String _uid;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(_uid).collection('bucketList');

  BucketListItem _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return BucketListItem(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      icon: IconRegistry.iconFor(data['iconKey'] as String?),
      color: ColorRegistry.colorFor(data['colorKey'] as String?),
      // Capped like the server's payout, so a goal saved with a bigger
      // number (before the cap, or by hand) shows what it will really pay.
      xpReward: ((data['xpReward'] as num?)?.toInt() ?? 0).clamp(
        0,
        BucketListItem.maxXpReward,
      ),
      coinReward: ((data['coinReward'] as num?)?.toInt() ?? 0).clamp(
        0,
        BucketListItem.maxCoinReward,
      ),
      isCompleted: data['isCompleted'] as bool? ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      rewardPaid:
          ((data['awardedXp'] as num?) ?? 0) > 0 ||
          ((data['awardedCoins'] as num?) ?? 0) > 0,
    );
  }

  @override
  Future<List<BucketListItem>> getItems() async {
    // Ordered by creation, the closest real-data equivalent of the mock's
    // fixed insertion-order list -- bucket list items have no drag-reorder
    // (unlike habits' explicit `order` field), so this is the only
    // ordering that needs to exist.
    final snapshot = await _collection.orderBy('createdAt').get();
    return snapshot.docs.map(_fromDoc).toList();
  }

  /// Written in a transaction, with a read first, on purpose: a plain
  /// `set`/`update` is queued by the SDK while the device is offline and
  /// applied later, after the screen has already shown an error and undone
  /// the change. A transaction needs the server, so it fails right away and
  /// nothing is left waiting to land.
  @override
  Future<void> addItem(BucketListItem item) async {
    final ref = _collection.doc(item.id);
    await _firestore.runTransaction((tx) async {
      await tx.get(ref);
      tx.set(ref, {
        'title': item.title,
        'description': item.description,
        'iconKey': IconRegistry.tryKeyFor(item.icon) ?? IconRegistry.defaultKey,
        'colorKey':
            ColorRegistry.tryKeyFor(item.color) ?? ColorRegistry.defaultKey,
        'xpReward': item.xpReward,
        'coinReward': item.coinReward,
        // Cloud-Function-only fields must start at their untouched defaults
        // -- mirrors the habit doc's create rule (firestore.rules).
        'isCompleted': false,
        'completedAt': null,
        'awardedXp': 0,
        'awardedCoins': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// A transaction for the same reason as [addItem].
  @override
  Future<void> updateItem(BucketListItem item) async {
    final ref = _collection.doc(item.id);
    await _firestore.runTransaction((tx) async {
      await tx.get(ref);
      tx.update(ref, {
        'title': item.title,
        'description': item.description,
        'iconKey': IconRegistry.tryKeyFor(item.icon) ?? IconRegistry.defaultKey,
        'colorKey':
            ColorRegistry.tryKeyFor(item.color) ?? ColorRegistry.defaultKey,
        'xpReward': item.xpReward,
        'coinReward': item.coinReward,
      });
    });
  }

  /// Always goes through the `deleteBucketListItem` Cloud Function rather
  /// than a direct delete: a completed item's reward has to be taken back
  /// in the same transaction, and firestore.rules rejects a direct delete
  /// of a completed item for exactly that reason.
  @override
  Future<void> deleteItem(String id) async {
    await callCloudFunction('deleteBucketListItem', {'itemId': id});
  }

  @override
  Future<HabitRewardResult> completeItem(String id) {
    throw UnsupportedError(
      'FirestoreBucketListRepository.completeItem: awarding XP/coins is '
      'Cloud-Function-only (docs/technical/BACKEND.md, "Security rules") -- the '
      'deployed rules reject a direct client write to isCompleted/'
      'awardedXp/awardedCoins. Call the completeBucketListItem Cloud '
      'Function from the screen instead.',
    );
  }

  @override
  Future<HabitRewardResult> uncompleteItem(String id) {
    throw UnsupportedError(
      'FirestoreBucketListRepository.uncompleteItem: reversing XP/coins is '
      'Cloud-Function-only (docs/technical/BACKEND.md, "Security rules") -- the '
      'deployed rules reject a direct client write to isCompleted/'
      'awardedXp/awardedCoins. Call the uncompleteBucketListItem Cloud '
      'Function from the screen instead.',
    );
  }
}
