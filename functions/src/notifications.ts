// Writes server-observed in-app notifications in the event’s transaction.
// The client writes achievement and streak notifications.

import {
  DocumentData,
  DocumentReference,
  FieldValue,
  Timestamp,
  Transaction,
} from "firebase-admin/firestore";
import { PetStage } from "./rewards";

export type ServerNotificationKind = "levelUp" | "petEvolved" | "gift" | "petCare";

export interface PendingNotification {
  kind: ServerNotificationKind;
  message: string;
}

// Mirrors kPetDecayPerHour (lib/data/pet_repository.dart) -- change both together.
export const PET_DECAY_PER_HOUR = 1;
// A vital below this (out of 100) earns a "Pet Needs You".
export const LOW_VITAL = 30;
// At most one pet-care notification per this window.
export const PET_CARE_COOLDOWN_MS = 24 * 60 * 60 * 1000;
// Stop reminding once the pet has gone this long without care. Vitals hit zero after ~4 days
// at 1/h, so this leaves about a week of daily reminders, then silence until the user cares
// for the pet again (care resets lastDecayAt, which is what this measures).
export const PET_CARE_DORMANT_AFTER_MS = 7 * 24 * 60 * 60 * 1000;

const ACCESSORY_NAMES: Record<string, string> = { sunglasses: "a pair of sunglasses" };

export function notificationRefs(userRef: DocumentReference) {
  return {
    collection: userRef.collection("notifications"),
    state: userRef.collection("notificationState").doc("main"),
  };
}

export function petNameOf(petData: DocumentData | undefined): string {
  const name = petData?.name;
  return typeof name === "string" && name.trim() !== "" ? name : "Nori";
}

export interface ProgressInput {
  previousLevel: number;
  level: number;
  previousPetStage: PetStage | null;
  petStage: PetStage | null;
  giftedAccessoryId: string | null;
  petName: string;
  // notificationState/main, or undefined if it doesn't exist yet.
  notified: DocumentData | undefined;
}

// Computes reward notifications; notificationState prevents duplicate level/evolution alerts.
// Pure for unit testing.
export function progressNotifications(input: ProgressInput): {
  notifications: PendingNotification[];
  stateUpdate: Record<string, unknown>;
} {
  const notifications: PendingNotification[] = [];
  const stateUpdate: Record<string, unknown> = {};
  const { petName, notified } = input;

  const notifiedLevel = typeof notified?.level === "number" ? notified.level : input.previousLevel;
  if (input.level > input.previousLevel && input.level > notifiedLevel) {
    notifications.push({
      kind: "levelUp",
      message: `${petName} grew! You reached Level ${input.level}.`,
    });
    stateUpdate.level = input.level;
  }

  if (
    input.previousPetStage === "baby" &&
    input.petStage === "evolution1" &&
    notified?.petEvolved !== true
  ) {
    notifications.push({ kind: "petEvolved", message: `${petName} evolved! Go say hi.` });
    stateUpdate.petEvolved = true;
  }

  if (input.giftedAccessoryId) {
    const item = ACCESSORY_NAMES[input.giftedAccessoryId] ?? "a new accessory";
    notifications.push({
      kind: "gift",
      message: `Your first completed habit earned ${petName} ${item}!`,
    });
  }

  return { notifications, stateUpdate };
}

// The rules let a client write any value here, so only a real Timestamp counts.
function lastDecayMillis(petData: DocumentData): number | null {
  const value = petData.lastDecayAt;
  return value instanceof Timestamp ? value.toMillis() : null;
}

/** True when the pet was last cared for over PET_CARE_DORMANT_AFTER_MS ago: stop nagging. */
export function isPetCareDormant(petData: DocumentData, nowMillis: number): boolean {
  const lastDecayAt = lastDecayMillis(petData);
  return lastDecayAt !== null && nowMillis - lastDecayAt > PET_CARE_DORMANT_AFTER_MS;
}

/** Pet-care message for the lowest vital after decay, or null if all are fine. */
export function petCareMessage(petData: DocumentData, nowMillis: number): string | null {
  const lastDecayAt = lastDecayMillis(petData);
  const hours = lastDecayAt !== null ? Math.max(0, (nowMillis - lastDecayAt) / 3_600_000) : 0;
  const drop = hours * PET_DECAY_PER_HOUR;
  const vital = (field: string) => {
    const value = petData[field];
    return (typeof value === "number" && Number.isFinite(value) ? value : 100) - drop;
  };
  const name = petNameOf(petData);
  const [value, text] = [
    [vital("hunger"), `${name} is hungry!`],
    [vital("hygiene"), `${name} needs a bath!`],
    [vital("happiness"), `${name} is feeling lonely!`],
  ].sort((a, b) => (a[0] as number) - (b[0] as number))[0] as [number, string];
  if (value >= LOW_VITAL) return null;
  return `${text} Take care of ${name} from the home screen.`;
}

/** Queues [notifications] and the state update on [tx]. Caller has done every read. */
export function writeNotifications(
  tx: Transaction,
  userRef: DocumentReference,
  notifications: PendingNotification[],
  stateUpdate: Record<string, unknown>,
): void {
  const refs = notificationRefs(userRef);
  for (const notification of notifications) {
    tx.set(refs.collection.doc(), {
      ...notification,
      createdAt: FieldValue.serverTimestamp(),
      isRead: false,
    });
  }
  if (Object.keys(stateUpdate).length > 0) {
    tx.set(refs.state, stateUpdate, { merge: true });
  }
}
