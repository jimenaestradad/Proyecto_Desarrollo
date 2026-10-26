// Adaptive XP (FEATURES.md §4). Scales XP only: coins stay at the flat
// difficulty amount (rewards.ts computeReward), so the shop economy doesn't
// shift with it.
//: a habit pays more while the user struggles
// with it and less once it's consistently easy for them. Built 2026-10-06;
// the numbers below are defaults (docs/OPEN_DECISIONS.md, "XP balancing").
// Pure, so it can be unit-tested; claimHabit does the Firestore reads.
//
// Recomputed from scratch on every claim from the habit's recent history —
// never stepped up or down from its previous value — so claiming, unclaiming
// and re-claiming can't ratchet it.

import { isArchivedOn } from "./habitTransaction";
import { HabitDifficulty } from "./rewards";

// Per-difficulty multiplier bounds. Chosen so the XP ranges never overlap
// (easy 9–13, medium 16–24, hard 26–36): adaptation fine-tunes a habit
// within its tier but never makes an easy habit out-earn a medium one. The
// floors keep an easy habit worth claiming; the hard ceiling keeps one
// struggled-with habit from dominating the level curve. The spreads are also
// narrow enough that completing a habit more often always earns more XP per
// day — wider ones (the first draft's easy 8–14, medium 15–25) paid a
// 90%-consistent user slightly less than an 80% one.
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
