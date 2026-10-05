/**
 * Nori — Cloud Functions.
 *
 * See ../docs/BACKEND.md for the full plan this implements: the schema,
 * the Cloud-Functions-vs-direct-write rule of thumb, and the concrete
 * function list. Jimena's functions, all in this file: onUserCreate,
 * purchaseCareItem, purchaseAccessory, completeBucketListItem,
 * uncompleteBucketListItem, deleteBucketListItem. Valeria's: claimHabit, unclaimHabit,
 * deleteHabit, in their
 * own files, re-exported below (see docs/BACKEND.md "Division of labor").
 * Everything deploys from this one entry point — a second functions/
 * folder would make each side's `firebase deploy` delete the other's.
 *
 * onUserCreate is a v1-style Auth trigger (functions.auth.user().onCreate)
 * rather than a v2 callable, on purpose: v2 doesn't have a direct
 * non-blocking "after this account was created" trigger equivalent to
 * v1's — v2's identity triggers (beforeUserCreated/beforeUserSignedIn) are
 * *blocking* functions that run synchronously as part of sign-up/sign-in
 * and are meant for validation, not this "provision some Firestore docs
 * afterward, don't hold up the response" job. Mixing v1 (this trigger)
 * and v2 (future callables like purchaseCareItem) in one codebase is
 * normal and supported.
 */

import * as admin from "firebase-admin";
import {
  DocumentData,
  DocumentReference,
  FieldValue,
  Transaction,
} from "firebase-admin/firestore";
import * as functionsV1 from "firebase-functions/v1";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import {
  asNumber,
  levelFields,
  readLevelState,
  syncPetStage,
} from "./habitTransaction";
import { applyXpDelta } from "./xpCurve";

admin.initializeApp();
const db = admin.firestore();

export { claimHabit } from "./claimHabit";
export { unclaimHabit } from "./unclaimHabit";
export { deleteHabit } from "./deleteHabit";

/**
 * Server-side mirror of lib/data/care_item_catalog.dart's price/grants.
 * The *catalog* (icons, colors, restore amounts) stays a bundled Dart
 * constant per ../docs/BACKEND.md ("Static content catalogs") -- but a
 * Cloud Function can never trust a price the client hands it, so the two
 * numbers that actually affect the currency (price, grants) are
 * duplicated here. Keep in sync BY HAND if either catalog changes --
 * same rule firestore.rules's own header comment already lives by.
 */
const CARE_ITEM_CATALOG: Record<string, { price: number; grants: number }> = {
  food: { price: 50, grants: 3 },
  cake: { price: 90, grants: 3 },
  shampoo: { price: 40, grants: 3 },
  "hair-brush": { price: 70, grants: 3 },
  plushie: { price: 60, grants: 3 },
  blanket: { price: 100, grants: 3 },
};

/** Server-side mirror of lib/data/accessory_catalog.dart's prices -- same
 * hand-sync reasoning as [CARE_ITEM_CATALOG] above. */
const ACCESSORY_CATALOG: Record<string, { price: number }> = {
  "flower-crown": { price: 180 },
  "horn-bow": { price: 120 },
  sunglasses: { price: 140 },
  "steampunk-goggles": { price: 180 },
  "chef-hat": { price: 160 },
  "tail-charm-clasp": { price: 130 },
};

// ../docs/BACKEND.md, "Bucket-list rewards are capped server-side at 500
// XP / 250 coins" -- bounds the seeded/free-text xpReward/coinReward
// fields without needing a frontend change.
const BUCKET_LIST_XP_CAP = 500;
const BUCKET_LIST_COIN_CAP = 250;

/**
 * Own-key catalog lookup. A plain `catalog[id]` also matches inherited
 * keys ("constructor", "toString", "__proto__"), whose `price` is
 * undefined -- the coin check then compares against NaN, passes, and
 * saves `coins: NaN`, after which every purchase is free.
 */
function catalogEntry<T>(catalog: Record<string, T>, id: unknown): T | undefined {
  return typeof id === "string" && Object.prototype.hasOwnProperty.call(catalog, id)
    ? catalog[id]
    : undefined;
}

/**
 * Provisions a brand-new sign-up's /users/{uid} doc, starter pet, and
 * starter inventory. Values are exactly docs/BACKEND.md's "New-account
 * provisioning" table — do not tune game-balance numbers here, that's an
 * OPEN_DECISIONS.md question, not this function's.
 *
 * Deliberately NOT set here (left for the client to fill in immediately
 * after, as direct writes the security rules already allow):
 * - `name`, `username`, `avatarUrl` — this trigger fires the instant the
 *   Auth account exists, before the client's own sign-up flow has run
 *   updateProfile() or claimed a username (see docs/BACKEND.md, "Username
 *   uniqueness" — same race, same accepted sub-second window).
 * - Pet `name` — stays 'Nori' until onboarding writes a real one, also
 *   per docs/BACKEND.md (an auth trigger can't see a value typed on a
 *   later onboarding screen).
 *
 * No accessory is granted here — the one free accessory (sunglasses) is a
 * first-habit-completion gift, granted inside Valeria's claimHabit
 * transaction, not at sign-up. See docs/BACKEND.md.
 */
