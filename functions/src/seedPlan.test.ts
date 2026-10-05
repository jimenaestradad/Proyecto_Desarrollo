import { test } from "node:test";
import assert from "node:assert/strict";
import { SeedHabit, isOffDay, isScheduledForSeed, localDayKey, pastDays, planSeed } from "./seedPlan";
import { computeReward, parseHabitDefinition } from "./rewards";

const habit = (id: string, data: Record<string, unknown>): SeedHabit =>
  ({ id, data, startDate: null, endDate: null });

// 2026-10-05 is a Monday.
const MONDAY = new Date(2026, 9, 5);

test("pastDays covers the days before today, oldest first, never today", () => {
  const days = pastDays(new Date(2026, 9, 5, 15, 30), 3);
  assert.deepEqual(days.map(localDayKey), ["2026-10-02", "2026-10-03", "2026-10-04"]);
});

test("repeat schedules match Habit.isScheduledOn", () => {
  const saturday = new Date(2026, 9, 3);
  assert.equal(isScheduledForSeed(habit("a", { repeat: "weekdays" }), MONDAY), true);
  assert.equal(isScheduledForSeed(habit("a", { repeat: "weekdays" }), saturday), false);
  assert.equal(isScheduledForSeed(habit("a", { repeat: "weekends" }), saturday), true);
  assert.equal(isScheduledForSeed(habit("a", { repeat: "custom", customDays: [1, 3] }), MONDAY), true);
  assert.equal(isScheduledForSeed(habit("a", { repeat: "custom", customDays: [2] }), MONDAY), false);
});

test("start/end window and archived stretches are skipped", () => {
  const windowed: SeedHabit = {
    ...habit("a", { repeat: "daily" }),
    startDate: new Date(2026, 9, 6),
    endDate: null,
  };
  assert.equal(isScheduledForSeed(windowed, MONDAY), false);
  const archived = habit("a", {
    repeat: "daily",
    archivedRanges: [{ start: "2026-10-05", end: "2026-10-07" }],
  });
  assert.equal(isScheduledForSeed(archived, MONDAY), false);
  assert.equal(isScheduledForSeed(archived, new Date(2026, 9, 7)), true);
});

test("plan is deterministic, skips existing logs and vacation, and pays like claimHabit", () => {
  const habits = [
    habit("bin", { repeat: "daily", type: "binary", difficulty: "hard" }),
    habit("qty", { repeat: "daily", type: "quantity", difficulty: "easy", targetValue: 8, minThreshold: 4 }),
    habit("lim", { repeat: "daily", type: "limit", difficulty: "medium", targetValue: 60 }),
  ];
  const days = pastDays(MONDAY, 60);
  const vacation = localDayKey(days[10]);
  const existing = new Set([`${localDayKey(days[0])}_bin`]);
  const plan = planSeed(habits, days, existing, (d) => localDayKey(d) === vacation, 0);

  assert.deepEqual(planSeed(habits, days, existing, (d) => localDayKey(d) === vacation, 0), plan);
  assert.ok(plan.logs.length > 60, "expected a believable amount of history");
  assert.ok(!plan.logs.some((l) => l.dayKey === vacation));
  assert.ok(!plan.logs.some((l) => l.habitId === "bin" && l.dayKey === localDayKey(days[0])));

  for (const log of plan.logs) {
    const definition = parseHabitDefinition(habits.find((h) => h.id === log.habitId)!.data);
    const expected = log.claimed ? computeReward(definition, log.value) : { xp: 0, coins: 0 };
    assert.equal(log.awardedXp, expected.xp);
    assert.equal(log.awardedCoins, expected.coins);
    // Claimed progress habits always sit at or above target (claimValue snaps up).
    if (log.claimed && log.habitId === "qty") assert.ok(log.value >= 8);
  }
  assert.equal(plan.totalXp, plan.logs.reduce((sum, l) => sum + l.awardedXp, 0));
  assert.equal(localDayKey(plan.earliestDayByHabit.get("lim")!) >= localDayKey(days[0]), true);
});

test("off days leave whole days empty so the streak can break", () => {
  const habits = [habit("bin", { repeat: "daily", type: "binary", difficulty: "easy" })];
  const days = pastDays(MONDAY, 200);
  const offKeys = days.map(localDayKey).filter((key) => isOffDay(key, 0.12));
  assert.ok(offKeys.length > 10 && offKeys.length < 40, `got ${offKeys.length} off days`);
  const plan = planSeed(habits, days, new Set(), () => false, 0.12);
  assert.ok(!plan.logs.some((l) => offKeys.includes(l.dayKey)));
  assert.equal(planSeed(habits, days, new Set(), () => false, 0).logs.length > plan.logs.length, true);
});
