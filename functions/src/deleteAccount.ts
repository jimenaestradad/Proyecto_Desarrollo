import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";
import { requireAuth } from "./requestArgs";

// Deletes everything the caller owns, then the Firebase Auth user itself:
// the whole /users/{uid} tree (habits, habitLogs, pet, inventory,
// bucketList, notifications, ...) and every /usernames entry pointing at
// this uid. A client can't delete subcollections in one step, which is why
// this is a function (docs/KNOWN_ISSUES.md, "Account settings are only half
// built"). Data goes first so a failure leaves a signed-in user who can
// simply retry; every step is safe to re-run.
export async function runDeleteAccount(uid: string): Promise<void> {
  const db = getFirestore();
  const usernames = await db.collection("usernames").where("uid", "==", uid).get();
  const batch = db.batch();
  for (const doc of usernames.docs) batch.delete(doc.ref);
  await batch.commit();

  await db.recursiveDelete(db.collection("users").doc(uid));

  try {
    await getAuth().deleteUser(uid);
  } catch (error) {
    // Already gone (a retry after a timeout) is fine.
    if ((error as { code?: string }).code !== "auth/user-not-found") throw error;
  }
}

export const deleteAccount = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  await runDeleteAccount(uid);
  return { deleted: true };
});
