// Pure planning half of the demo-history seed script (seedHistory.ts). Ports
// HabitHistoryStore.seedHistory (lib/data/habit_history_store.dart) to real
// Firestore documents. No Firestore here, so it can be unit-tested directly.
//
// Payouts go through the same computeReward/claimValue as claimHabit, so a
// seeded claim pays exactly what a live one would.

import { claimValue, computeReward, parseHabitDefinition } from "./rewards";
import { isArchivedOn } from "./habitTransaction";

export type HabitRepeat = "daily" | "weekdays" | "weekends" | "custom";

export interface SeedHabit {
  id: string;
  data: Record<string, unknown>;
  // Local-midnight dates, already converted from Firestore Timestamps.
  startDate: Date | null;
  endDate: Date | null;
}

export interface SeedLog {
  habitId: string;
  dayKey: string;
  date: Date; // local midnight
  value: number;
  claimed: boolean;
  awardedXp: number;
  awardedCoins: number;
}

export interface SeedPlan {
  logs: SeedLog[];
  // Earliest seeded day per habit, for backdating createdAt — the app's
  // isScheduledOn hides every day before createdAt.
  earliestDayByHabit: Map<string, Date>;
  totalXp: number;
  totalCoins: number;
}

// Device-local yyyy-mm-dd, matching dayKey() in habit_history_store.dart.
export function localDayKey(date: Date): string {
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${date.getFullYear()}-${m}-${d}`;
}

export function localMidnight(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

// The last `days` days before `today`, oldest first. Today itself is never
// seeded: it's the user's live state.
export function pastDays(today: Date, days: number): Date[] {
  const base = localMidnight(today);
  const result: Date[] = [];
  for (let back = days; back >= 1; back--) {
    result.push(new Date(base.getFullYear(), base.getMonth(), base.getDate() - back));
  }
  return result;
}

// Habit.isScheduledOn minus the createdAt lower bound, which the seed
// deliberately moves back. ISO weekday: 1 = Monday … 7 = Sunday.
export function isScheduledForSeed(habit: SeedHabit, day: Date): boolean {
  if (isArchivedOn(habit.data.archivedRanges, localDayKey(day))) return false;
  if (habit.startDate && day < localMidnight(habit.startDate)) return false;
  if (habit.endDate && day > localMidnight(habit.endDate)) return false;

  const weekday = day.getDay() === 0 ? 7 : day.getDay();
  switch (habit.data.repeat as HabitRepeat) {
    case "weekdays":
      return weekday <= 5;
    case "weekends":
      return weekday >= 6;
    case "custom": {
      const custom = habit.data.customDays;
      return Array.isArray(custom) ? custom.includes(weekday) : true;
    }
    default:
      return true;
  }
}

// FNV-1a, same as _stableHash in habit_history_store.dart, so a re-run
// (or a dry run followed by --apply) plans the same history.
function stableHash(value: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < value.length; i++) {
    hash ^= value.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash;
}

// mulberry32 — a tiny seeded PRNG.
function seededRandom(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function numberOrNull(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

// Same odds as HabitHistoryStore._seedState. One difference: a progress habit
// that only reached its minimum is logged unclaimed, because claiming snaps it
// up to the target (claimValue) — the mock's "claimed at the minimum" state
// can't happen through the real claim flow.
export function seedDay(habit: SeedHabit, day: Date): Omit<SeedLog, "habitId" | "dayKey" | "date"> | null {
  const key = localDayKey(day);
  const random = seededRandom(stableHash(`${habit.id}#${key}`));
  const roll = random();
  const definition = parseHabitDefinition(habit.data);

  const claimed = (loggedValue: number) => {
    const value = claimValue(definition, loggedValue);
    const reward = computeReward(definition, value);
    return { value, claimed: true, awardedXp: reward.xp, awardedCoins: reward.coins };
  };
  const logged = (value: number) => ({ value, claimed: false, awardedXp: 0, awardedCoins: 0 });

  if (definition.type === "binary") {
    return roll < 0.72 ? claimed(0) : null;
  }

  const target = definition.targetValue ?? 0;
  if (definition.type === "limit") {
    // Limit habits succeed by staying under the ceiling.
    if (roll < 0.7) return claimed(round1(target * (0.2 + random() * 0.5)));
    return logged(round1(target * (1.05 + random() * 0.4)));
  }

  if (roll < 0.62) return claimed(target);
  const min = numberOrNull(habit.data.minThreshold);
  if (roll < 0.78 && min !== null) {
    return logged(round1(min + random() * (target - min) * 0.6));
  }
  if (roll < 0.9) return logged(round1(random() * (min ?? target) * 0.8));
  return null;
}

function round1(value: number): number {
  return Math.round(value * 10) / 10;
}

// Share of days skipped entirely, as if the user never opened the app. With
// several habits each logged ~70% of the time, almost every day has *something*
// kept, and the calendar's streak only breaks on a day with nothing kept — so
// without whole off days, any seed is one unbroken streak.
export const DEFAULT_OFF_DAY_RATE = 0.12;

// Exactly one off day per block of round(1/rate) days, at a stable
// pseudo-random position inside the block. Rolling each day independently
// clumped badly (a whole month with none, then several together); blocks
// keep the breaks spread out. dayKey is a real yyyy-mm-dd, so it's parsed as
// UTC purely to number the days, not to interpret any time zone.
export function isOffDay(dayKey: string, rate: number): boolean {
  if (rate <= 0) return false;
  const blockSize = Math.max(2, Math.round(1 / rate));
  const dayNumber = Math.round(Date.parse(`${dayKey}T00:00:00Z`) / 86400000);
  const block = Math.floor(dayNumber / blockSize);
  const offset = stableHash(`off#${block}`) % blockSize;
  return dayNumber - block * blockSize === offset;
}

export function planSeed(
  habits: SeedHabit[],
  days: Date[],
  existingLogKeys: Set<string>,
  isVacationDay: (day: Date) => boolean,
  offDayRate = DEFAULT_OFF_DAY_RATE,
): SeedPlan {
  const logs: SeedLog[] = [];
  const earliestDayByHabit = new Map<string, Date>();
  let totalXp = 0;
  let totalCoins = 0;

  for (const day of days) {
    if (isVacationDay(day)) continue;
    const dayKey = localDayKey(day);
    if (isOffDay(dayKey, offDayRate)) continue;
    for (const habit of habits) {
      // Never overwrite a day the user actually logged.
      if (existingLogKeys.has(`${dayKey}_${habit.id}`)) continue;
      if (!isScheduledForSeed(habit, day)) continue;
      const state = seedDay(habit, day);
      if (!state) continue;
      logs.push({ habitId: habit.id, dayKey, date: day, ...state });
      if (!earliestDayByHabit.has(habit.id)) earliestDayByHabit.set(habit.id, day);
      totalXp += state.awardedXp;
      totalCoins += state.awardedCoins;
    }
  }
  return { logs, earliestDayByHabit, totalXp, totalCoins };
}
