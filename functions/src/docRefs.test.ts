import assert from "node:assert/strict";
import { test } from "node:test";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { habitLogId, userDocRefs } from "./docRefs";

// Paths only — building references never touches the network.
const db = getFirestore(initializeApp({ projectId: "nori-test" }, "docRefs-test"));

test("user document paths match the schema", () => {
  const refs = userDocRefs(db, "u1");
  assert.equal(refs.user.path, "users/u1");
  assert.equal(refs.pet.path, "users/u1/pet/main");
  assert.equal(refs.inventory.path, "users/u1/inventory/main");
  assert.equal(refs.habits.doc("h1").path, "users/u1/habits/h1");
  assert.equal(refs.bucketList.doc("b1").path, "users/u1/bucketList/b1");
});

test("a habit log id is dayKey_habitId, in the flat habitLogs collection", () => {
  assert.equal(habitLogId("2026-10-26", "h1"), "2026-10-26_h1");
  const refs = userDocRefs(db, "u1");
  assert.equal(
    refs.habitLogs.doc(habitLogId("2026-10-26", "h1")).path,
    "users/u1/habitLogs/2026-10-26_h1",
  );
});
