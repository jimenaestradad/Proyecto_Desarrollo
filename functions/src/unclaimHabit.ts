import { getFirestore } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";
import { applyXpDelta } from "./xpCurve";
import { DayArgs, parseDayArgs, parseHabitId, requireAuth } from "./requestArgs";
import {
  HabitRewardResult,
  asNumber,
  coinsAfterReversal,
  currentPetStage,
  habitDocRefs,
  levelFields,
  readLevelState,
  syncPetStage,
} from "./habitTransaction";

// Unmarks the claim and takes back exactly what it paid (XP, coins, and the
// level / pet stage that follow), so claim → undo nets zero and a re-claim
// pays again. Rejects, instead of clamping at 0, if the coins were already
// spent: otherwise claim → spend → undo would keep the purchase for free
// (the same rule as deleteHabit). The sunglasses gift is never taken back.
export async function runUnclaimHabit(
  uid: string,
  habitId: string,
  day: DayArgs,
): Promise<HabitRewardResult> {
  const db = getFirestore();
  const refs = habitDocRefs(db, uid, habitId, day.dayKey);

  return db.runTransaction(async (tx) => {
    const [logSnap, userSnap, petSnap] = await Promise.all([
      tx.get(refs.log),
      tx.get(refs.user),
      tx.get(refs.pet),
    ]);

    const userData = userSnap.data() ?? {};
    const previousState = readLevelState(userData);
    const petData = petSnap.data();
    const previousPetStage = currentPetStage(petData);
    const logData = logSnap.data();

    // Not claimed → nothing to undo. The claimed value stays on the log so the
    // user can keep editing from it.
    if (logData?.claimed !== true) {
      return {
        changed: false,
        xpDelta: 0,
        coinsDelta: 0,
        previousLevel: previousState.level,
        level: previousState.level,
        previousPetStage,
        petStage: previousPetStage,
        giftedAccessoryId: null,
      };
    }

    const xpToReverse = asNumber(logData.awardedXp, 0);
    const coinsToReverse = asNumber(logData.awardedCoins, 0);
    const levelState = applyXpDelta(previousState, -xpToReverse);
    // Checked before any write so a rejection leaves the log untouched.
    const newCoins = coinsAfterReversal(userData, coinsToReverse, "undone");

    tx.update(refs.log, { claimed: false, awardedXp: 0, awardedCoins: 0 });
    let petStage = previousPetStage;
    if (xpToReverse !== 0 || coinsToReverse !== 0) {
      tx.update(refs.user, { ...levelFields(levelState), coins: newCoins });
      petStage = syncPetStage(tx, refs.pet, petData, levelState.level);
    }

    return {
      changed: true,
      xpDelta: -xpToReverse,
      coinsDelta: -coinsToReverse,
      previousLevel: previousState.level,
      level: levelState.level,
      previousPetStage,
      petStage,
      giftedAccessoryId: null,
    };
  });
}

interface UnclaimHabitRequest {
  habitId?: unknown;
  dayKey?: unknown;
  dayStartMillis?: unknown;
}

export const unclaimHabit = onCall<UnclaimHabitRequest>((request) => {
  const uid = requireAuth(request.auth?.uid);
  const habitId = parseHabitId(request.data.habitId);
  const day = parseDayArgs(request.data);
  return runUnclaimHabit(uid, habitId, day);
});
