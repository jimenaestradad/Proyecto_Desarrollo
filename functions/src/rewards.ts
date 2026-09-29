// Pure habit-reward and progression math, ported from the Dart mocks:
// Habit.computeReward/rewardTier (lib/models/habit.dart),
// MockHabitRepository._claimValue (lib/data/habit_repository.dart),
// PetRepository.syncEvolution (lib/data/pet_repository.dart).
// No Firestore here, so it can be unit-tested directly.

export type HabitType = "binary" | "quantity" | "duration" | "multipleCompletion" | "limit";
export type HabitDifficulty = "easy" | "medium" | "hard";
export type RewardTier = "none" | "min" | "full";
export type PetStage = "baby" | "evolution1";

const HABIT_TYPES: readonly HabitType[] = [
  "binary", "quantity", "duration", "multipleCompletion", "limit",
];
const DIFFICULTIES: readonly HabitDifficulty[] = ["easy", "medium", "hard"];

const BASE_XP: Record<HabitDifficulty, number> = { easy: 10, medium: 20, hard: 30 };

const TIER_FRACTION: Record<RewardTier, number> = { none: 0, min: 0.75, full: 1 };

export interface HabitDefinition {
  type: HabitType;
  difficulty: HabitDifficulty;
  targetValue: number | null;
  minThreshold: number | null;
  adaptiveMultiplier: number;
}

function numberOrNull(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

// Unknown enum values fall back the same way Habit.fromJson does.
export function parseHabitDefinition(data: Record<string, unknown>): HabitDefinition {
  const type = HABIT_TYPES.includes(data.type as HabitType) ? (data.type as HabitType) : "binary";
  const difficulty = DIFFICULTIES.includes(data.difficulty as HabitDifficulty)
    ? (data.difficulty as HabitDifficulty)
    : "medium";
  const multiplier = numberOrNull(data.adaptiveMultiplier) ?? 1;
  return {
    type,
    difficulty,
    targetValue: numberOrNull(data.targetValue),
    minThreshold: numberOrNull(data.minThreshold),
    adaptiveMultiplier: Math.min(1.5, Math.max(0.5, multiplier)),
  };
}

// Base rewards come from difficulty, not the habit doc's xpReward/coinReward:
// firestore.rules lets clients edit those fields, so trusting them would let a
// client mint arbitrary XP. The add-habit screen always writes these same values.
export function baseRewards(difficulty: HabitDifficulty): { xp: number; coins: number } {
  const xp = BASE_XP[difficulty];
  return { xp, coins: Math.floor(xp / 2) };
}

// Pressing "Complete" snaps a progress habit up to its target; limit habits
// claim the value as logged, since their target is a ceiling.
export function claimValue(habit: HabitDefinition, loggedValue: number): number {
  if (habit.type === "limit") return loggedValue;
  const target = habit.targetValue;
  if (target === null || loggedValue >= target) return loggedValue;
  return target;
}

// Evaluated at claim time, so a binary habit's "completed" is always true here.
export function rewardTier(habit: HabitDefinition, value: number): RewardTier {
  const target = habit.targetValue;
  const inverted = habit.type === "limit";
  let targetMet: boolean;
  if (habit.type === "binary") targetMet = true;
  else if (inverted) targetMet = target !== null && value <= target;
  else targetMet = target !== null && value >= target;

  if (targetMet) return "full";
  if (inverted) return "none";
  const minMet = habit.minThreshold !== null && value >= habit.minThreshold;
  return minMet ? "min" : "none";
}

export function computeReward(
  habit: HabitDefinition,
  value: number,
): { tier: RewardTier; xp: number; coins: number } {
  const tier = rewardTier(habit, value);
  const fraction = TIER_FRACTION[tier];
  const base = baseRewards(habit.difficulty);
  return {
    tier,
    xp: Math.round(base.xp * habit.adaptiveMultiplier * fraction),
    coins: Math.round(base.coins * fraction),
  };
}

export function petStageForLevel(
  current: PetStage,
  level: number,
  evolutionLevelThreshold: number,
): PetStage {
  const shouldEvolve = level >= evolutionLevelThreshold;
  if (shouldEvolve && current === "baby") return "evolution1";
  if (!shouldEvolve && current === "evolution1") return "baby";
  return current;
}
