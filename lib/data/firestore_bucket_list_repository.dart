import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bucket_list_item.dart';
import 'bucket_list_repository.dart';
import 'cloud_functions_client.dart';
import 'habit_repository.dart' show HabitRewardResult;
import 'icon_registry.dart';

/// Real Firestore-backed [BucketListRepository] for
/// `/users/{uid}/bucketList/{itemId}` -- see docs/BACKEND.md, "Firestore
/// schema".
///
/// [getItems]/[addItem]/[updateItem] are direct, rules-guarded client
/// writes -- no currency involved (Architecture table: "Habit
/// create/update/delete/reorder", same reasoning applies here).
/// [deleteItem] is the exception: deleting a completed item takes its
/// reward back, so it's a Cloud Function call (see its own comment). [updateItem] only ever touches the user-editable fields --
/// never `isCompleted`/`completedAt`/`awardedXp`/`awardedCoins`, which are
/// Cloud-Function-only (see below).
///
/// [completeItem]/[uncompleteItem] are the currency-minting half --
/// completing an item awards XP/coins, so per the Architecture table
/// that's Cloud-Function-only (`completeBucketListItem`/
/// `uncompleteBucketListItem` in functions/src/bucketList.ts). This repository
/// deliberately doesn't attempt a direct write for either, matching
/// FirestoreUserRepository.addXp's UnsupportedError idiom -- screens call
/// the Cloud Function directly instead (see bucket_list_screen.dart's
/// `_toggleComplete`, via cloud_functions_client.dart's shared helper).
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
      icon: iconForKey(data['iconKey'] as String?),
      color: colorForKey(data['colorKey'] as String?),
      xpReward: (data['xpReward'] as num?)?.toInt() ?? 0,
      coinReward: (data['coinReward'] as num?)?.toInt() ?? 0,
      isCompleted: data['isCompleted'] as bool? ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
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

  @override
  Future<void> addItem(BucketListItem item) async {
    await _collection.doc(item.id).set({
      'title': item.title,
      'description': item.description,
      'iconKey': iconKeyFor(item.icon) ?? kDefaultIconKey,
      'colorKey': colorKeyFor(item.color) ?? kDefaultColorKey,
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
  }

  @override
  Future<void> updateItem(BucketListItem item) async {
    await _collection.doc(item.id).update({
      'title': item.title,
      'description': item.description,
      'iconKey': iconKeyFor(item.icon) ?? kDefaultIconKey,
      'colorKey': colorKeyFor(item.color) ?? kDefaultColorKey,
      'xpReward': item.xpReward,
      'coinReward': item.coinReward,
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
      'Cloud-Function-only (docs/BACKEND.md, "Security rules") -- the '
      'deployed rules reject a direct client write to isCompleted/'
      'awardedXp/awardedCoins. Call the completeBucketListItem Cloud '
      'Function from the screen instead.',
    );
  }

  @override
  Future<HabitRewardResult> uncompleteItem(String id) {
    throw UnsupportedError(
      'FirestoreBucketListRepository.uncompleteItem: reversing XP/coins is '
      'Cloud-Function-only (docs/BACKEND.md, "Security rules") -- the '
      'deployed rules reject a direct client write to isCompleted/'
      'awardedXp/awardedCoins. Call the uncompleteBucketListItem Cloud '
      'Function from the screen instead.',
    );
  }
}
