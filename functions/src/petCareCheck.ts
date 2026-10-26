import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { PET_CARE_COOLDOWN_MS, notificationRefs, petCareMessage } from "./notifications";

/**
 * Hourly: notifies each user whose pet has a vital below LOW_VITAL, at most
 * once per PET_CARE_COOLDOWN_MS. Time-based, so no user action triggers
 * it. Pet decay is lazy (applied when the app reads the pet), so this
 * computes the decayed values itself and never writes the pet doc.
 *
 * Reads every pet once an hour: 24 reads/user/day, fine at this scale. A
 * much bigger user base would want a query on a stored "low since" field.
 */
export const petCareCheck = onSchedule("every 60 minutes", async () => {
  const db = getFirestore();
  const now = Date.now();
  const pets = await db.collectionGroup("pet").get();
  let sent = 0;

  for (const petSnap of pets.docs) {
    const userRef = petSnap.ref.parent.parent;
    if (petSnap.id !== "main" || !userRef) continue;
    const message = petCareMessage(petSnap.data(), now);
    if (!message) continue;

    const refs = notificationRefs(userRef);
    const wrote = await db.runTransaction(async (tx) => {
      const last = (await tx.get(refs.state)).get("petCareAt");
      if (last instanceof Timestamp && now - last.toMillis() < PET_CARE_COOLDOWN_MS) {
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
  }

  logger.info(`petCareCheck: ${pets.size} pets checked, ${sent} notified.`);
});
