import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { userDocRefs } from "./docRefs";
import { requireAuth } from "./requestArgs";
import { asNumber } from "./habitTransaction";

// Mirrors trusted prices/grants from lib/data/care_item_catalog.dart; never trust client prices.
// Keep both catalogs in sync manually when prices or grants change.
const CARE_ITEM_CATALOG: Record<string, { price: number; grants: number }> = {
  food: { price: 10, grants: 3 },
  cake: { price: 18, grants: 3 },
  shampoo: { price: 10, grants: 3 },
  "hair-brush": { price: 18, grants: 3 },
  plushie: { price: 10, grants: 3 },
  blanket: { price: 18, grants: 3 },
};

// Server-side mirror of lib/data/accessory_catalog.dart's prices; hand-synced
// like CARE_ITEM_CATALOG above.
const ACCESSORY_CATALOG: Record<string, { price: number }> = {
  "flower-crown": { price: 500 },
  "horn-bow": { price: 180 },
  sunglasses: { price: 140 },
  "steampunk-goggles": { price: 350 },
  "chef-hat": { price: 250 },
  "tail-charm-clasp": { price: 100 },
};

// Looks up own catalog keys only; inherited keys can yield undefined prices.
// That would bypass the coin check via NaN and make subsequent purchases free.
function catalogEntry<T>(catalog: Record<string, T>, id: unknown): T | undefined {
  return typeof id === "string" && Object.prototype.hasOwnProperty.call(catalog, id)
    ? catalog[id]
    : undefined;
}

// Buys care items atomically using catalog prices/grants and the available coin balance.
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

  const { user: userRef, inventory: inventoryRef } = userDocRefs(db, uid);
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

// Buys a catalog accessory atomically after checking ownership and available coins.
// Equipping remains a separate direct client write.
export const purchaseAccessory = onCall(async (request) => {
  const db = getFirestore();
  const uid = requireAuth(request.auth?.uid);

  const accessoryId = request.data?.accessoryId;
  const accessory = catalogEntry(ACCESSORY_CATALOG, accessoryId);
  if (!accessory) {
    throw new HttpsError("invalid-argument", "Unknown accessory.");
  }

  const { user: userRef, inventory: inventoryRef } = userDocRefs(db, uid);

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
