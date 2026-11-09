// Pure planning for demo-history Firestore documents, ported from HabitHistoryStore.seedHistory.
// Uses the same computeReward/claimValue as live claims.

import { claimValue, computeReward, numberOrNull, parseHabitDefinition } from "./rewards";
import { isScheduledOnKey } from "./adaptiveXp";

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
// deliberately moves back.
export function isScheduledForSeed(habit: SeedHabit, day: Date): boolean {
  return isScheduledOnKey(
    {
      repeat: habit.data.repeat,
      customDays: habit.data.customDays,
      createdKey: null,
      startKey: habit.startDate && localDayKey(habit.startDate),
      endKey: habit.endDate && localDayKey(habit.endDate),
      archivedRanges: habit.data.archivedRanges,
    },
    localDayKey(day),
  );
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

// Uses HabitHistoryStore._seedState odds, but logs minimum-only progress as unclaimed.
// Real claims snap progress to the target, so the mock’s claimed-at-minimum state cannot occur.
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

// Skips whole days so seeded calendar streaks can break.
// With several habits logged about 70% of the time, almost every day otherwise has activity.
export const DEFAULT_OFF_DAY_RATE = 0.12;

// Places one off day per round(1/rate) block at a stable pseudo-random position.
// Blocks spread breaks out; UTC parsing only numbers days, without interpreting a time zone.
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
