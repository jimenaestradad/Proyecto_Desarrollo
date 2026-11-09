import { DayArgs } from "./requestArgs";
import { SeedHabit, SeedPlan, pastDays, planSeed } from "./seedPlan";

// How many days before today the demo reset keeps filled in, so the calendar, streaks and
// stats always have something to show.
export const DEMO_HISTORY_DAYS = 7;

// seedPlan reads days off a Date's local fields, so a Date built from a dayKey this way gives
// back the same dayKey on any server time zone.
export function dateFromKey(dayKey: string): Date {
  const [y, m, d] = dayKey.split("-").map(Number);
  return new Date(y, m - 1, d);
}

// Plans the last DEMO_HISTORY_DAYS days for [habits], skipping days that already have a log.
// Dates are rebuilt from the caller's own midnight (as claimHabit stores them) rather than the
// server's, because the app queries logs by those. Vacation is ignored: the reset turns it off.
export function planDemoHistory(
  habits: SeedHabit[],
  day: DayArgs,
  existingLogKeys: Set<string>,
  days: number = DEMO_HISTORY_DAYS,
): SeedPlan {
  const plan = planSeed(habits, pastDays(dateFromKey(day.dayKey), days), existingLogKeys, () => false);
  const callerOffset = day.dayStartMillis - day.utcMidnightMillis;
  const callerMidnight = (date: Date) =>
    new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()) + callerOffset);
  return {
    ...plan,
    logs: plan.logs.map((log) => ({ ...log, date: callerMidnight(log.date) })),
    earliestDayByHabit: new Map(
      [...plan.earliestDayByHabit].map(([id, date]) => [id, callerMidnight(date)]),
    ),
  };
}