export const onUserCreate = functionsV1.auth.user().onCreate(async (user) => {
  const uid = user.uid;
  const now = FieldValue.serverTimestamp();

  // create(), not set(): if this trigger is ever delivered twice, the
  // second run fails instead of resetting a user who has already started.
  const batch = db.batch();

  batch.create(db.collection("users").doc(uid), {
    name: "",
    username: "",
    email: user.email ?? "",
    avatarUrl: null,
    createdAt: now,
    level: 1,
    totalXp: 0,
    xpIntoLevel: 0,
    xpForNextLevel: 100,
    coins: 0,
    vacationModeEnabled: false,
    vacationRanges: [],
    habitCategories: [],
    firstHabitCompletedAt: null,
  });

  batch.create(db.collection("users").doc(uid).collection("pet").doc("main"), {
    name: "Nori",
    hunger: 100,
    hygiene: 100,
    happiness: 100,
    lastDecayAt: now,
    stage: "baby",
    evolutionLevelThreshold: 7,
  });

  batch.create(
    db.collection("users").doc(uid).collection("inventory").doc("main"),
    {
      // All six catalog ids present from the start (not just the ones
      // with a starting count) so consumeCareItem/purchaseCareItem never
      // have to special-case "this key doesn't exist yet" — see
      // care_item_catalog.dart for where these ids come from.
      careItemCounts: {
        food: 3,
        cake: 0,
        shampoo: 2,
        "hair-brush": 0,
        plushie: 1,
        blanket: 0,
      },
      ownedAccessoryIds: [],
      equippedAccessoryId: null,
    }
  );

  await batch.commit();
});

/**
 * Buys `quantity` (default 1) of a Food & Care item -- see
 * ../docs/BACKEND.md's Architecture table: spends coins to mint an owned
 * item, which is exactly the currency-affecting write the Cloud-Functions
 * boundary exists to guard. Validates `itemId` against [CARE_ITEM_CATALOG]
 * (never trusts a price/grants amount from the client), checks
 * `cost <= coins`, then decrements coins and increments
 * `careItemCounts[itemId]` in one transaction.
 */
export const purchaseCareItem = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const itemId = request.data?.itemId;
  const quantity = Number(request.data?.quantity ?? 1);
  const careItem = catalogEntry(CARE_ITEM_CATALOG, itemId);
  if (!careItem) {
    throw new HttpsError("invalid-argument", "Unknown care item.");
  }
  if (!Number.isInteger(quantity) || quantity < 1) {
    throw new HttpsError(
      "invalid-argument",
      "Quantity must be a positive whole number."
    );
  }

  const userRef = db.collection("users").doc(uid);
  const inventoryRef = userRef.collection("inventory").doc("main");
  const cost = careItem.price * quantity;
  const grantedCount = careItem.grants * quantity;

  return db.runTransaction(async (tx) => {
    const [userSnap, inventorySnap] = await Promise.all([
      tx.get(userRef),
      tx.get(inventoryRef),
    ]);
    const userData = userSnap.data();
    const inventoryData = inventorySnap.data();
    if (!userData || !inventoryData) {
      throw new HttpsError(
        "failed-precondition",
        "Account isn't fully set up yet."
      );
    }

    const coins = asNumber(userData.coins, 0);
    if (coins < cost) {
      throw new HttpsError("failed-precondition", "Not enough coins.");
    }

    const careItemCounts = { ...(inventoryData.careItemCounts ?? {}) };
    careItemCounts[itemId] = (careItemCounts[itemId] ?? 0) + grantedCount;
    const newCoins = coins - cost;

    tx.update(userRef, { coins: newCoins });
    tx.update(inventoryRef, { careItemCounts });

    return { coins: newCoins, careItemCounts };
  });
});

/**
 * Buys one accessory -- same currency reasoning as [purchaseCareItem].
 * Validates `accessoryId` against [ACCESSORY_CATALOG], rejects an
 * accessory the user already owns (../docs/BACKEND.md: "Buying something
 * already owned is rejected server-side, even if the UI already hides
 * it"), checks `price <= coins`, then decrements coins and adds the id to
 * `ownedAccessoryIds` in one transaction. Does not auto-equip -- equipping
 * stays its own direct client write (`setEquippedAccessory`).
 */
