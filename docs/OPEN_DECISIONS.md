# Nori — Open Product Decisions

Things implementation will eventually need that aren't decided yet. Don't invent these — when a
task needs one, stop and ask. When one gets resolved, move the answer into
[FEATURES.md](FEATURES.md) (or code) and delete it here.

Grouped to match [FEATURES.md](FEATURES.md)'s sections.

## Habit mechanics
- Specific-days-of-week vs. X-times-per-period scheduling — support both, or just one? (they
  behave differently for streaks)
- Hard-deleting a habit that has real history (more than 2 active days): when its logs are
  wiped, do the XP/coins they earned stay or get taken back? Deferred 2026-09-30, so such a
  habit can only be archived for now. Keeping them is simpler; taking them back is consistent
  with bucket-list delete but could drop several levels and de-evolve the pet.
- Retroactive logging (can a missed day be logged after the fact?)
- Editing an active habit's schedule/target — effect on history/streak?
- Negative/limit-habit implementation details

## XP balancing
- Exact XP % awarded for minimum-threshold-only completion (~70% was an example, not final) —
  moot for now: as of 2026-09-28 the minimum keeps streaks but pays nothing; a partial reward is a
  logged future idea (FEATURES.md §3)
- Starting XP values per difficulty tier (Easy/Medium/Hard — 10/20/30 were examples)
- Adaptive-XP formula and adjustment window (how much history, how fast it moves)
- Adaptive-XP multiplier bounds (~0.5×–1.5× was an example)
- Exact cadence multipliers (weekly vs. daily vs. other frequencies)
- **What's actually live while these stay open (noted 2026-10-05):** `functions/src/rewards.ts`
  pays Easy/Medium/Hard = **10/20/30 XP**, coins = **XP ÷ 2** (5/10/15), times the habit's
  `adaptiveMultiplier` clamped to 0.5–1.5. No cadence multiplier exists (a weekly habit pays the
  same as a daily one), and nothing ever moves `adaptiveMultiplier` off 1.0 (KNOWN_ISSUES.md,
  "Adaptive XP is promised in the UI but never adjusts"). So the "examples" above are the shipped
  values by default, not by decision; confirming or changing them is a one-file change.
- Resolved 2026-09-16: **`xpForNextLevel = 100 × currentLevel`** (cumulative to reach level n is
  `50 × n × (n − 1)`). New accounts start at level 1 / 0 XP / 100 to next. The formula lives only
  in the Cloud Function, which writes level/xpIntoLevel/xpForNextLevel to the user doc — the
  client displays stored values and never recomputes. See [BACKEND.md](BACKEND.md).

## Streaks
- Exact behavior for flexible/any-day-in-period schedules ("5x any day this week")

## Pet mechanics
- Resolved 2026-09-16: the XP curve is `100 × currentLevel` and evolution stages are Baby 1–6,
  Evolution 1 at **level 7**, Evolution 2 at **level 15** (MVP ships only the first evolution).
  See [FEATURES.md](FEATURES.md) §6. The level-7 threshold that was a placeholder in
  `pet_repository.dart` is now the real value; `kDemoUser`'s level 5 still matches the
  breathing-sprite art reading as a toddler (2026-09-10 anchor), one level below evolving.
- Resolved 2026-09-16 (direction only, still not MVP): additional pets are unlocked by **buying
  an egg with coins once the current pet is maxed out** — see FEATURES.md §7. Egg pricing and
  whether eggs are the only unlock path are still open.
- Whether XP belongs to the user or to the currently active pet
- Whether only one pet can progress at a time
- How inactive pets' stats/needs behave
- Pet-care stat decay rates

## Economy
- Resolved 2026-09-16: new accounts start with **0 coins** and the care items
  `{food: 3, shampoo: 2, plushie: 1}`. The `sunglasses` accessory is unlocked on the user's
  **first habit completion** and is the **only** free accessory ever granted — everything else
  is bought with coins. See [BACKEND.md](BACKEND.md).
- Coins earned per habit completion
- Shop item prices
- Consumable vs. permanent items
- Power-up design (e.g. cake's special effect)
- Per-pet vs. shared inventory/accessories
- Care item tiers/pricing (2026-09-14): valevasqc asked for a choice of which owned item to use
  when caring for a stat, suggesting pricier items should restore more. Implemented as a
  placeholder — two tiers per stat (`lib/data/care_item_catalog.dart`: Food/Cake,
  Shampoo/Hair Brush, Plushie/Blanket), tier 2 priced and restoring roughly 1.7-2x tier 1 — but
  the actual price-to-restore-amount curve, and whether all 15 reference-sheet consumables
  (see `assets/source/accessories/README.md`) get wired in, are still undecided.
- Cosmetic ownership rules

## Social (vision-only — still not MVP regardless of these answers)
- Competition types & scoring
- Leaderboard period/scoring
- Friend-streak rules
- Privacy rules for feed/proof posts

## Bucket list
- Resolved 2026-09-10: it ships (see FEATURES.md §11). Still open: themed mementos per item
  instead of a flat XP/coin reward.

## Calendar
- Yearly stats view (beyond the current month grid) — requested, deliberately not built yet
  (2026-09-10 decision: document the idea rather than take on a possibly-large screen addition
  without knowing its scope first). Needs design/scope pass: what stats (completion rate,
  longest streak, per-habit breakdown?), a year-at-a-glance layout, and a decision on whether it
  reuses `CalendarRepository.getMonth` aggregated across 12 months or needs a new query shape.

## Notifications
- Whether any exist at all: habit reminders, streak warnings, pet-needs alerts, competition
  notifications — nothing decided yet

## Monetization
- End-user pricing model (free/premium/subscription/cosmetic purchases) — none chosen; don't
  build billing/paywalls without this

## User flows / screens
Not yet designed: onboarding, first-pet moment, habit creation, daily home screen, logging
progress, rewards moment, pet care screen, shop, profile.

- Decided 2026-09-16: the user **names their pet during onboarding** (default "Nori" if they
  skip). The name is written client-side after sign-up, not by the auth trigger — see
  [BACKEND.md](BACKEND.md). The surrounding first-pet flow is still undesigned.

## Technical rules / edge cases
- Timezone / day-rollover handling — partially resolved 2026-09-16 for backend purposes: the
  canonical day key is computed **device-local** by `dayKey()` and passed explicitly to Cloud
  Functions, which never derive the day from (UTC) server time. See [BACKEND.md](BACKEND.md).
  Still open: what happens when a user travels across timezones, and DST edges.
- Resolved 2026-09-30 (supersedes 2026-09-16's "deleting always archives"): a habit with
  history is **archived** (hidden from today on, restorable, `habitLogs` kept); one with at most
  2 active days can be **deleted** outright, taking back its rewards. See BACKEND.md,
  "Deleting vs. archiving a habit".
- Resolved 2026-09-30: **per-habit pause is out of MVP scope.** Vacation Mode (global) is the
  only pause.
- Missed-period handling
- Cheating / duplicate-completion prevention
- Data history retention

## Infrastructure
- Resolved 2026-09-16: Firebase (Auth + Firestore + Cloud Functions, Node.js/TypeScript) — see
  [BACKEND.md](BACKEND.md) for schema, security-rules approach, and the Cloud Functions list.
- Resolved 2026-09-21: Auth provider/strategy — Firebase Auth, email/password only for now — see
  `FirebaseAuthRepository` in `lib/data/firebase_auth_repository.dart`. Google Sign-In is tracked
  as its own separate task, not covered by this.
- Still open: specific GCP services beyond Firebase itself for hosting/deploy (the GCP phase in
  ROADMAP.md, not yet started).
