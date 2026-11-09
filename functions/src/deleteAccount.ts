import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { onCall } from "firebase-functions/v2/https";
import { userDocRefs } from "./docRefs";
import { requireAuth, requireRecentLogin } from "./requestArgs";

// Deletes the user tree and matching usernames before deleting the Auth user.
// Data goes first so failures leave a signed-in user who can safely retry.
export async function runDeleteAccount(uid: string): Promise<void> {
  const db = getFirestore();
  const usernames = await db.collection("usernames").where("uid", "==", uid).get();
  const batch = db.batch();
  for (const doc of usernames.docs) batch.delete(doc.ref);
  await batch.commit();

  await db.recursiveDelete(userDocRefs(db, uid).user);

  try {
    await getAuth().deleteUser(uid);
  } catch (error) {
    // Already gone (a retry after a timeout) is fine.
    if ((error as { code?: string }).code !== "auth/user-not-found") throw error;
  }
}

export const deleteAccount = onCall(async (request) => {
  const uid = requireAuth(request.auth?.uid);
  // Irreversible, so a session left open somewhere isn't enough.
  requireRecentLogin(request.auth?.token);
  await runDeleteAccount(uid);
  return { deleted: true };
});
