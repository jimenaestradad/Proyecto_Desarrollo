// onUserCreate is a v1-style Auth trigger (functions.auth.user().onCreate)
// rather than a v2 callable, on purpose: v2 doesn't have a direct
// non-blocking "after this account was created" trigger equivalent to
// v1's — v2's identity triggers (beforeUserCreated/beforeUserSignedIn) are
// *blocking* functions that run synchronously as part of sign-up/sign-in
// and are meant for validation, not this "provision some Firestore docs
// afterward, don't hold up the response" job. Mixing v1 (this trigger)
// and v2 (the callables) in one codebase is normal and supported.

import { FieldValue, getFirestore } from "firebase-admin/firestore";
import * as functionsV1 from "firebase-functions/v1";

/**
 * Provisions a brand-new sign-up's /users/{uid} doc, starter pet, and
 * starter inventory. Values are exactly docs/BACKEND.md's "New-account
 * provisioning" table — do not tune game-balance numbers here, that's an
 * OPEN_DECISIONS.md question, not this function's.
 *
 * Deliberately NOT set here (left for the client to fill in immediately
 * after, as direct writes the security rules already allow):
 * - `name`, `username`, `avatarUrl` — this trigger fires the instant the
 *   Auth account exists, before the client's own sign-up flow has run
 *   updateProfile() or claimed a username (see docs/BACKEND.md, "Username
 *   uniqueness" — same race, same accepted sub-second window).
 * - Pet `name` — stays 'Nori' until onboarding writes a real one, also
 *   per docs/BACKEND.md (an auth trigger can't see a value typed on a
 *   later onboarding screen).
 *
 * No accessory is granted here — the one free accessory (sunglasses) is a
 * first-habit-completion gift, granted inside Valeria's claimHabit
 * transaction, not at sign-up. See docs/BACKEND.md.
 */
export const onUserCreate = functionsV1.auth.user().onCreate(async (user) => {
  const db = getFirestore();
  const uid = user.uid;
  const now = FieldValue.serverTimestamp();

  // create(), not set(): if this trigger is ever delivered twice, the
  // second run fails instead of resetting a user who has already started.
  const batch = db.batch();

  batch.create(db.collection("users").doc(uid), {
    name: "",
    username: "",
    email: user.email ?? "",
    avatarUrl: null,
    createdAt: now,
    level: 1,
    totalXp: 0,
    xpIntoLevel: 0,
    xpForNextLevel: 100,
    coins: 0,
    vacationModeEnabled: false,
    vacationRanges: [],
    habitCategories: [],
    firstHabitCompletedAt: null,
  });

  batch.create(db.collection("users").doc(uid).collection("pet").doc("main"), {
    name: "Nori",
    hunger: 100,
    hygiene: 100,
    happiness: 100,
    lastDecayAt: now,
    stage: "baby",
    evolutionLevelThreshold: 7,
  });

  batch.create(
    db.collection("users").doc(uid).collection("inventory").doc("main"),
    {
      // All six catalog ids present from the start (not just the ones
      // with a starting count) so consumeCareItem/purchaseCareItem never
      // have to special-case "this key doesn't exist yet" — see
      // care_item_catalog.dart for where these ids come from.
      careItemCounts: {
        food: 3,
        cake: 0,
        shampoo: 2,
        "hair-brush": 0,
        plushie: 1,
        blanket: 0,
      },
      ownedAccessoryIds: [],
      equippedAccessoryId: null,
    }
  );

  await batch.commit();
});
