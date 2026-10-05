import { test } from "node:test";
import assert from "node:assert/strict";
import { isArchivedOn } from "./habitTransaction";

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
