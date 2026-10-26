import { test } from "node:test";
import assert from "node:assert/strict";
import { coinsAfterReversal, isArchivedOn, rewardPaid } from "./habitTransaction";

test("isArchivedOn: open range covers its start day and everything after", () => {
  const ranges = [{ start: "2026-09-30", end: null }];
  assert.equal(isArchivedOn(ranges, "2026-09-29"), false);
  assert.equal(isArchivedOn(ranges, "2026-09-30"), true);
  assert.equal(isArchivedOn(ranges, "2027-01-01"), true);
});

test("isArchivedOn: closed range is end-exclusive (restore day is active)", () => {
  const ranges = [{ start: "2026-09-10", end: "2026-09-20" }];
  assert.equal(isArchivedOn(ranges, "2026-09-10"), true);
  assert.equal(isArchivedOn(ranges, "2026-09-19"), true);
  assert.equal(isArchivedOn(ranges, "2026-09-20"), false);
});

test("isArchivedOn: same-day archive+restore leaves an empty range", () => {
  assert.equal(isArchivedOn([{ start: "2026-09-30", end: "2026-09-30" }], "2026-09-30"), false);
});

test("isArchivedOn: tolerates a missing or malformed field", () => {
  assert.equal(isArchivedOn(undefined, "2026-09-30"), false);
  assert.equal(isArchivedOn("nope", "2026-09-30"), false);
  assert.equal(isArchivedOn([{ start: 5 }], "2026-09-30"), false);
});

test("coinsAfterReversal: takes back the full amount when the balance covers it", () => {
  assert.equal(coinsAfterReversal({ coins: 40 }, 15), 25);
  assert.equal(coinsAfterReversal({ coins: 15 }, 15), 0);
});

test("coinsAfterReversal: rejects when the coins were already spent", () => {
  assert.throws(() => coinsAfterReversal({ coins: 5 }, 15), /already spent/);
  assert.throws(() => coinsAfterReversal({}, 15), /already spent/);
});

test("rewardPaid: true once a log or item has paid anything, even after an unclaim", () => {
  assert.equal(rewardPaid({ claimed: false, awardedXp: 20, awardedCoins: 10 }), true);
  assert.equal(rewardPaid({ awardedXp: 0, awardedCoins: 5 }), true);
  assert.equal(rewardPaid({ claimed: false, awardedXp: 0, awardedCoins: 0 }), false);
  assert.equal(rewardPaid(undefined), false);
});
