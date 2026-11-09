import { test } from "node:test";
import assert from "node:assert/strict";
import { dayKeyBefore, isDemoAccount } from "./resetDemoAccount";

test("only the demo account's verified email passes", () => {
  assert.ok(isDemoAccount({ email: "demo@test.com" }));
  assert.ok(isDemoAccount({ email: "Demo@Test.com" }));
});

test("any other or missing email is rejected", () => {
  for (const token of [undefined, {}, { email: "test@nori.com" }, { email: "xdemo@test.com" }, { email: 5 }]) {
    assert.equal(isDemoAccount(token), false, JSON.stringify(token));
  }
});

test("dayKeyBefore counts calendar days across month and year ends", () => {
  assert.equal(dayKeyBefore("2026-11-08", 7), "2026-11-01");
  assert.equal(dayKeyBefore("2026-03-02", 3), "2026-02-27");
  assert.equal(dayKeyBefore("2027-01-02", 5), "2026-12-28");
});
