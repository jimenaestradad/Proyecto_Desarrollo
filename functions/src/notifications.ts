// In-app notifications written server-side, in the same transaction as the
// event that caused them -- see ../docs/BACKEND.md, "In-app notifications".
// The app writes the two kinds only it can compute (achievement, streak);
// everything here is a kind the server sees happen.

import {
  DocumentData,
  DocumentReference,
  FieldValue,
  Transaction,
} from "firebase-admin/firestore";
import { PetStage } from "./rewards";

export type ServerNotificationKind = "levelUp" | "petEvolved" | "gift" | "petCare";

export interface PendingNotification {
  kind: ServerNotificationKind;
  message: string;
}

// Mirrors FirestorePetRepository._decayPerHour (lib/data/firestore_pet_repository.dart).
export const PET_DECAY_PER_HOUR = 2;
// A vital below this (out of 100) earns a "Pet Needs You".
export const LOW_VITAL = 30;
// At most one pet-care notification per this window.
export const PET_CARE_COOLDOWN_MS = 24 * 60 * 60 * 1000;

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

/**
 * What a reward just earned, notification-wise. Level and evolution ratchet
 * against notificationState, so undoing a claim and redoing it doesn't
 * notify twice. Pure, so it can be unit-tested.
 */
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

/** Pet-care message for the lowest vital after decay, or null if all are fine. */
export function petCareMessage(petData: DocumentData, nowMillis: number): string | null {
  const lastDecayAt = petData.lastDecayAt?.toMillis?.();
  const hours = typeof lastDecayAt === "number" ? Math.max(0, (nowMillis - lastDecayAt) / 3_600_000) : 0;
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
