import { test } from "node:test";
import assert from "node:assert/strict";
import {
  HabitDefinition,
  claimValue,
  computeReward,
  parseHabitDefinition,
  petStageForLevel,
} from "./rewards";
import { LevelState, applyXpDelta } from "./xpCurve";

const fresh: LevelState = { level: 1, totalXp: 0, xpIntoLevel: 0 };

function habit(overrides: Partial<HabitDefinition>): HabitDefinition {
  return {
    type: "binary",
    difficulty: "medium",
    targetValue: null,
    adaptiveMultiplier: 1,
    ...overrides,
  };
}

test("binary claim pays full base reward", () => {
  assert.deepEqual(computeReward(habit({ difficulty: "easy" }), 0), { tier: "full", xp: 10, coins: 5 });
});

test("progress habit snaps to target on claim and pays full", () => {
  const water = habit({ type: "quantity", difficulty: "easy", targetValue: 1000 });
  const value = claimValue(water, 750);
  assert.equal(value, 1000);
  assert.equal(computeReward(water, value).tier, "full");
});

test("reaching only the minimum pays nothing", () => {
  const study = habit({ type: "quantity", targetValue: 60 });
  assert.deepEqual(computeReward(study, 45), { tier: "none", xp: 0, coins: 0 });
});

test("limit habit claims the logged value, full under the ceiling, none over it", () => {
  const social = habit({ type: "limit", targetValue: 120 });
  assert.equal(claimValue(social, 200), 200);
  assert.equal(computeReward(social, 45).tier, "full");
  assert.deepEqual(computeReward(social, 200), { tier: "none", xp: 0, coins: 0 });
});

test("adaptive multiplier scales XP only", () => {
  const gym = habit({ type: "duration", difficulty: "hard", targetValue: 45, adaptiveMultiplier: 1.2 });
  assert.deepEqual(computeReward(gym, 45), { tier: "full", xp: 36, coins: 15 });
});

test("client-editable fields can't inflate rewards", () => {
  const parsed = parseHabitDefinition({
    type: "binary",
    difficulty: "hard",
    xpReward: 1_000_000,
    coinReward: 1_000_000,
    adaptiveMultiplier: 50,
  });
  assert.equal(parsed.adaptiveMultiplier, 1.5);
  assert.deepEqual(computeReward(parsed, 0), { tier: "full", xp: 45, coins: 15 });
});

test("unknown enum values fall back like Habit.fromJson", () => {
  const parsed = parseHabitDefinition({ type: "nonsense", difficulty: 3 });
  assert.equal(parsed.type, "binary");
  assert.equal(parsed.difficulty, "medium");
});

test("level curve is 100 × level per step", () => {
  assert.deepEqual(applyXpDelta(fresh, 99), { level: 1, totalXp: 99, xpIntoLevel: 99 });
  assert.deepEqual(applyXpDelta(fresh, 100), { level: 2, totalXp: 100, xpIntoLevel: 0 });
  assert.deepEqual(applyXpDelta(fresh, 299), { level: 2, totalXp: 299, xpIntoLevel: 199 });
  assert.equal(applyXpDelta(fresh, 2100).level, 7);
});

test("a single award can jump several levels", () => {
  assert.deepEqual(applyXpDelta(fresh, 500), { level: 3, totalXp: 500, xpIntoLevel: 200 });
});

test("claim → unclaim → claim returns to the same level state", () => {
  const start = applyXpDelta(fresh, 95);
  const award = computeReward(habit({ difficulty: "hard" }), 0).xp;
  const claimed = applyXpDelta(start, award);
  assert.equal(claimed.level, 2);
  const unclaimed = applyXpDelta(claimed, -award);
  assert.deepEqual(unclaimed, start);
  assert.deepEqual(applyXpDelta(unclaimed, award), claimed);
});

test("unclaim can drop several levels", () => {
  const high = applyXpDelta(fresh, 500);
  assert.deepEqual(applyXpDelta(high, -500), fresh);
});

test("pet evolves at the threshold and demotes below it", () => {
  assert.equal(petStageForLevel("baby", 6, 7), "baby");
  assert.equal(petStageForLevel("baby", 7, 7), "evolution1");
  assert.equal(petStageForLevel("evolution1", 6, 7), "baby");
});
