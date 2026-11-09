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
- Retroactive logging — **shipped default:** any past day since the habit was created can be logged
  and claimed from the calendar or the Habits date strip (`claimHabit` only rejects days before
  `createdAt`, outside start/end, or archived). Open: whether to cap how far back.
- **Complete / Undo and what happens to XP and coins — decided 2026-11-08 (valevasqc).** Undo
  takes back exactly what the claim paid (XP, coins, and any level / pet-stage change that followed)
  and Redo pays again, so claim → undo nets zero and the "undo just for the coins" loop is gone.
  If the coins were already spent, the Undo is **refused** with "You've already spent the coins this
  earned, so it can't be undone." (the same rule as deleting a habit or bucket item) rather than
  flooring at 0 or allowing a negative balance, either of which keeps a purchase for free or adds a
  "you owe coins" state to every coin display. Bucket-list Uncomplete follows the same rule. The
  one-time first-habit accessory is never taken back. Replaces the pay-once rule of 2026-10-26;
  options considered: keep and label, clawback within a window, pay at day's end.
- Editing an active habit's schedule/target — effect on history/streak?
- Negative/limit-habit implementation details

## XP balancing
- Exact XP % awarded for minimum-threshold-only completion (~70% was an example, not final) —
  moot for now: as of 2026-09-28 the minimum keeps streaks but pays nothing; a partial reward is a
  logged future idea (FEATURES.md §3)
- Starting XP values per difficulty tier (Easy/Medium/Hard — 10/20/30 were examples)
- Resolved 2026-10-06 (valevasqc asked for it built with caps so hard habits don't break the
  system and easy ones stay rewarding; the specific numbers are defaults, change freely in
  `functions/src/adaptiveXp.ts`): **adaptive XP** recomputes on every claim from the habit's last
  14 days; ≤40% of scheduled days completed pays the max, ≥90% the min, linear between, 1.0× with
  under 5 days of history. Per-difficulty bounds: easy 0.85–1.3×, medium 0.8–1.2×, hard
  0.87–1.2× (9–13 / 16–24 / 26–36 XP), so the tiers never overlap. The spreads are capped so
  that completing a habit more often always earns more XP per day (a unit test enforces it; the
  first draft's wider easy/medium spreads paid a 90%-consistent user slightly less than an 80%
  one). **XP only — coins stay flat** at the difficulty amount (5/10/15), so adaptation never
  shifts the shop economy.
  - *(Written for the old level-7 evolution, 2,100 XP; the first evolution is now level 5, 1,000
    XP, see Pet mechanics.)* Effect on pacing to the first evolution, 5 medium habits: at 50% completion
    ~42 → ~38 days, at 70% ~30 → ~32, at 90% ~23 → ~29. It narrows the gap between struggling and
    consistent users rather than speeding everyone up; whether level 7 is the right evolution
    point is a separate open question (below).
  - **Open: allow a slight overlap between tiers?** Currently none, so the user-picked difficulty
    always dominates and a struggling user can re-label a habit to earn more. Overlap would let a
    struggled-with easy habit out-earn a mastered medium one, closer to "difficulty is personal".
    Default kept: no overlap.
- Exact cadence multipliers (weekly vs. daily vs. other frequencies)
- **What's actually live while these stay open (noted 2026-10-05):** `functions/src/rewards.ts`
  pays Easy/Medium/Hard = **10/20/30 XP**, coins = **XP ÷ 2** (5/10/15), times the adaptive
  multiplier (see above, per-difficulty caps). No cadence multiplier exists (a weekly habit pays the
  same as a daily one). So the base "examples" above are the shipped
  values by default, not by decision; confirming or changing them is a one-file change.
- Resolved 2026-09-16: **`xpForNextLevel = 100 × currentLevel`** (cumulative to reach level n is
  `50 × n × (n − 1)`). New accounts start at level 1 / 0 XP / 100 to next. The formula lives only
  in the Cloud Function, which writes level/xpIntoLevel/xpForNextLevel to the user doc — the
  client displays stored values and never recomputes. See [BACKEND.md](../technical/BACKEND.md).

## Streaks
- Exact behavior for flexible/any-day-in-period schedules ("5x any day this week")

## Pet mechanics
- Resolved 2026-11-07 (valevasqc, from the economy simulation): **Evolution 1 moved to level 5**
  (1,000 XP), curve unchanged, per FEATURES.md §6's "adjust the thresholds, not the curve". A
  typical player (5 habits, 70% done) gets there on about day 15, a light one (3 habits, 50%) on
  about day 32; at level 7 the light one never did within 60 days. Every pet uses the constant
  (`EVOLUTION_LEVEL` / `kEvolutionLevel`); the 7 stored on older pet documents is ignored.
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
- Whether Vacation Mode should pause pet decay. FEATURES.md §2 says paused time shouldn't hurt
  the pet, but only streaks and the calendar are frozen today: decay and the scheduled `petCareCheck`
  notification keep running (shipped default, 2026-09-15). Pausing would mean skipping the frozen
  span in `applyPetDecay` and in `petCareCheck`.
