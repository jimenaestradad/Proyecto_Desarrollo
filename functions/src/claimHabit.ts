import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { claimValue, computeReward, levelStateForTotalXp, parseHabitDefinition } from "./rewards";
import { DayArgs, parseDayArgs, parseHabitId, requireAuth } from "./requestArgs";
import {
  HabitRewardResult,
  asNumber,
  currentPetStage,
  habitDocRefs,
  syncPetStage,
} from "./habitTransaction";

const FIRST_COMPLETION_GIFT = "sunglasses";
// Lenient on purpose: a DST day can be 25h long.
const LONGEST_DAY_MS = 25 * 60 * 60 * 1000;

export async function runClaimHabit(
  uid: string,
  habitId: string,
  day: DayArgs,
): Promise<HabitRewardResult> {
  const db = getFirestore();
  const refs = habitDocRefs(db, uid, habitId, day.dayKey);

  return db.runTransaction(async (tx) => {
    // Firestore transactions require every read before any write.
    const [habitSnap, logSnap, userSnap, petSnap, inventorySnap] = await Promise.all([
      tx.get(refs.habit),
      tx.get(refs.log),
      tx.get(refs.user),
      tx.get(refs.pet),
      tx.get(refs.inventory),
    ]);

    const habitData = habitSnap.data();
    if (!habitData || habitData.archived === true) {
      throw new HttpsError("not-found", "Habit not found.");
    }
    const userData = userSnap.data();
    if (!userData) {
      throw new HttpsError("failed-precondition", "User profile hasn't been provisioned yet.");
    }

    const createdAt = habitData.createdAt;
    if (createdAt instanceof Timestamp && day.dayStartMillis + LONGEST_DAY_MS <= createdAt.toMillis()) {
      throw new HttpsError("failed-precondition", "Habit didn't exist on that day.");
    }

    const previousTotalXp = asNumber(userData.totalXp, 0);
    const previousLevel = levelStateForTotalXp(previousTotalXp).level;
    const petData = petSnap.data();
    const previousPetStage = currentPetStage(petData);

    const logData = logSnap.data();
    if (logData?.claimed === true) {
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

    const habit = parseHabitDefinition(habitData);
    const value = claimValue(habit, asNumber(logData?.value, 0));
    const reward = computeReward(habit, value);

    tx.set(refs.log, {
      habitId,
      dayKey: day.dayKey,
      date: Timestamp.fromMillis(day.dayStartMillis),
      value,
      claimed: true,
      awardedXp: reward.xp,
      awardedCoins: reward.coins,
    });

    const totalXp = previousTotalXp + reward.xp;
    const levelState = levelStateForTotalXp(totalXp);
    const userUpdate: Record<string, unknown> = {
      totalXp,
      level: levelState.level,
      xpIntoLevel: levelState.xpIntoLevel,
      xpForNextLevel: levelState.xpForNextLevel,
      coins: asNumber(userData.coins, 0) + reward.coins,
    };

    // One-time and one-way: unclaimHabit never takes the gift back. Skipped
    // (not stamped) if inventory isn't provisioned, so the gift isn't lost.
    let giftedAccessoryId: string | null = null;
    const inventoryData = inventorySnap.data();
    if (userData.firstHabitCompletedAt == null && reward.tier !== "none" && inventoryData) {
      giftedAccessoryId = FIRST_COMPLETION_GIFT;
      userUpdate.firstHabitCompletedAt = FieldValue.serverTimestamp();
      const inventoryUpdate: Record<string, unknown> = {
        ownedAccessoryIds: FieldValue.arrayUnion(FIRST_COMPLETION_GIFT),
      };
      if (inventoryData.equippedAccessoryId == null) {
        inventoryUpdate.equippedAccessoryId = FIRST_COMPLETION_GIFT;
      }
      tx.update(refs.inventory, inventoryUpdate);
    }
    tx.update(refs.user, userUpdate);

    return {
      changed: true,
      xpDelta: reward.xp,
      coinsDelta: reward.coins,
      previousLevel,
      level: levelState.level,
      previousPetStage,
      petStage: syncPetStage(tx, refs.pet, petData, levelState.level),
      giftedAccessoryId,
    };
  });
}

interface ClaimHabitRequest {
  habitId?: unknown;
  dayKey?: unknown;
  dayStartMillis?: unknown;
}

export const claimHabit = onCall<ClaimHabitRequest>((request) => {
  const uid = requireAuth(request.auth?.uid);
  const habitId = parseHabitId(request.data.habitId);
  const day = parseDayArgs(request.data);
  return runClaimHabit(uid, habitId, day);
});
