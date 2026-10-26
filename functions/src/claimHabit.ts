import { DocumentData, FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { claimValue, computeReward, parseHabitDefinition } from "./rewards";
import { applyXpDelta } from "./xpCurve";
import { DayArgs, localDayKeyOf, parseDayArgs, parseHabitId, requireAuth } from "./requestArgs";
import {
  WINDOW_DAYS,
  adaptiveMultiplier,
  completionRate,
  isScheduledOnKey,
  previousDayKeys,
} from "./adaptiveXp";
import {
  HabitRewardResult,
  asNumber,
  currentPetStage,
  habitDocRefs,
  isArchivedOn,
  levelFields,
  readLevelState,
  rewardPaid,
  syncPetStage,
} from "./habitTransaction";
import { notificationRefs, petNameOf, progressNotifications, writeNotifications } from "./notifications";

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
    const [habitSnap, logSnap, userSnap, petSnap, inventorySnap, notifiedSnap] = await Promise.all([
      tx.get(refs.habit),
      tx.get(refs.log),
      tx.get(refs.user),
      tx.get(refs.pet),
      tx.get(refs.inventory),
      tx.get(notificationRefs(refs.user).state),
    ]);

    const habitData = habitSnap.data();
    if (!habitData) {
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
      (endDate instanceof Timestamp && day.dayKey > localDayKeyOf(endDate.toMillis(), day)) ||
      // Archived days are off too, but days before the archive stay
      // claimable — archiving hides a habit going forward, it doesn't
      // freeze its history.
      isArchivedOn(habitData.archivedRanges, day.dayKey)
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

    // Already paid today (then unclaimed): mark it claimed again, pay nothing.
    if (rewardPaid(logData)) {
      const habit = parseHabitDefinition(habitData);
      tx.update(refs.log, { claimed: true, value: claimValue(habit, asNumber(logData?.value, 0)) });
      return {
        changed: true,
        xpDelta: 0,
        coinsDelta: 0,
        previousLevel,
        level: previousLevel,
        previousPetStage,
        petStage: previousPetStage,
        giftedAccessoryId: null,
      };
    }

    // Adaptive XP: recomputed from the last WINDOW_DAYS of this habit's
    // history on every claim, ignoring whatever multiplier the doc holds
    // (the client can write that field). Reads stay before any write.
    const scheduledKeys = recentScheduledDays(habitData, userData, day);
    const windowLogs = scheduledKeys.length === 0 ? [] : await tx.getAll(
      ...scheduledKeys.map((key) => refs.user.collection("habitLogs").doc(`${key}_${habitId}`)),
    );
    const claimedKeys = new Set(
      windowLogs.filter((snap) => snap.get("claimed") === true).map((snap) => snap.get("dayKey") as string),
    );
    const habit = parseHabitDefinition(habitData);
    habit.adaptiveMultiplier = adaptiveMultiplier(
      habit.difficulty,
      completionRate(scheduledKeys, claimedKeys),
    );
    const value = claimValue(habit, asNumber(logData?.value, 0));
    const reward = computeReward(habit, value);

    // Stored so the app's reward preview shows what the next claim pays.
    tx.update(refs.habit, { adaptiveMultiplier: habit.adaptiveMultiplier });

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
    const petStage = syncPetStage(tx, refs.pet, petData, levelState.level);

    const { notifications, stateUpdate } = progressNotifications({
      previousLevel,
      level: levelState.level,
      previousPetStage,
      petStage,
      giftedAccessoryId,
      petName: petNameOf(petData),
      notified: notifiedSnap.data(),
    });
    writeNotifications(tx, refs.user, notifications, stateUpdate);

    return {
      changed: true,
      xpDelta: reward.xp,
      coinsDelta: reward.coins,
      previousLevel,
      level: levelState.level,
      previousPetStage,
      petStage,
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

// The window's days on which this habit was due: its schedule, minus days
// before it existed, outside its start/end, archived, or frozen by Vacation
// Mode (those count as safe in the calendar, so they don't count here either).
function recentScheduledDays(
  habitData: DocumentData,
  userData: DocumentData,
  day: DayArgs,
): string[] {
  const toKey = (value: unknown) =>
    value instanceof Timestamp ? localDayKeyOf(value.toMillis(), day) : null;
  const schedule = {
    repeat: habitData.repeat,
    customDays: habitData.customDays,
    createdKey: toKey(habitData.createdAt),
    startKey: toKey(habitData.startDate),
    endKey: toKey(habitData.endDate),
    archivedRanges: habitData.archivedRanges,
  };
  const vacations = (Array.isArray(userData.vacationRanges) ? userData.vacationRanges : [])
    .map((range: { start?: unknown; end?: unknown }) => ({ start: toKey(range?.start), end: toKey(range?.end) }))
    .filter((range: { start: string | null }) => range.start !== null);
  const onVacation = (key: string) => vacations.some(
    (range: { start: string | null; end: string | null }) =>
      key >= range.start! && (range.end === null || key <= range.end),
  );
  return previousDayKeys(day.dayKey, WINDOW_DAYS)
    .filter((key) => isScheduledOnKey(schedule, key) && !onVacation(key));
}
