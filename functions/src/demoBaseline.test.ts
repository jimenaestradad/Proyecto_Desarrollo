import { test } from "node:test";
import assert from "node:assert/strict";
import { DEMO_MIN_COINS, evolutionBaseline, topUpCareItems, topUpCoins } from "./demoBaseline";

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

test("the baseline is one level short of evolving, a biggest goal away from it", () => {
  // Level 4 needs 400 to level up; 100 in the bar + a 300 goal = 400. 1+2+3 levels' worth = 600.
  assert.deepEqual(evolutionBaseline(5, 300), { level: 4, totalXp: 700, xpIntoLevel: 100 });
});

test("a goal bigger than the level's bar starts the bar empty; no goals does too", () => {
  assert.equal(evolutionBaseline(5, 5000).xpIntoLevel, 0);
  assert.equal(evolutionBaseline(5, 0).xpIntoLevel, 399);
});

test("a threshold of 1 or 2 never drops below level 1", () => {
  assert.equal(evolutionBaseline(1, 100).level, 1);
  assert.equal(evolutionBaseline(2, 100).level, 1);
});
