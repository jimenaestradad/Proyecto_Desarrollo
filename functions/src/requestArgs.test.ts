import { test } from "node:test";
import assert from "node:assert/strict";
import { localDayKeyOf, parseDayArgs } from "./requestArgs";

const HOUR_MS = 60 * 60 * 1000;

test("impossible dates are rejected, not rolled over", () => {
  for (const dayKey of ["2025-13-01", "2026-02-31", "2026-09-00", "2026-00-15", "0026-01-01"]) {
    const [y, m, d] = dayKey.split("-").map(Number);
    assert.throws(() => parseDayArgs({ dayKey, dayStartMillis: Date.UTC(y, m - 1, d) }), dayKey);
  }
});

test("a real date in any UTC offset is accepted", () => {
  const utc = Date.UTC(2026, 8, 24);
  for (const offsetHours of [-12, -6, 0, 5.5, 14]) {
    const day = parseDayArgs({ dayKey: "2026-09-24", dayStartMillis: utc - offsetHours * HOUR_MS });
    assert.equal(day.dayKey, "2026-09-24");
  }
  assert.ok(parseDayArgs({ dayKey: "2024-02-29", dayStartMillis: Date.UTC(2024, 1, 29) }));
});

test("date-only fields map back to the client's local day, DST drift included", () => {
  // Guatemala, UTC−6: local midnight of Sep 30 is 06:00Z.
  const day = parseDayArgs({ dayKey: "2026-09-24", dayStartMillis: Date.UTC(2026, 8, 24, 6) });
  assert.equal(localDayKeyOf(Date.UTC(2026, 8, 30, 6), day), "2026-09-30");
  assert.equal(localDayKeyOf(Date.UTC(2026, 8, 30, 5), day), "2026-09-30");
  assert.equal(localDayKeyOf(Date.UTC(2026, 8, 30, 7), day), "2026-09-30");
});
