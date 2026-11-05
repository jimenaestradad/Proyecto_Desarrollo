import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { userDocRefs } from "./docRefs";
import { requireAuth } from "./requestArgs";
import { applyXpDelta, xpForLevel } from "./xpCurve";
import { asNumber, currentPetStage, readLevelState, rewardPaid } from "./habitTransaction";
import { petStageForLevel } from "./rewards";

// The one account the dev-only reset button works on (Settings -> Developer).
// See ../docs/BACKEND.md, "Demo account reset".
export const DEMO_ACCOUNT_EMAIL = "demo@test.com";

// Checked against the verified ID token's `email` claim, which a client can't
// set -- the Settings button only hides itself, this is the actual gate.
export function isDemoAccount(token: { email?: unknown } | undefined): boolean {
  return typeof token?.email === "string" && token.email.toLowerCase() === DEMO_ACCOUNT_EMAIL;
}

/**
 * Takes back every bucket-list payout (XP, coins, the item's completed
 * state), drops the level and pet stage that XP had earned, and clears the
 * "already notified" flags so level-up / evolved fire again when the items are
 * re-completed -- i.e. puts the account back where it was before the bucket
 * list was ticked off, so that flow can be tested again. Habits, habit logs,
 * inventory and achievements are left alone. Reverses what each item actually
 * paid (`awardedXp`/`awardedCoins`), like deleteBucketListItem, and counts an
 * un-completed item too since it keeps its payout. Safe to re-run.
 */
export const resetDemoAccount = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  if (!isDemoAccount(request.auth?.token)) {
    throw new HttpsError("permission-denied", "This is only available on the demo account.");
  }

  const db = getFirestore();
  const { user, pet, bucketList } = userDocRefs(db, uid);
  const notifications = user.collection("notifications");
  const notificationStateRef = user.collection("notificationState").doc("main");

  return db.runTransaction(async (tx) => {
    const [userSnap, petSnap, itemsSnap, notificationsSnap] = await Promise.all([
      tx.get(user),
      tx.get(pet),
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
      tx.update(item.ref, { isCompleted: false, completedAt: null, awardedXp: 0, awardedCoins: 0 });
    }

    const levelState = applyXpDelta(readLevelState(userData), -xp);
    tx.update(user, {
      ...levelState,
      xpForNextLevel: xpForLevel(levelState.level),
      coins: Math.max(0, asNumber(userData.coins, 0) - coins),
    });

    const petData = petSnap.data();
    const stage = currentPetStage(petData);
    if (petData && stage) {
      const threshold = asNumber(petData.evolutionLevelThreshold, 7);
      const next = petStageForLevel(stage, levelState.level, threshold);
      if (next !== stage) tx.update(pet, { stage: next });
    }

    tx.set(notificationStateRef, { level: levelState.level, petEvolved: false }, { merge: true });
    for (const notification of notificationsSnap.docs) tx.delete(notification.ref);

    return { xpDelta: -xp, coinsDelta: -coins, level: levelState.level };
  });
});
