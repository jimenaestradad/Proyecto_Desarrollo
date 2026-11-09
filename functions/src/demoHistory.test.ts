import { test } from "node:test";
import assert from "node:assert/strict";
import { dateFromKey, planDemoHistory } from "./demoHistory";
import { parseDayArgs } from "./requestArgs";
import { localDayKey } from "./seedPlan";

// Guatemala, UTC-6: local midnight of 2026-11-08 is 06:00Z.
const day = parseDayArgs({ dayKey: "2026-11-08", dayStartMillis: Date.UTC(2026, 10, 8, 6) });
const daily = { id: "h1", data: { repeat: "daily", type: "binary", difficulty: "easy", xpReward: 10, coinReward: 5 }, startDate: null, endDate: null };

test("a dayKey round-trips through dateFromKey on any time zone", () => {
  assert.equal(localDayKey(dateFromKey("2026-03-01")), "2026-03-01");
});

test("history covers the days before today, never today, and skips days already logged", () => {
  const plan = planDemoHistory([daily], day, new Set(["2026-11-07_h1"]));
  const keys = plan.logs.map((log) => log.dayKey);
  assert.ok(keys.length > 0);
  assert.ok(keys.every((key) => key >= "2026-11-01" && key <= "2026-11-07"), keys.join());
  assert.ok(!keys.includes("2026-11-08"));
  assert.ok(!keys.includes("2026-11-07"));
});

test("log dates are the caller's local midnight, not the server's", () => {
  const plan = planDemoHistory([daily], day, new Set());
  for (const log of plan.logs) {
    const [y, m, d] = log.dayKey.split("-").map(Number);
    assert.equal(log.date.getTime(), Date.UTC(y, m - 1, d, 6), log.dayKey);
  }
  for (const date of plan.earliestDayByHabit.values()) assert.equal(date.getUTCHours(), 6);
});
