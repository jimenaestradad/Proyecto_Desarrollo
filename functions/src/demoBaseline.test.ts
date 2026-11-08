import { test } from "node:test";
import assert from "node:assert/strict";
import { DEMO_MIN_COINS, topUpCareItems, topUpCoins } from "./demoBaseline";

test("every catalog item is raised to at least three", () => {
  assert.deepEqual(topUpCareItems({ food: 0, cake: 1 }), {
    food: 3, cake: 3, shampoo: 3, "hair-brush": 3, plushie: 3, blanket: 3,
  });
});

test("counts above the floor are kept", () => {
  assert.equal(topUpCareItems({ food: 9 }).food, 9);
});

test("a missing or malformed inventory still gets a full set", () => {
  for (const counts of [undefined, null, 5, "x"]) {
    assert.equal(topUpCareItems(counts).blanket, 3, String(counts));
  }
});

test("other keys are left alone", () => {
  assert.equal(topUpCareItems({ extra: 2 }).extra, 2);
});

test("coins are floored, never lowered", () => {
  assert.equal(topUpCoins(0), DEMO_MIN_COINS);
  assert.equal(topUpCoins(DEMO_MIN_COINS + 250), DEMO_MIN_COINS + 250);
});
