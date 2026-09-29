import { getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { applyXpDelta } from "./xpCurve";
import { DayArgs, parseDayArgs, parseHabitId, requireAuth } from "./requestArgs";
import {
  HabitRewardResult,
  asNumber,
  currentPetStage,
  habitDocRefs,
  levelFields,
  readLevelState,
  syncPetStage,
} from "./habitTransaction";

// Reverses exactly what the log says the claim paid (awardedXp/awardedCoins),
// never a recomputation. Leaves the sunglasses gift and firstHabitCompletedAt
// alone — the gift is deliberately one-way (docs/BACKEND.md).
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

    const userData = userSnap.data();
    if (!userData) {
      throw new HttpsError("failed-precondition", "User profile hasn't been provisioned yet.");
    }

    const previousState = readLevelState(userData);
    const previousLevel = previousState.level;
    const petData = petSnap.data();
    const previousPetStage = currentPetStage(petData);

    const logData = logSnap.data();
    if (logData?.claimed !== true) {
      return {
        changed: false,
        xpDelta: 0,
        coinsDelta: 0,
        previousLevel,
        level: previousLevel,
        previousPetStage,
        petStage: previousPetStage,
        giftedAccessoryId: null,
      };
    }

    const awardedXp = asNumber(logData.awardedXp, 0);
    const awardedCoins = asNumber(logData.awardedCoins, 0);

    // The claimed value stays on the log so the user can keep editing from it.
    tx.update(refs.log, { claimed: false, awardedXp: 0, awardedCoins: 0 });

    const levelState = applyXpDelta(previousState, -awardedXp);
    // Clamped at 0 like MockUserRepository.addCoins — coins already spent
    // can't be taken back. See docs/KNOWN_ISSUES.md for the exploit this allows.
    const previousCoins = asNumber(userData.coins, 0);
    const coins = Math.max(0, previousCoins - awardedCoins);

    tx.update(refs.user, { ...levelFields(levelState), coins });

    return {
      changed: true,
      xpDelta: levelState.totalXp - previousState.totalXp,
      coinsDelta: coins - previousCoins,
      previousLevel,
      level: levelState.level,
      previousPetStage,
      petStage: syncPetStage(tx, refs.pet, petData, levelState.level),
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
