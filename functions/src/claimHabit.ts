import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { claimValue, computeReward, parseHabitDefinition } from "./rewards";
import { applyXpDelta } from "./xpCurve";
import { DayArgs, localDayKeyOf, parseDayArgs, parseHabitId, requireAuth } from "./requestArgs";
import {
  HabitRewardResult,
  asNumber,
  currentPetStage,
  habitDocRefs,
  levelFields,
  readLevelState,
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
    // Same window Habit.isActiveOn uses: outside it the habit counts as
    // archived (FEATURES.md §2), so it can't be claimed. dayKeys compare as strings.
    const { startDate, endDate } = habitData;
    if (
      (startDate instanceof Timestamp && day.dayKey < localDayKeyOf(startDate.toMillis(), day)) ||
      (endDate instanceof Timestamp && day.dayKey > localDayKeyOf(endDate.toMillis(), day))
    ) {
      throw new HttpsError("failed-precondition", "Habit isn't active on that day.");
    }

    const previousState = readLevelState(userData);
    const previousLevel = previousState.level;
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

    const levelState = applyXpDelta(previousState, reward.xp);
    const userUpdate: Record<string, unknown> = {
      ...levelFields(levelState),
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
