import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { requireAuth } from "./requestArgs";
import { asNumber } from "./habitTransaction";

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
 * Buys `quantity` (default 1) of a Food & Care item -- see
 * ../docs/BACKEND.md's Architecture table: spends coins to mint an owned
 * item, which is exactly the currency-affecting write the Cloud-Functions
 * boundary exists to guard. Validates `itemId` against [CARE_ITEM_CATALOG]
 * (never trusts a price/grants amount from the client), checks
 * `cost <= coins`, then decrements coins and increments
 * `careItemCounts[itemId]` in one transaction.
 */
export const purchaseCareItem = onCall(async (request) => {
  const db = getFirestore();
  const uid = requireAuth(request.auth?.uid);

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
  const db = getFirestore();
  const uid = requireAuth(request.auth?.uid);

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
