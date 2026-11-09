// Scales XP with recent habit history; coins keep the flat difficulty reward.
// Recomputes on every claim so unclaiming and re-claiming cannot ratchet XP.

import { isArchivedOn } from "./habitTransaction";
import { HabitDifficulty } from "./rewards";

// Per-difficulty bounds keep XP tiers separate and frequent completion more rewarding.
// Floors keep easy habits worthwhile; the hard ceiling limits domination of the level curve.
export const ADAPTIVE_BOUNDS: Record<HabitDifficulty, { min: number; max: number }> = {
  easy: { min: 0.85, max: 1.3 },
  medium: { min: 0.8, max: 1.2 },
  hard: { min: 0.87, max: 1.2 },
};

// How far back to look, and how much history is needed before adapting.
export const WINDOW_DAYS = 14;
export const MIN_SCHEDULED_DAYS = 5;
// Completion rate at or below which the habit counts as a struggle (pays
// the max), and at or above which it counts as easy (pays the min).
export const STRUGGLE_RATE = 0.4;
export const EASY_RATE = 0.9;

export function adaptiveMultiplier(difficulty: HabitDifficulty, completionRate: number | null): number {
  if (completionRate === null) return 1;
  const { min, max } = ADAPTIVE_BOUNDS[difficulty];
  const t = (completionRate - STRUGGLE_RATE) / (EASY_RATE - STRUGGLE_RATE);
  const clamped = Math.min(1, Math.max(0, t));
  return Math.round((max - clamped * (max - min)) * 100) / 100;
}

// The schedule fields isScheduledOn needs, already converted to the
// client's local dayKeys by the caller.
export interface HabitSchedule {
  repeat: unknown;
  customDays: unknown;
  createdKey: string | null;
  startKey: string | null;
  endKey: string | null;
  archivedRanges: unknown;
}

const DAY_MS = 24 * 60 * 60 * 1000;

function keyToUtc(dayKey: string): number {
  return Date.parse(`${dayKey}T00:00:00Z`);
}

// The `count` dayKeys before `dayKey`, oldest first. dayKeys are plain
// calendar dates, so UTC arithmetic on them is exact.
export function previousDayKeys(dayKey: string, count: number): string[] {
  const base = keyToUtc(dayKey);
  const keys: string[] = [];
  for (let back = count; back >= 1; back--) {
    keys.push(new Date(base - back * DAY_MS).toISOString().slice(0, 10));
  }
  return keys;
}

// Mirrors Habit.isScheduledOn (lib/models/habit.dart). ISO weekday: 1 = Mon.
export function isScheduledOnKey(habit: HabitSchedule, dayKey: string): boolean {
  if (habit.createdKey && dayKey < habit.createdKey) return false;
  if (habit.startKey && dayKey < habit.startKey) return false;
  if (habit.endKey && dayKey > habit.endKey) return false;
  if (isArchivedOn(habit.archivedRanges, dayKey)) return false;
  const utcDay = new Date(keyToUtc(dayKey)).getUTCDay();
  const weekday = utcDay === 0 ? 7 : utcDay;
  switch (habit.repeat) {
    case "weekdays":
      return weekday <= 5;
    case "weekends":
      return weekday >= 6;
    case "custom":
      return Array.isArray(habit.customDays) ? habit.customDays.includes(weekday) : true;
    default:
      return true;
  }
}

// Share of scheduled, non-vacation days in the window that were claimed, or
// null when there are too few to judge (new habits stay at 1.0×).
export function completionRate(
  scheduledKeys: string[],
  claimedKeys: Set<string>,
): number | null {
  if (scheduledKeys.length < MIN_SCHEDULED_DAYS) return null;
  const claimed = scheduledKeys.filter((key) => claimedKeys.has(key)).length;
  return claimed / scheduledKeys.length;
}
