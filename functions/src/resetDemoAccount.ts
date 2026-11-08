import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { userDocRefs } from "./docRefs";
import { requireAuth } from "./requestArgs";
import { applyXpDelta } from "./xpCurve";
import { asNumber, levelFields, readLevelState, rewardPaid, syncPetStage } from "./habitTransaction";
import { topUpCareItems, topUpCoins } from "./demoBaseline";

// The one account the dev-only reset button works on (Settings -> Developer).
// See ../docs/BACKEND.md, "Demo account reset".
export const DEMO_ACCOUNT_EMAIL = "demo@test.com";

// Checked against the verified ID token's `email` claim, which a client can't
// set -- the Settings button only hides itself, this is the actual gate.
export function isDemoAccount(token: { email?: unknown } | undefined): boolean {
  return typeof token?.email === "string" && token.email.toLowerCase() === DEMO_ACCOUNT_EMAIL;
}

// Reverses all bucket-list payouts and resets completion and progress notification flags.
// Then tops the demo account back up to its test baseline (every care item x3, 500 coins
// minimum; see demoBaseline.ts). Leaves habits, logs, accessories, and achievements alone;
// safe to re-run.
export const resetDemoAccount = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  if (!isDemoAccount(request.auth?.token)) {
    throw new HttpsError("permission-denied", "This is only available on the demo account.");
  }

  const db = getFirestore();
  const { user, pet, bucketList, inventory } = userDocRefs(db, uid);
  const notifications = user.collection("notifications");
  const notificationStateRef = user.collection("notificationState").doc("main");

  return db.runTransaction(async (tx) => {
    const [userSnap, petSnap, inventorySnap, itemsSnap, notificationsSnap] = await Promise.all([
      tx.get(user),
      tx.get(pet),
      tx.get(inventory),
      tx.get(bucketList),
      tx.get(notifications.where("kind", "in", ["levelUp", "petEvolved"])),
    ]);
    const userData = userSnap.data();
    if (!userData) throw new HttpsError("not-found", "No user doc for this account.");

    let xp = 0;
    let coins = 0;
    for (const item of itemsSnap.docs) {
      const data = item.data();
      if (!rewardPaid(data) && data.isCompleted !== true) continue;
      xp += asNumber(data.awardedXp, 0);
      coins += asNumber(data.awardedCoins, 0);
      tx.update(item.ref, {
        isCompleted: false, completedAt: null, awardedXp: 0, awardedCoins: 0, paidAt: null,
      });
    }

    const levelState = applyXpDelta(readLevelState(userData), -xp);
    const newCoins = topUpCoins(Math.max(0, asNumber(userData.coins, 0) - coins));
    tx.update(user, { ...levelFields(levelState), coins: newCoins });

    const inventoryData = inventorySnap.data();
    if (inventoryData) {
      tx.update(inventory, { careItemCounts: topUpCareItems(inventoryData.careItemCounts) });
    }

    syncPetStage(tx, pet, petSnap.data(), levelState.level);

    tx.set(notificationStateRef, { level: levelState.level, petEvolved: false }, { merge: true });
    for (const notification of notificationsSnap.docs) tx.delete(notification.ref);

    return { xpDelta: -xp, coinsDelta: newCoins - asNumber(userData.coins, 0), level: levelState.level };
  });
});
