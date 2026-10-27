import { test } from "node:test";
import assert from "node:assert/strict";
import { localDayKeyOf, parseDayArgs, requireRecentLogin } from "./requestArgs";

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

test("requireRecentLogin: a sign-in within five minutes passes", () => {
  const now = Date.UTC(2026, 9, 26, 12, 0, 0);
  const justNow = { auth_time: now / 1000 - 30 };
  assert.doesNotThrow(() => requireRecentLogin(justNow, now));
  assert.doesNotThrow(() => requireRecentLogin({ auth_time: now / 1000 - 299 }, now));
});

test("requireRecentLogin: an old, missing or malformed sign-in time is rejected", () => {
  const now = Date.UTC(2026, 9, 26, 12, 0, 0);
  for (const token of [
    { auth_time: now / 1000 - 301 },
    { auth_time: now / 1000 - 86_400 },
    {},
    undefined,
    { auth_time: "yesterday" },
    { auth_time: Number.NaN },
  ]) {
    assert.throws(() => requireRecentLogin(token, now), /log in again/, JSON.stringify(token));
  }
});
