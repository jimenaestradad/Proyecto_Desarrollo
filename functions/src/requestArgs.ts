import { HttpsError } from "firebase-functions/v2/https";

const HOUR_MS = 60 * 60 * 1000;

export function requireAuth(uid: string | undefined): string {
  if (!uid) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  return uid;
}

// A "/" would let the id address a different document path.
export function parseHabitId(value: unknown): string {
  if (typeof value !== "string" || value.length === 0 || value.length > 200 || value.includes("/")) {
    throw new HttpsError("invalid-argument", "habitId must be a non-empty document id.");
  }
  return value;
}

export interface DayArgs {
  dayKey: string;
  dayStartMillis: number;
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
  if (Math.abs(dayStartMillis - utcMidnight) > 14 * HOUR_MS) {
    throw new HttpsError("invalid-argument", "dayStartMillis doesn't match dayKey.");
  }
  if (dayStartMillis > Date.now()) {
    throw new HttpsError("invalid-argument", "Can't act on a future day.");
  }
  return { dayKey: match[0], dayStartMillis };
}