export const purchaseAccessory = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const accessoryId = request.data?.accessoryId;
  const accessory = catalogEntry(ACCESSORY_CATALOG, accessoryId);
  if (!accessory) {
    throw new HttpsError("invalid-argument", "Unknown accessory.");
  }

  const userRef = db.collection("users").doc(uid);
  const inventoryRef = userRef.collection("inventory").doc("main");

  return db.runTransaction(async (tx) => {
    const [userSnap, inventorySnap] = await Promise.all([
      tx.get(userRef),
      tx.get(inventoryRef),
    ]);
    const userData = userSnap.data();
    const inventoryData = inventorySnap.data();
    if (!userData || !inventoryData) {
      throw new HttpsError(
        "failed-precondition",
        "Account isn't fully set up yet."
      );
    }

    const ownedAccessoryIds: string[] = inventoryData.ownedAccessoryIds ?? [];
    if (ownedAccessoryIds.includes(accessoryId)) {
      throw new HttpsError(
        "failed-precondition",
        "You already own this accessory."
      );
    }

    const coins = asNumber(userData.coins, 0);
    if (coins < accessory.price) {
      throw new HttpsError("failed-precondition", "Not enough coins.");
    }
    const newCoins = coins - accessory.price;

    tx.update(userRef, { coins: newCoins });
    tx.update(inventoryRef, {
      ownedAccessoryIds: FieldValue.arrayUnion(accessoryId),
    });

    return { coins: newCoins };
  });
});

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

  return db.runTransaction(async (tx) => {
    const { userData, itemData, petData } = await readBucketListDocs(
      tx, userRef, itemRef, petRef
    );

    if (itemData.isCompleted === true) {
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

    const nextLevelState = applyXpDelta(readLevelState(userData), xpAwarded);
    const newCoins = Math.max(0, asNumber(userData.coins, 0) + coinsAwarded);

    tx.update(itemRef, {
      isCompleted: true,
      completedAt: FieldValue.serverTimestamp(),
      awardedXp: xpAwarded,
      awardedCoins: coinsAwarded,
    });
    tx.update(userRef, { ...levelFields(nextLevelState), coins: newCoins });
    syncPetStage(tx, petRef, petData, nextLevelState.level);

    return { xpDelta: xpAwarded, coinsDelta: coinsAwarded };
  });
});

function requireBucketListCall(request: { auth?: { uid: string }; data?: { itemId?: unknown } }) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const itemId = request.data?.itemId;
  if (typeof itemId !== "string" || itemId.length === 0) {
    throw new HttpsError("invalid-argument", "itemId is required.");
  }
  return { uid, itemId };
}

function bucketListRefs(uid: string, itemId: string) {
  const userRef = db.collection("users").doc(uid);
  return {
    userRef,
    itemRef: userRef.collection("bucketList").doc(itemId),
    petRef: userRef.collection("pet").doc("main"),
  };
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
 * since-edited) `xpReward`/`coinReward`, mirroring `unclaimHabit` -- and
 * re-syncs `pet.stage`. Shared by uncomplete and delete so the two can't
 * drift. Caller must have checked `isCompleted === true`.
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
  const newCoins = Math.max(0, asNumber(userData.coins, 0) - coinsToReverse);

  tx.update(refs.userRef, { ...levelFields(nextLevelState), coins: newCoins });
  syncPetStage(tx, refs.petRef, petData, nextLevelState.level);

  return { xpDelta: -xpToReverse, coinsDelta: -coinsToReverse };
}

/**
 * Reverses [completeBucketListItem] exactly (see
 * [reverseBucketListReward]). No-op if not currently completed.
 */
export const uncompleteBucketListItem = onCall(async (request) => {
  const { uid, itemId } = requireBucketListCall(request);
  const refs = bucketListRefs(uid, itemId);

  return db.runTransaction(async (tx) => {
    const { userData, itemData, petData } = await readBucketListDocs(
      tx, refs.userRef, refs.itemRef, refs.petRef
    );

    if (itemData.isCompleted !== true) {
      return { xpDelta: 0, coinsDelta: 0 };
    }

    tx.update(refs.itemRef, {
      isCompleted: false,
      completedAt: null,
      awardedXp: 0,
      awardedCoins: 0,
    });
    return reverseBucketListReward(tx, refs, userData, itemData, petData);
  });
});

/**
 * Deletes a bucket list item, first taking back its reward if it was
 * completed -- in one transaction, so deleting can't be used to keep a
 * reward and free the slot. firestore.rules only lets the client delete
 * an item directly while it's *not* completed; a completed one has to
 * come through here.
 */
export const deleteBucketListItem = onCall(async (request) => {
  const { uid, itemId } = requireBucketListCall(request);
  const refs = bucketListRefs(uid, itemId);

  return db.runTransaction(async (tx) => {
    const { userData, itemData, petData } = await readBucketListDocs(
      tx, refs.userRef, refs.itemRef, refs.petRef
    );

    const result = itemData.isCompleted === true
      ? reverseBucketListReward(tx, refs, userData, itemData, petData)
      : { xpDelta: 0, coinsDelta: 0 };
    tx.delete(refs.itemRef);
    return result;
  });
});
