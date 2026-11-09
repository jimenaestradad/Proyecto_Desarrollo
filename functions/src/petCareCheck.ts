import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { PET_CARE_COOLDOWN_MS, isPetCareDormant, notificationRefs, petCareMessage } from "./notifications";

// Low-vital notifications respect PET_CARE_COOLDOWN_MS.
// Computes lazy pet decay locally without writing the pet document.
// Every 6 hours, not hourly: it reads every pet document ever created (dormant ones included),
// so reads scale with registered users, not active ones. Vitals decay 1/hour, so a vital takes
// ~70 hours to fall below LOW_VITAL, and the notification is an in-app inbox entry nobody sees
// before opening the app, so hourly precision bought nothing and cost 6x the reads.
export const petCareCheck = onSchedule("every 6 hours", async () => {
  const db = getFirestore();
  const now = Date.now();
  const pets = await db.collectionGroup("pet").get();
  let sent = 0;
  let dormant = 0;
  let failed = 0;

  for (const petSnap of pets.docs) {
    const userRef = petSnap.ref.parent.parent;
    if (petSnap.id !== "main" || !userRef) continue;
    // Abandoned accounts stop getting reminders (the notifications collection is append-only).
    if (isPetCareDormant(petSnap.data(), now)) {
      dormant++;
      continue;
    }
    if (!petCareMessage(petSnap.data(), now)) continue;

    const refs = notificationRefs(userRef);
    try {
      const wrote = await db.runTransaction(async (tx) => {
        // Re-read here: the user may have cared for the pet since the scan above.
        const [freshPet, state] = await Promise.all([tx.get(petSnap.ref), tx.get(refs.state)]);
        const message = petCareMessage(freshPet.data() ?? {}, now);
        const last = state.get("petCareAt");
        if (!message || (last instanceof Timestamp && now - last.toMillis() < PET_CARE_COOLDOWN_MS)) {
          return false;
        }
        tx.set(refs.collection.doc(), {
          kind: "petCare",
          message,
          createdAt: FieldValue.serverTimestamp(),
          isRead: false,
        });
        tx.set(refs.state, { petCareAt: FieldValue.serverTimestamp() }, { merge: true });
        return true;
      });
      if (wrote) sent++;
    } catch (error) {
      // One user's bad data or failed write must not stop everyone after them.
      failed++;
      logger.error(`petCareCheck: skipped ${userRef.id}`, error);
    }
  }

  logger.info(
    `petCareCheck: ${pets.size} pets checked, ${dormant} dormant, ${sent} notified, ${failed} failed.`,
  );
});