- Resolved 2026-11-07: pet-care stat decay is **1 point/hour** per stat, clamped 0–100
  (`kPetDecayPerHour`, mirrored in `functions/src/notifications.ts`). From full, a vital takes
  about 70 hours to reach the "Pet needs you" line (30). Was 2, the mock's demo value, which made
  care cost more than anyone earns (see Economy).

## Economy
- **Economy pass, resolved 2026-11-07 (valevasqc approved the whole set).** Method: an hour-by-hour
  simulation of four players (light: 3 habits at 50%; typical: 5 at 70%, twice a day; sporadic:
  typical but skips 30% of days; heavy: 8 at 90%), 200 random runs each over 60 days
  (`tool/economy_sim.py`). Before the pass, care cost about 106 coins a day against 14-78 earned, so
  the pet sat at 0 for 60-96% of the time for everyone but the heaviest user, no accessory was ever
  affordable, and a self-made bucket goal (typed reward, cap 250) paid 281 coins a day. Care cost is
  a cliff: while it stays near one medium habit's daily coins (~10), even the light player's pet is
  fine; slightly above that it is not. Shipped:

  | Lever | Before | Now |
  |---|---|---|
  | Pet decay | 2 points/hour | **1** |
  | Coins per habit (easy / medium / hard) | 5 / 10 / 15 | unchanged |
  | XP per habit | 10 / 20 / 30 × adaptive | unchanged |
  | Basic care items (food, shampoo, plushie), pack of 3 | 50 / 40 / 60 coins, restore 25 / 25 / 20 | **10 each, restore 25 each** |
  | Better care items (cake, hair brush, blanket), pack of 3 | 90 / 70 / 100, restore 45 / 45 / 40 | **18 each, restore 50 each** |
  | Accessories (sunglasses stay the free first-completion gift) | 120-180 | **Tail Charm Clasp 100, Horn Bow 180, Chef Hat 250, Steampunk Goggles 350, Flower Crown 500** (1,380 for the five). The clasp is cheapest because it is not drawn once Nori evolves |
  | Bucket-list reward | typed, up to 500 XP / 250 coins, unlimited goals | **Small 75 XP / 25 coins, Medium 150 / 50, Big 300 / 100; at most 2 paid goals per rolling week** |
  | First evolution | level 7 | **level 5** |
  | Starting care items | food 3, shampoo 2, plushie 1 | **food 3, shampoo 3, plushie 3**; still 0 coins |

  Result for the four players: pet healthy (every vital at 30 or more) 99-100% of the time; care
  takes 13-75% of coins (the light player spends most of theirs on care, as intended); a typical
  player buys the first accessory around day 5 and all five by day 60 (about every 10 days); a
  sporadic one gets 3-4 of 5; a light one the first around day 30. Coming back with all three vitals
  at 0 costs 60 coins to refill (about 1.6 typical days; before, 300). Accepted: a heavy player
  (8 habits at 90%) finishes the shop in about 3 weeks and ends day 60 with ~2,600 coins; the real
  fix is a bigger catalog (more accessories, room decor, eggs) when the game grows, not a daily cap.
  Simulator limits: habit days are independent random draws, the simulated player always cares for
  Nori first and then saves, and the Social +XP is not modelled.
  - Still open here: the demo account's baseline and `resetDemoAccount` are unchanged (every care
    item at 3+, 500 coins minimum); egg pricing for extra pets (FEATURES.md §7).
  - Old decision, superseded in part: 2026-09-16 "0 coins and `{food: 3, shampoo: 2, plushie: 1}`";
    coins stay 0, the items are now 3 / 3 / 3. The `sunglasses` accessory is unlocked on the user's
    **first habit completion** and is the **only** free accessory ever granted. See
    [BACKEND.md](../technical/BACKEND.md).
- Coins earned per habit completion — **shipped default, kept in the 2026-11-07 pass:** XP ÷ 2 at the
  base tier (5/10/15), not adapted (see XP balancing above)
