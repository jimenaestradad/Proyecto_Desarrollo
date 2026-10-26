import { HttpsError } from "firebase-functions/v2/https";

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;

export function requireAuth(uid: string | undefined): string {
  if (!uid) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  return uid;
}

// A "/" would let the id address a different document path.
export function parseDocId(value: unknown, field: string): string {
  if (typeof value !== "string" || value.length === 0 || value.length > 200 || value.includes("/")) {
    throw new HttpsError("invalid-argument", `${field} must be a non-empty document id.`);
  }
  return value;
}

export function parseHabitId(value: unknown): string {
  return parseDocId(value, "habitId");
}

export interface DayArgs {
  dayKey: string;
  dayStartMillis: number;
  // dayKey's own UTC midnight; minus dayStartMillis, it's the client's UTC offset.
  utcMidnightMillis: number;
}

// The client sends its device-local day (docs/BACKEND.md "Dates and the
// day-rollover rule") — the server never derives it from UTC. dayStartMillis
// is that day's local midnight, stored as the log's `date` for range queries.
export function parseDayArgs(data: { dayKey?: unknown; dayStartMillis?: unknown }): DayArgs {
  const { dayKey, dayStartMillis } = data;
  const match = typeof dayKey === "string" ? /^(\d{4})-(\d{2})-(\d{2})$/.exec(dayKey) : null;
  if (!match) {
    throw new HttpsError("invalid-argument", "dayKey must be 'yyyy-mm-dd'.");
  }
  if (typeof dayStartMillis !== "number" || !Number.isFinite(dayStartMillis)) {
    throw new HttpsError("invalid-argument", "dayStartMillis must be a number.");
  }

  // UTC offsets range from −12h to +14h, so local midnight must sit within
  // 14h of the same calendar date's UTC midnight.
  const utcMidnight = Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
  // Date.UTC rolls impossible dates over ("2025-13-01" → 2026-01-01), which
  // would let one real day be claimed again under every alias. The callable
  // is reachable outside the app, so only an exact round-trip is accepted.
  if (new Date(utcMidnight).toISOString().slice(0, 10) !== match[0]) {
    throw new HttpsError("invalid-argument", "dayKey isn't a real date.");
  }
  if (Math.abs(dayStartMillis - utcMidnight) > 14 * HOUR_MS) {
    throw new HttpsError("invalid-argument", "dayStartMillis doesn't match dayKey.");
  }
  if (dayStartMillis > Date.now()) {
    throw new HttpsError("invalid-argument", "Can't act on a future day.");
  }
  return { dayKey: match[0], dayStartMillis, utcMidnightMillis: utcMidnight };
}

// The client-local dayKey of a date-only habit field (startDate/endDate),
// which the date picker stores as local midnight. Shifted by the caller's
// offset, then rounded to the nearest UTC midnight so a DST hour of drift
// can't tip it into the neighbouring day.
export function localDayKeyOf(dateOnlyMillis: number, day: DayArgs): string {
  const shifted = dateOnlyMillis + (day.utcMidnightMillis - day.dayStartMillis);
  return new Date(Math.round(shifted / DAY_MS) * DAY_MS).toISOString().slice(0, 10);
}
