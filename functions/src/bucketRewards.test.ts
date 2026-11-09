import { test } from "node:test";
import assert from "node:assert/strict";
import {
  BUCKET_LIST_COIN_CAP,
  BUCKET_LIST_XP_CAP,
  bucketReward,
  weeklyPaidLimitReached,
} from "./bucketRewards";

test("a goal pays what it says, up to the caps", () => {
  assert.deepEqual(bucketReward({ xpReward: 150, coinReward: 50 }), { xp: 150, coins: 50 });
  assert.deepEqual(bucketReward({ xpReward: 5000, coinReward: 5000 }), {
    xp: BUCKET_LIST_XP_CAP,
    coins: BUCKET_LIST_COIN_CAP,
  });
});

test("bad or negative reward fields pay nothing", () => {
  for (const value of ["abc", NaN, -5, null, undefined]) {
    assert.deepEqual(bucketReward({ xpReward: value, coinReward: value }), { xp: 0, coins: 0 }, String(value));
  }
});

test("fractional rewards are rounded", () => {
  assert.deepEqual(bucketReward({ xpReward: 74.6, coinReward: 24.4 }), { xp: 75, coins: 24 });
});

test("the third paid goal in a week is the one that pays nothing", () => {
  assert.equal(weeklyPaidLimitReached(0), false);
  assert.equal(weeklyPaidLimitReached(1), false);
  assert.equal(weeklyPaidLimitReached(2), true);
  assert.equal(weeklyPaidLimitReached(5), true);
});