- Consumable vs. permanent items
- Power-up design (e.g. cake's special effect)
- Per-pet vs. shared inventory/accessories
- Whether all 15 reference-sheet consumables (see `assets/source/accessories/README.md`) get wired
  in beyond the six care items and six accessories — undecided.
- Cosmetic ownership rules

## Social (vision-only — still not MVP regardless of these answers)
- Competition types & scoring
- Leaderboard period/scoring
- Friend-streak rules
- Privacy rules for feed/proof posts
- Profile avatars as an option instead of photos (idea only, 2026-11-08; see FEATURES.md §10)

## Health wearable integration (vision-only — out of scope, see FEATURES.md §12)
- Which route: Android's Health Connect (one integration, many brands) vs. a Wear OS companion app
  (heavier). Health Connect looks like the sensible default, but nothing has been checked.
- Which watches/rings must actually work, and what metrics they expose. Don't promise a device
  until it's verified to reach the app.
- What "stress" means in Nori: a vendor's own score if one is available, or something derived from
  heart rate / HRV / sleep — and how to avoid implying a medical reading.
- What Nori does with it: only mood/animation, or also suggested habits / lighter day lists /
  Vacation Mode prompts? Default leaning: comfort only, never any effect on XP, coins, streaks or
  stats.
- Where the data lives (on-device only vs. stored per user) and whether any of it is ever visible
  to friends — default leaning: private, never shown in Social.
- Consent and Play Store health-data requirements before any permission prompt is added.

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
- **In-app feed: decided and built (2026-10-21, valevasqc).** Level-up, pet evolution,
  first-completion gift, achievement unlocked, streak milestones (3/7/14/30/60/100/180/365
  days), and a "pet needs you" at most once per 24h when a vital drops below 30. See BACKEND.md, "In-app notifications". The
  event list and thresholds are defaults, open to change.
- Still open: anything outside the app. That means phone notifications, either local habit
  reminders (needs a reminder time on habits) or FCM push (streak warnings, social/competition
  events).

## Monetization
- **Proposal 2026-11-08, prices approved by valevasqc, rest not yet confirmed:** freemium with
  ads, three plans: Free (5 habits, 3 bucket-list goals, ads), Nori Plus ($3.99/mo, $29.99/yr) and
  Nori Duo ($5.99/mo, $44.99/yr, two linked accounts). All Social features are free on every plan.
  Tiers, ad rules and reasoning are in [COTIZACION.md](../business/COTIZACION.md) Part 2. The Nori Plus and
  payment preview screens show these plans since 2026-11-08 (still mock: no limits, billing or ads).
  Enforcing the Free limits is designed (BACKEND.md, "Plan limits") and planned for after the 2026-11-12 demo;
  the demo account would be on Duo.
- **iOS / App Store later (2026-11-08):** wanted after the Android launch, but costs more (Apple Developer
  $99/year vs. $25 once on Google Play, 15–30% commission, a Sign in with Apple requirement to verify,
  stricter review, ~52 h of extra work). Still out of scope for the semester (OVERVIEW.md); estimate in
  [COTIZACION.md](../business/COTIZACION.md) §7.
- Don't build billing, paywalls or the Free limits until valevasqc and Jimena confirm the proposal above.

## User flows / screens
All MVP screens are built (onboarding, habit creation, Home, logging, pet care, shop, profile —
see FEATURES.md). Still open: a real **rewards moment** on a plain claim (only level-up and
evolution have one — KNOWN_ISSUES.md "No reward feedback on claim itself") and the
**first-pet moment** beyond naming the pet.

- Decided 2026-09-16: the user **names their pet during onboarding** (default "Nori" if they
  skip). The name is written client-side after sign-up, not by the auth trigger — see
  [BACKEND.md](../technical/BACKEND.md). The surrounding first-pet flow is still undesigned.

## Technical rules / edge cases
- Timezone / day-rollover handling — partially resolved 2026-09-16 for backend purposes: the
  canonical day key is computed **device-local** by `dayKey()` and passed explicitly to Cloud
  Functions, which never derive the day from (UTC) server time. See [BACKEND.md](../technical/BACKEND.md).
  Still open: what happens when a user travels across timezones, and DST edges.
- Resolved 2026-09-30 (supersedes 2026-09-16's "deleting always archives"): a habit with
  history is **archived** (hidden from today on, restorable, `habitLogs` kept); one with at most
  2 active days can be **deleted** outright, taking back its rewards. See BACKEND.md,
  "Deleting vs. archiving a habit".
- Resolved 2026-09-30: **per-habit pause is out of MVP scope.** Vacation Mode (global) is the
  only pause.
- Missed-period handling
- Cheating / duplicate-completion prevention — mostly resolved: every claim goes through
  `claimHabit` (one claim per habit per day, rewards computed server-side), and since 2026-10-26
  each habit-day and bucket-list item holds one payout at a time (Undo takes it back, since 2026-11-08, and is refused if the coins were spent).
  Remaining known gaps are bounded and logged in KNOWN_ISSUES.md (backdated `createdAt`, pet
  vitals as a direct client write).
- Data history retention

## Infrastructure
- Resolved 2026-09-16: Firebase (Auth + Firestore + Cloud Functions, Node.js/TypeScript) — see
  [BACKEND.md](../technical/BACKEND.md) for schema, security-rules approach, and the Cloud Functions list.
- Resolved 2026-09-21, extended 2026-09-28: Auth is Firebase Auth with **email/password and
  Google Sign-In**, linkable in both directions — see `FirebaseAuthRepository` in
  `lib/data/firebase_auth_repository.dart` and BACKEND.md, "Auth" (account linking).
- Resolved in practice (GCP sprint, 2026-10): no GCP services beyond what Firebase provisions
  (Cloud Functions/Run, Cloud Scheduler for `petCareCheck`, Artifact Registry, a $5 budget alert).
  Still open: whether CI/CD deploys automatically (ROADMAP.md, GCP row).
