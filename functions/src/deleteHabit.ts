import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { applyXpDelta } from "./xpCurve";
import { userDocRefs } from "./docRefs";
import { parseHabitId, requireAuth } from "./requestArgs";
import { asNumber, coinsAfterReversal, levelFields, rewardPaid, readLevelState, syncPetStage } from "./habitTransaction";

// A habit can only be fully deleted while it has almost no history — at most
// this many days with any logged progress or a claim. Anything with more has
// to be archived instead (docs/BACKEND.md, "Deleting vs. archiving a habit").
// Keep in sync with kMaxDeletableActiveDays in lib/data/habit_repository.dart.
export const MAX_DELETABLE_ACTIVE_DAYS = 2;

export interface DeleteHabitResult {
  xpDelta: number;
  coinsDelta: number;
}

// Deletes the habit doc and every one of its habitLogs, taking back whatever
// those logs paid (their stored awardedXp/awardedCoins, rejected if the coins
// were already spent) and re-syncing pet.stage, all in one transaction.
// Unlike unclaim, this does reverse: otherwise create → claim → delete would
// mint. Rejects a habit with real history. The sunglasses gift stays.
export async function runDeleteHabit(uid: string, habitId: string): Promise<DeleteHabitResult> {
  const db = getFirestore();
  const { user: userRef, habits, pet: petRef, habitLogs } = userDocRefs(db, uid);
  const habitRef = habits.doc(habitId);
  const logsQuery = habitLogs.where("habitId", "==", habitId);

  return db.runTransaction(async (tx) => {
    const [habitSnap, logsSnap, userSnap, petSnap] = await Promise.all([
      tx.get(habitRef),
      tx.get(logsQuery),
      tx.get(userRef),
      tx.get(petRef),
    ]);
    if (!habitSnap.exists) {
      throw new HttpsError("not-found", "Habit not found.");
    }
    const userData = userSnap.data();
    if (!userData) {
      throw new HttpsError("failed-precondition", "User profile hasn't been provisioned yet.");
    }

    let activeDays = 0;
    let xpToReverse = 0;
    let coinsToReverse = 0;
    for (const log of logsSnap.docs) {
      const data = log.data();
      const claimed = data.claimed === true;
      if (claimed || asNumber(data.value, 0) > 0 || rewardPaid(data)) activeDays++;
      // Unclaimed days can still hold a payout (a day pays once and keeps
      // it), so every log's award is taken back, claimed or not.
      xpToReverse += asNumber(data.awardedXp, 0);
      coinsToReverse += asNumber(data.awardedCoins, 0);
    }
    if (activeDays > MAX_DELETABLE_ACTIVE_DAYS) {
      throw new HttpsError(
        "failed-precondition",
        "This habit has history — archive it instead.",
      );
    }

    if (xpToReverse !== 0 || coinsToReverse !== 0) {
      const nextLevelState = applyXpDelta(readLevelState(userData), -xpToReverse);
      const newCoins = coinsAfterReversal(userData, coinsToReverse);
      tx.update(userRef, { ...levelFields(nextLevelState), coins: newCoins });
      syncPetStage(tx, petRef, petSnap.data(), nextLevelState.level);
    }
    for (const log of logsSnap.docs) tx.delete(log.ref);
    tx.delete(habitRef);

    return { xpDelta: -xpToReverse, coinsDelta: -coinsToReverse };
  });
}

interface DeleteHabitRequest {
  habitId?: unknown;
}

export const deleteHabit = onCall<DeleteHabitRequest>((request) => {
  const uid = requireAuth(request.auth?.uid);
  const habitId = parseHabitId(request.data.habitId);
  return runDeleteHabit(uid, habitId);
});
