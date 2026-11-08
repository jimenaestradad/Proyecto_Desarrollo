import { asNumber } from "./habitTransaction";

// Bucket-list goals come in three sizes (small 75 XP / 25 coins, medium 150 / 50, big 300 / 100;
// lib/models/bucket_list_item.dart, BucketGoalSize). The server enforces the biggest one, so a
// hand-edited goal can't pay more, and at most BUCKET_PAID_GOALS_PER_WEEK goals pay in any rolling
// week, so a stream of self-made goals can't print coins (economy pass 2026-11-07).
export const BUCKET_LIST_XP_CAP = 300;
export const BUCKET_LIST_COIN_CAP = 100;
export const BUCKET_PAID_GOALS_PER_WEEK = 2;
export const BUCKET_PAID_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;

// asNumber, not Number(): the rules let a client write any type into these fields, and
// Number("abc") is NaN, which slips past both clamps. Rounded so a fractional reward can't leave
// fractional XP/coins.
export function bucketReward(itemData: Record<string, unknown>): { xp: number; coins: number } {
  const clamp = (value: unknown, cap: number) =>
    Math.round(Math.max(0, Math.min(asNumber(value, 0), cap)));
  return {
    xp: clamp(itemData.xpReward, BUCKET_LIST_XP_CAP),
    coins: clamp(itemData.coinReward, BUCKET_LIST_COIN_CAP),
  };
}

// [paidInWindow] is how many goals paid out within the last BUCKET_PAID_WINDOW_MS.
export function weeklyPaidLimitReached(paidInWindow: number): boolean {
  return paidInWindow >= BUCKET_PAID_GOALS_PER_WEEK;
}
