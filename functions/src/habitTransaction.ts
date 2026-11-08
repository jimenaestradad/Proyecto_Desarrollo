import { DocumentData, DocumentReference, Firestore, Transaction } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";
import { EVOLUTION_LEVEL, PetStage, petStageForLevel } from "./rewards";
import { LevelState, xpForLevel } from "./xpCurve";
import { userDocRefs, habitLogId } from "./docRefs";

export interface HabitRewardResult {
  changed: boolean;
  xpDelta: number;
  coinsDelta: number;
  previousLevel: number;
  level: number;
  previousPetStage: PetStage | null;
  petStage: PetStage | null;
  giftedAccessoryId: string | null;
}

export function habitDocRefs(db: Firestore, uid: string, habitId: string, dayKey: string) {
  const { user, habits, habitLogs, pet, inventory } = userDocRefs(db, uid);
  return {
    user,
    habit: habits.doc(habitId),
    log: habitLogs.doc(habitLogId(dayKey, habitId)),
    // The whole collection, for a claim that also reads the habit's earlier days.
    habitLogs,
    pet,
    inventory,
  };
}

// Mirrors Habit.isActiveOn's archive check: `archivedRanges` is a list of
// {start, end} client-local dayKeys, end exclusive (the restore day is active
// again) and null while the habit is still archived. dayKeys compare as strings.
export function isArchivedOn(archivedRanges: unknown, dayKey: string): boolean {
  if (!Array.isArray(archivedRanges)) return false;
  return archivedRanges.some((range) => {
    const start = range?.start;
    const end = range?.end;
    if (typeof start !== "string" || dayKey < start) return false;
    return typeof end !== "string" || dayKey < end;
  });
}

export function asNumber(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

// Whether a habit log or bucket-list item already paid its reward. Each pays
// once: unclaiming keeps the payout, so re-claiming pays nothing and
// claim → spend → unclaim → re-claim can't mint coins (2026-10-26).
export function rewardPaid(data: DocumentData | undefined): boolean {
  return asNumber(data?.awardedXp, 0) > 0 || asNumber(data?.awardedCoins, 0) > 0;
}

// The balance after taking back [amount] coins, for deletes, which do
// reverse a payout. Rejects instead of clamping at 0, so a delete can't keep
// coins that were already spent.
export function coinsAfterReversal(userData: DocumentData, amount: number): number {
  const coins = asNumber(userData.coins, 0);
  if (coins < amount) {
    throw new HttpsError(
      "failed-precondition",
      "You've already spent the coins this earned, so it can't be deleted.",
    );
  }
  return coins - amount;
}

export function readLevelState(userData: DocumentData): LevelState {
  return {
    level: asNumber(userData.level, 1),
    totalXp: asNumber(userData.totalXp, 0),
    xpIntoLevel: asNumber(userData.xpIntoLevel, 0),
  };
}

export function levelFields(state: LevelState) {
  return {
    level: state.level,
    totalXp: state.totalXp,
    xpIntoLevel: state.xpIntoLevel,
    xpForNextLevel: xpForLevel(state.level),
  };
}

export function currentPetStage(petData: DocumentData | undefined): PetStage | null {
  if (!petData) return null;
  return petData.stage === "evolution1" ? "evolution1" : "baby";
}

// Writes the pet's stage only when the new level actually crosses its threshold.
// A missing pet doc is skipped: stage is derived from level, so the next claim
// after provisioning re-syncs it.
export function syncPetStage(
  tx: Transaction,
  petRef: DocumentReference,
  petData: DocumentData | undefined,
  level: number,
): PetStage | null {
  const previous = currentPetStage(petData);
  if (!petData || !previous) return previous;
  const next = petStageForLevel(previous, level, EVOLUTION_LEVEL);
  if (next !== previous) tx.update(petRef, { stage: next });
  return next;
}
