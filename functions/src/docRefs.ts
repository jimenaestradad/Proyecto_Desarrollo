import { Firestore } from "firebase-admin/firestore";

// The one place the per-user Firestore paths are spelled out (the schema is
// in ../docs/BACKEND.md, "Firestore schema"). Everything a user owns lives
// under /users/{uid}; pet/main and inventory/main are single documents in
// collections of their own so more pets can be added later.
export function userDocRefs(db: Firestore, uid: string) {
  const user = db.collection("users").doc(uid);
  return {
    user,
    pet: user.collection("pet").doc("main"),
    inventory: user.collection("inventory").doc("main"),
    habits: user.collection("habits"),
    habitLogs: user.collection("habitLogs"),
    bucketList: user.collection("bucketList"),
  };
}

// A habit log's document id. habitLogs is one flat collection so a month's
// calendar is a single range query; the client builds the same id
// (FirestoreHabitRepository) and firestore.rules documents it.
export function habitLogId(dayKey: string, habitId: string): string {
  return `${dayKey}_${habitId}`;
}
