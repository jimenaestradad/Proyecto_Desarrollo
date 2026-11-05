import { test } from "node:test";
import assert from "node:assert/strict";
import { isDemoAccount } from "./resetDemoAccount";

test("only the demo account's verified email passes", () => {
  assert.ok(isDemoAccount({ email: "demo@test.com" }));
  assert.ok(isDemoAccount({ email: "Demo@Test.com" }));
});

test("any other or missing email is rejected", () => {
  for (const token of [undefined, {}, { email: "test@nori.com" }, { email: "xdemo@test.com" }, { email: 5 }]) {
    assert.equal(isDemoAccount(token), false, JSON.stringify(token));
  }
});
