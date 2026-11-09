import { asNumber } from "./habitTransaction";
import { LevelState, xpForLevel } from "./xpCurve";

// What the demo account always starts a test session with: every care item
// (food and cake for hunger, shampoo and hair brush for hygiene, plushie and
// blanket for love) in stock, and enough coins to buy things. Floors only: an
// account that already has more keeps it.
export const DEMO_CARE_ITEM_IDS = ["food", "cake", "shampoo", "hair-brush", "plushie", "blanket"];
export const DEMO_MIN_CARE_ITEMS = 3;
export const DEMO_MIN_COINS = 500;

// Raises every catalog item to at least DEMO_MIN_CARE_ITEMS; other keys and higher counts stay.
export function topUpCareItems(counts: unknown): Record<string, number> {
  const next: Record<string, number> =
    counts !== null && typeof counts === "object" ? { ...(counts as Record<string, number>) } : {};
  for (const id of DEMO_CARE_ITEM_IDS) {
    next[id] = Math.max(asNumber(next[id], 0), DEMO_MIN_CARE_ITEMS);
  }
  return next;
}

export function topUpCoins(coins: number): number {
  return Math.max(coins, DEMO_MIN_COINS);
}

// Where a reset leaves the level: one level short of evolving, with just enough XP in the bar
// that completing the single biggest bucket goal crosses the evolution line. Habit XP earned
// since the last reset can't keep the pet evolved (reversing bucket payouts alone leaves it
// evolved when habits alone got past the threshold).
export function evolutionBaseline(evolutionLevelThreshold: number, largestGoalXp: number): LevelState {
  const level = Math.max(1, Math.floor(evolutionLevelThreshold) - 1);
  const xpIntoLevel = Math.min(
    xpForLevel(level) - 1,
    Math.max(0, xpForLevel(level) - Math.max(0, largestGoalXp)),
  );
  let totalXp = xpIntoLevel;
  for (let l = 1; l < level; l++) totalXp += xpForLevel(l);
  return { level, totalXp, xpIntoLevel };
}
