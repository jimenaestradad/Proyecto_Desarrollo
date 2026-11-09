import { test } from "node:test";
import assert from "node:assert/strict";
import { Timestamp } from "firebase-admin/firestore";
import { PET_CARE_DORMANT_AFTER_MS, ProgressInput, isPetCareDormant, petCareMessage, progressNotifications } from "./notifications";

function input(overrides: Partial<ProgressInput>): ProgressInput {
  return {
    previousLevel: 4,
    level: 4,
    previousPetStage: "baby",
    petStage: "baby",
    giftedAccessoryId: null,
    petName: "Mochi",
    notified: undefined,
    ...overrides,
  };
}

const HOUR = 3_600_000;

test("level-up notifies and ratchets the notified level", () => {
  const result = progressNotifications(input({ level: 5 }));
  assert.deepEqual(result.notifications.map((n) => n.kind), ["levelUp"]);
  assert.match(result.notifications[0].message, /Mochi grew! You reached Level 5/);
  assert.deepEqual(result.stateUpdate, { level: 5 });
});

test("re-reaching an already-notified level stays quiet", () => {
  // Claimed to 5, unclaimed back to 4, claimed again.
  const result = progressNotifications(input({ level: 5, notified: { level: 5 } }));
  assert.deepEqual(result.notifications, []);
  assert.deepEqual(result.stateUpdate, {});
});

test("no level change, no notification", () => {
  assert.deepEqual(progressNotifications(input({})).notifications, []);
});

test("evolution notifies once", () => {
  const first = progressNotifications(input({ level: 7, previousLevel: 6, petStage: "evolution1" }));
  assert.deepEqual(first.notifications.map((n) => n.kind), ["levelUp", "petEvolved"]);
  const again = progressNotifications(input({
    level: 7, previousLevel: 6, petStage: "evolution1", notified: { level: 7, petEvolved: true },
  }));
  assert.deepEqual(again.notifications, []);
});

test("first-completion gift notifies", () => {
  const result = progressNotifications(input({ giftedAccessoryId: "sunglasses" }));
  assert.deepEqual(result.notifications.map((n) => n.kind), ["gift"]);
  assert.match(result.notifications[0].message, /sunglasses/);
});

test("pet care: healthy pet is quiet", () => {
  const now = Date.now();
  const pet = { name: "Mochi", hunger: 80, hygiene: 90, happiness: 70, lastDecayAt: Timestamp.fromMillis(now) };
  assert.equal(petCareMessage(pet, now), null);
});

test("pet care: decay since lastDecayAt counts, lowest vital is named", () => {
  const now = Date.now();
  // 40 hours at 1/h = -40: hunger 60 -> 20, hygiene 90 -> 50.
  const pet = { name: "Mochi", hunger: 60, hygiene: 90, happiness: 80, lastDecayAt: Timestamp.fromMillis(now - 40 * HOUR) };
  assert.match(petCareMessage(pet, now) ?? "", /^Mochi is hungry!/);
});

test("pet care: missing fields fall back to full and the default name", () => {
  assert.equal(petCareMessage({}, Date.now()), null);
  assert.match(petCareMessage({ hygiene: 10 }, Date.now()) ?? "", /^Nori needs a bath!/);
});

test("pet care: pets uncared-for past the dormancy window stop notifying", () => {
  const now = Date.now();
  const at = (agoMs: number) => ({ lastDecayAt: Timestamp.fromMillis(now - agoMs) });
  assert.equal(isPetCareDormant(at(PET_CARE_DORMANT_AFTER_MS - HOUR), now), false);
  assert.equal(isPetCareDormant(at(PET_CARE_DORMANT_AFTER_MS + HOUR), now), true);
  // No timestamp: can't tell, so don't silence it.
  assert.equal(isPetCareDormant({}, now), false);
});

test("pet care: a lastDecayAt that is not a Timestamp is ignored, not thrown on", () => {
  const forged = { name: "Mochi", hunger: 10, hygiene: 90, happiness: 80, lastDecayAt: { toMillis: 1 } };
  assert.equal(isPetCareDormant(forged, Date.now()), false);
  assert.match(petCareMessage(forged, Date.now()) ?? "", /hungry/);
});
