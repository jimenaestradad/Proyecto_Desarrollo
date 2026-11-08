import {
  DocumentData,
  DocumentReference,
  FieldValue,
  Timestamp,
  Transaction,
  getFirestore,
} from "firebase-admin/firestore";
import { CallableRequest, HttpsError, onCall } from "firebase-functions/v2/https";
import { applyXpDelta } from "./xpCurve";
import { userDocRefs } from "./docRefs";
import { parseDocId, requireAuth } from "./requestArgs";
import {
  asNumber,
  coinsAfterReversal,
  currentPetStage,
  levelFields,
  readLevelState,
  rewardPaid,
  syncPetStage,
} from "./habitTransaction";
import { notificationRefs, petNameOf, progressNotifications, writeNotifications } from "./notifications";
import { BUCKET_PAID_WINDOW_MS, bucketReward, weeklyPaidLimitReached } from "./bucketRewards";

// Reward size and the two-paid-goals-a-week limit live in bucketRewards.ts.

// Completes an item once, stores its capped payout, and syncs pet.stage atomically.
// Stored awardedXp/awardedCoins let deletion reverse the actual payout after edits.
export const completeBucketListItem = onCall(async (request) => {
  const { uid, itemId } = requireBucketListCall(request);

  const { userRef, itemRef, petRef } = bucketListRefs(uid, itemId);

  return getFirestore().runTransaction(async (tx) => {
    const { userData, itemData, petData } = await readBucketListDocs(
      tx, userRef, itemRef, petRef
    );
    // Read up front: Firestore transactions need every read before any write.
    const notifiedSnap = await tx.get(notificationRefs(userRef).state);
    const paidRecentlySnap = await tx.get(
      itemRef.parent.where("paidAt", ">=", Timestamp.fromMillis(Date.now() - BUCKET_PAID_WINDOW_MS))
    );

    if (itemData.isCompleted === true) {
      return { xpDelta: 0, coinsDelta: 0 };
    }
    // Paid once already (then un-completed): mark done again, pay nothing.
    if (rewardPaid(itemData)) {
      tx.update(itemRef, { isCompleted: true, completedAt: FieldValue.serverTimestamp() });
      return { xpDelta: 0, coinsDelta: 0 };
    }

    // The weekly limit: the goal still counts as achieved, it just pays nothing now. It stays
    // unpaid, so un-completing and completing it again after the week pays it normally.
    if (weeklyPaidLimitReached(paidRecentlySnap.size)) {
      tx.update(itemRef, { isCompleted: true, completedAt: FieldValue.serverTimestamp() });
      return { xpDelta: 0, coinsDelta: 0, limited: true };
    }

    const { xp: xpAwarded, coins: coinsAwarded } = bucketReward(itemData);

    const previousLevel = readLevelState(userData).level;
    const nextLevelState = applyXpDelta(readLevelState(userData), xpAwarded);
    const newCoins = Math.max(0, asNumber(userData.coins, 0) + coinsAwarded);

    tx.update(itemRef, {
      isCompleted: true,
      completedAt: FieldValue.serverTimestamp(),
      awardedXp: xpAwarded,
      awardedCoins: coinsAwarded,
      paidAt: FieldValue.serverTimestamp(),
    });
    tx.update(userRef, { ...levelFields(nextLevelState), coins: newCoins });
    const petStage = syncPetStage(tx, petRef, petData, nextLevelState.level);

    const { notifications, stateUpdate } = progressNotifications({
      previousLevel,
      level: nextLevelState.level,
      previousPetStage: currentPetStage(petData),
      petStage,
      giftedAccessoryId: null,
      petName: petNameOf(petData),
      notified: notifiedSnap.data(),
    });
    writeNotifications(tx, userRef, notifications, stateUpdate);

    return { xpDelta: xpAwarded, coinsDelta: coinsAwarded };
  });
});

function requireBucketListCall(request: CallableRequest<{ itemId?: unknown }>) {
  return {
    uid: requireAuth(request.auth?.uid),
    itemId: parseDocId(request.data?.itemId, "itemId"),
  };
}

function bucketListRefs(uid: string, itemId: string) {
  const { user, bucketList, pet } = userDocRefs(getFirestore(), uid);
  return { userRef: user, itemRef: bucketList.doc(itemId), petRef: pet };
}

async function readBucketListDocs(
  tx: Transaction,
  userRef: DocumentReference,
  itemRef: DocumentReference,
  petRef: DocumentReference,
) {
  const [userSnap, itemSnap, petSnap] = await Promise.all([
    tx.get(userRef),
    tx.get(itemRef),
    tx.get(petRef),
  ]);
  const userData = userSnap.data();
  const itemData = itemSnap.data();
  if (!userData || !itemData) {
    throw new HttpsError("not-found", "Bucket list item not found.");
  }
  return { userData, itemData, petData: petSnap.data() };
}

// Reverses the stored payout and syncs pet.stage for deletion only.
// Caller must check rewardPaid; uncompleting keeps the payout.
function reverseBucketListReward(
  tx: Transaction,
  refs: { userRef: DocumentReference; petRef: DocumentReference },
  userData: DocumentData,
  itemData: DocumentData,
  petData: DocumentData | undefined,
) {
  const xpToReverse = asNumber(itemData.awardedXp, 0);
  const coinsToReverse = asNumber(itemData.awardedCoins, 0);

  const nextLevelState = applyXpDelta(readLevelState(userData), -xpToReverse);
  const newCoins = coinsAfterReversal(userData, coinsToReverse);

  tx.update(refs.userRef, { ...levelFields(nextLevelState), coins: newCoins });
  syncPetStage(tx, refs.petRef, petData, nextLevelState.level);

  return { xpDelta: -xpToReverse, coinsDelta: -coinsToReverse };
}

// Unmarks completion but keeps the payout; completing again pays nothing.
// No-op when the item is not completed.
export const uncompleteBucketListItem = onCall(async (request) => {
  const { uid, itemId } = requireBucketListCall(request);
  const refs = bucketListRefs(uid, itemId);

  return getFirestore().runTransaction(async (tx) => {
    const itemData = (await tx.get(refs.itemRef)).data();
    if (!itemData) {
      throw new HttpsError("not-found", "Bucket list item not found.");
    }

    if (itemData.isCompleted !== true) {
      return { xpDelta: 0, coinsDelta: 0 };
    }

    tx.update(refs.itemRef, { isCompleted: false, completedAt: null });
    return { xpDelta: 0, coinsDelta: 0 };
  });
});

// Deletes the item and reverses any prior payout atomically, preventing reward retention.
// Direct client deletion is allowed only for items that have never paid.
export const deleteBucketListItem = onCall(async (request) => {
  const { uid, itemId } = requireBucketListCall(request);
  const refs = bucketListRefs(uid, itemId);

  return getFirestore().runTransaction(async (tx) => {
    const { userData, itemData, petData } = await readBucketListDocs(
      tx, refs.userRef, refs.itemRef, refs.petRef
    );

    // rewardPaid, not isCompleted: an un-completed item keeps its payout.
    const result = rewardPaid(itemData)
      ? reverseBucketListReward(tx, refs, userData, itemData, petData)
      : { xpDelta: 0, coinsDelta: 0 };
    tx.delete(refs.itemRef);
    return result;
  });
});
