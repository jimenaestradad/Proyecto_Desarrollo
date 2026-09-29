import { DocumentData, DocumentReference, Firestore, Transaction } from "firebase-admin/firestore";
import { PetStage, petStageForLevel } from "./rewards";

const DEFAULT_EVOLUTION_THRESHOLD = 7;

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
  const user = db.collection("users").doc(uid);
  return {
    user,
    habit: user.collection("habits").doc(habitId),
    log: user.collection("habitLogs").doc(`${dayKey}_${habitId}`),
    pet: user.collection("pet").doc("main"),
    inventory: user.collection("inventory").doc("main"),
  };
}

export function asNumber(value: unknown, fallback: number): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
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
  const threshold = asNumber(petData.evolutionLevelThreshold, DEFAULT_EVOLUTION_THRESHOLD);
  const next = petStageForLevel(previous, level, threshold);
  if (next !== previous) tx.update(petRef, { stage: next });
  return next;
}
