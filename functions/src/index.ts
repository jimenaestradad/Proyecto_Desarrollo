/**
 * Nori — Cloud Functions.
 *
 * See ../docs/BACKEND.md for the full plan this implements: the schema,
 * the Cloud-Functions-vs-direct-write rule of thumb, and the concrete
 * function list. Jimena's functions: onUserCreate (this file, so far),
 * purchaseCareItem, purchaseAccessory, completeBucketListItem,
 * uncompleteBucketListItem (not written yet). Valeria's: claimHabit,
 * unclaimHabit, setHabitCompleted (not written yet, separate file once
 * she starts — see docs/BACKEND.md "Division of labor").
 *
 * onUserCreate is a v1-style Auth trigger (functions.auth.user().onCreate)
 * rather than a v2 callable, on purpose: v2 doesn't have a direct
 * non-blocking "after this account was created" trigger equivalent to
 * v1's — v2's identity triggers (beforeUserCreated/beforeUserSignedIn) are
 * *blocking* functions that run synchronously as part of sign-up/sign-in
 * and are meant for validation, not this "provision some Firestore docs
 * afterward, don't hold up the response" job. Mixing v1 (this trigger)
 * and v2 (future callables like purchaseCareItem) in one codebase is
 * normal and supported.
 */

import * as admin from "firebase-admin";
import * as functionsV1 from "firebase-functions/v1";

admin.initializeApp();
const db = admin.firestore();

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
  const uid = user.uid;
  const now = admin.firestore.FieldValue.serverTimestamp();

  const batch = db.batch();

  batch.set(db.collection("users").doc(uid), {
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

  batch.set(db.collection("users").doc(uid).collection("pet").doc("main"), {
    name: "Nori",
    hunger: 100,
    hygiene: 100,
    happiness: 100,
    lastDecayAt: now,
    stage: "baby",
    evolutionLevelThreshold: 7,
  });

  batch.set(
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
