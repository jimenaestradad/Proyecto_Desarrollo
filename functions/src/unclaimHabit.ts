import { getFirestore } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";
import { DayArgs, parseDayArgs, parseHabitId, requireAuth } from "./requestArgs";
import { HabitRewardResult, currentPetStage, habitDocRefs, readLevelState } from "./habitTransaction";

// Un-marks the day as claimed but keeps what the claim paid: each day pays
// once, so the reward stays and a re-claim pays nothing (claimHabit checks
// the log's awardedXp/awardedCoins). Taking it back instead let claim →
// spend → unclaim → re-claim mint coins (docs/RESOLVED_LOG.md, 2026-10-26).
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

    const level = readLevelState(userSnap.data() ?? {}).level;
    const petStage = currentPetStage(petSnap.data());
    const changed = logSnap.data()?.claimed === true;
    // The claimed value stays on the log so the user can keep editing from it.
    if (changed) tx.update(refs.log, { claimed: false });

    return {
      changed,
      xpDelta: 0,
      coinsDelta: 0,
      previousLevel: level,
      level,
      previousPetStage: petStage,
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
