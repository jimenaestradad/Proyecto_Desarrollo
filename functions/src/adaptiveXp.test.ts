import { test } from "node:test";
import assert from "node:assert/strict";
import {
  ADAPTIVE_BOUNDS,
  EASY_RATE,
  HabitSchedule,
  STRUGGLE_RATE,
  adaptiveMultiplier,
  completionRate,
  isScheduledOnKey,
  previousDayKeys,
} from "./adaptiveXp";
import { baseRewards, HabitDifficulty } from "./rewards";

const DIFFICULTIES: HabitDifficulty[] = ["easy", "medium", "hard"];
const xp = (d: HabitDifficulty, m: number) => Math.round(baseRewards(d).xp * m);

test("tiers never overlap: an easy habit can't out-earn a medium one, nor a medium a hard one", () => {
  for (let i = 0; i < DIFFICULTIES.length - 1; i++) {
    const lower = DIFFICULTIES[i];
    const higher = DIFFICULTIES[i + 1];
    assert.ok(
      xp(lower, ADAPTIVE_BOUNDS[lower].max) < xp(higher, ADAPTIVE_BOUNDS[higher].min),
      `${lower} max must stay below ${higher} min`,
    );
  }
});

test("caps: easy never drops below 9 XP, hard never exceeds 36", () => {
  assert.equal(xp("easy", adaptiveMultiplier("easy", 1)), 9);
  assert.equal(xp("hard", adaptiveMultiplier("hard", 0)), 36);
});

test("completing a habit more often always earns more XP per day", () => {
  // Between the two rates, XP/day = rate × multiplier(rate) is a downward
  // parabola, so it rises everywhere iff it's still rising at EASY_RATE:
  // min ≥ EASY_RATE × (max − min) / (EASY_RATE − STRUGGLE_RATE).
  for (const d of DIFFICULTIES) {
    const { min, max } = ADAPTIVE_BOUNDS[d];
    const slope = (max - min) / (EASY_RATE - STRUGGLE_RATE);
    assert.ok(min >= EASY_RATE * slope, `${d}: a ${EASY_RATE * 100}% user would earn less per day than a less consistent one`);
  }
});

test("struggling pays the max, consistency pays the min, in between is proportional", () => {
  assert.equal(adaptiveMultiplier("medium", 0.2), ADAPTIVE_BOUNDS.medium.max);
  assert.equal(adaptiveMultiplier("medium", 0.4), ADAPTIVE_BOUNDS.medium.max);
  assert.equal(adaptiveMultiplier("medium", 0.95), ADAPTIVE_BOUNDS.medium.min);
  assert.equal(adaptiveMultiplier("medium", 0.65), 1);
});

test("too little history stays at 1.0x", () => {
  assert.equal(completionRate(["2026-10-01", "2026-10-02"], new Set()), null);
  assert.equal(adaptiveMultiplier("hard", null), 1);
});

test("completion rate counts claimed scheduled days only", () => {
  const keys = previousDayKeys("2026-10-06", 5);
  assert.deepEqual(keys, ["2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04", "2026-10-05"]);
  assert.equal(completionRate(keys, new Set(["2026-10-01", "2026-10-03", "2025-01-01"])), 0.4);
});

test("schedule mirrors Habit.isScheduledOn", () => {
  const base: HabitSchedule = {
    repeat: "weekdays", customDays: null, createdKey: null, startKey: null, endKey: null, archivedRanges: [],
  };
  assert.equal(isScheduledOnKey(base, "2026-10-05"), true); // Monday
  assert.equal(isScheduledOnKey(base, "2026-10-04"), false); // Sunday
  assert.equal(isScheduledOnKey({ ...base, repeat: "custom", customDays: [7] }, "2026-10-04"), true);
  assert.equal(isScheduledOnKey({ ...base, createdKey: "2026-10-06" }, "2026-10-05"), false);
  assert.equal(
    isScheduledOnKey({ ...base, archivedRanges: [{ start: "2026-10-05", end: null }] }, "2026-10-05"),
    false,
  );
});
