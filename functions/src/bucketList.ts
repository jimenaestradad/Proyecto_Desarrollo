import {
  DocumentData,
  DocumentReference,
  FieldValue,
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

// ../docs/BACKEND.md, "Bucket-list rewards are capped server-side at 500
// XP / 250 coins" -- bounds the seeded/free-text xpReward/coinReward
// fields without needing a frontend change.
const BUCKET_LIST_XP_CAP = 500;
const BUCKET_LIST_COIN_CAP = 250;

/**
 * Marks a bucket list item done and mints its (capped) XP/coin reward --
 * see ../docs/BACKEND.md's Architecture table and "Bucket-list rewards are
 * capped server-side at 500 XP / 250 coins". Stores exactly what it paid
 * into `awardedXp`/`awardedCoins` on the item -- see "Why 7 and 8 store
 * what they paid": [uncompleteBucketListItem] must reverse *that*, never
 * the item's current (possibly since-edited) `xpReward`/`coinReward`.
 * No-op (mirrors MockBucketListRepository.completeItem) if already
 * completed, so a duplicate tap/retry is harmless rather than an error.
 * Syncs `pet.stage` in the same transaction, exactly like claimHabit:
 * a bucket-list reward can cross the evolution level too, and the client
 * can't write `stage` itself (firestore_pet_repository.dart's
 * syncEvolution is a deliberate no-op).
 */
export const completeBucketListItem = onCall(async (request) => {
  const { uid, itemId } = requireBucketListCall(request);

  const { userRef, itemRef, petRef } = bucketListRefs(uid, itemId);

  return getFirestore().runTransaction(async (tx) => {
    const { userData, itemData, petData } = await readBucketListDocs(
      tx, userRef, itemRef, petRef
    );
    // Read up front: Firestore transactions need every read before any write.
    const notifiedSnap = await tx.get(notificationRefs(userRef).state);

    if (itemData.isCompleted === true) {
      return { xpDelta: 0, coinsDelta: 0 };
    }
    // Paid once already (then un-completed): mark done again, pay nothing.
    if (rewardPaid(itemData)) {
      tx.update(itemRef, { isCompleted: true, completedAt: FieldValue.serverTimestamp() });
      return { xpDelta: 0, coinsDelta: 0 };
    }

    // asNumber, not Number(): the rules let a client write any type into
    // these fields, and Number("abc") is NaN, which slips past both clamps.
    // Rounded so a fractional reward can't leave fractional XP/coins.
    const xpAwarded = Math.round(
      Math.max(0, Math.min(asNumber(itemData.xpReward, 0), BUCKET_LIST_XP_CAP))
    );
    const coinsAwarded = Math.round(
      Math.max(0, Math.min(asNumber(itemData.coinReward, 0), BUCKET_LIST_COIN_CAP))
    );

    const previousLevel = readLevelState(userData).level;
    const nextLevelState = applyXpDelta(readLevelState(userData), xpAwarded);
    const newCoins = Math.max(0, asNumber(userData.coins, 0) + coinsAwarded);

    tx.update(itemRef, {
      isCompleted: true,
      completedAt: FieldValue.serverTimestamp(),
      awardedXp: xpAwarded,
      awardedCoins: coinsAwarded,
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

/**
 * Subtracts exactly what [completeBucketListItem] paid -- the stored
 * `awardedXp`/`awardedCoins`, never the item's current (possibly
 * since-edited) `xpReward`/`coinReward` -- and re-syncs `pet.stage`. Only
 * delete uses it; uncomplete keeps the payout. Caller must have checked
 * [rewardPaid].
 */
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

/**
 * Un-marks the item as done but keeps what it paid, like unclaimHabit: an
 * item pays once, so completing it again pays nothing. No-op if not
 * currently completed.
 */
export const uncompleteBucketListItem = onCall(async (request) => {
  const { uid, itemId } = requireBucketListCall(request);
  const refs = bucketListRefs(uid, itemId);

  return getFirestore().runTransaction(async (tx) => {
    const { itemData } = await readBucketListDocs(
      tx, refs.userRef, refs.itemRef, refs.petRef
    );

    if (itemData.isCompleted !== true) {
      return { xpDelta: 0, coinsDelta: 0 };
    }

    tx.update(refs.itemRef, { isCompleted: false, completedAt: null });
    return { xpDelta: 0, coinsDelta: 0 };
  });
});

/**
 * Deletes a bucket list item, first taking back its reward if it ever paid
 * one (completed now or before) -- in one transaction, so deleting can't be
 * used to keep a reward and free the slot. firestore.rules only lets the
 * client delete an item directly while it has never paid; anything else
 * has to come through here.
 */
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
