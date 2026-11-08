import { asNumber } from "./habitTransaction";

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
