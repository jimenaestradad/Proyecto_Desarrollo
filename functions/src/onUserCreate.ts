// Uses the v1 non-blocking Auth creation trigger to provision Firestore after sign-up.
// v2 identity triggers block sign-up/sign-in and are intended for validation.

import { FieldValue, getFirestore } from "firebase-admin/firestore";
import * as functionsV1 from "firebase-functions/v1";
import { userDocRefs } from "./docRefs";
import { EVOLUTION_LEVEL } from "./rewards";

// Provisions the user, starter pet, and inventory with the agreed balance values.
// The client fills profile fields and pet name afterward; sign-up grants no accessory.
export const onUserCreate = functionsV1.auth.user().onCreate(async (user) => {
  const db = getFirestore();
  const uid = user.uid;
  const refs = userDocRefs(db, uid);
  const now = FieldValue.serverTimestamp();

  // create(), not set(): if this trigger is ever delivered twice, the
  // second run fails instead of resetting a user who has already started.
  const batch = db.batch();

  batch.create(refs.user, {
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

  batch.create(refs.pet, {
    name: "Nori",
    hunger: 100,
    hygiene: 100,
    happiness: 100,
    lastDecayAt: now,
    stage: "baby",
    evolutionLevelThreshold: EVOLUTION_LEVEL,
  });

  batch.create(
    refs.inventory,
    {
      // Includes all six catalog IDs so care-item operations need no missing-key special case.
      careItemCounts: {
        food: 3,
        cake: 0,
        shampoo: 3,
        "hair-brush": 0,
        plushie: 3,
        blanket: 0,
      },
      ownedAccessoryIds: [],
      equippedAccessoryId: null,
    }
  );

  await batch.commit();
});
