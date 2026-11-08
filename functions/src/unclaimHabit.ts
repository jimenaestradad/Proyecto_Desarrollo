import { getFirestore } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";
import { DayArgs, parseDayArgs, parseHabitId, requireAuth } from "./requestArgs";
import { HabitRewardResult, currentPetStage, habitDocRefs, readLevelState } from "./habitTransaction";

// Unmarks the claim but keeps its payout; re-claiming pays nothing.
// Reversing it allowed claim → spend → unclaim → re-claim to mint coins.
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
