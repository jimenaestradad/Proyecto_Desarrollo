# Nori — Open Product Decisions

Things implementation will eventually need that aren't decided yet. Don't invent these — when a
task needs one, stop and ask. When one gets resolved, move the answer into
[FEATURES.md](FEATURES.md) (or code) and delete it here.

Grouped to match [FEATURES.md](FEATURES.md)'s sections.

## Habit mechanics
- Specific-days-of-week vs. X-times-per-period scheduling — support both, or just one? (they
  behave differently for streaks)
- Per-habit pause vs. a global Vacation Mode — likely both, not formally decided
- Retroactive logging (can a missed day be logged after the fact?)
- Editing an active habit's schedule/target — effect on history/streak?
- Negative/limit-habit implementation details

## XP balancing
- Exact XP % awarded for minimum-threshold-only completion (~70% was an example, not final)
- Starting XP values per difficulty tier (Easy/Medium/Hard — 10/20/30 were examples)
- Adaptive-XP formula and adjustment window (how much history, how fast it moves)
- Adaptive-XP multiplier bounds (~0.5×–1.5× was an example)
- Exact cadence multipliers (weekly vs. daily vs. other frequencies)
- Full XP-per-level curve

## Streaks
- Exact behavior for flexible/any-day-in-period schedules ("5x any day this week")

## Pet mechanics
- Evolution XP requirements / level thresholds per stage — still undecided overall, but one
  anchor point is set (2026-09-10): the existing breathing-sprite art (see
  `nori_breathing_sprite.dart`) reads visually as a toddler, not a newborn or an
  already-evolved pet, so the mock user (`kDemoUser` in `lib/data/user_repository.dart`)
  starts at **level 5** rather than level 1 or 18+ to match. `evolutionLevelThreshold`
  (`lib/data/pet_repository.dart`) is a placeholder testing value, lowered 2026-09-11 from
  20 to **7** (just above the level-5 starting point) purely so the evolution screen is
  reachable in a normal test session — not a real balance decision, along with thresholds
  for any stage beyond evolution1.
- How additional pets are unlocked
- Whether XP belongs to the user or to the currently active pet
- Whether only one pet can progress at a time
- How inactive pets' stats/needs behave
- Pet-care stat decay rates

## Economy
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

## Technical rules / edge cases
- Timezone / day-rollover handling
- Deleting a habit (vs. archiving)
- Missed-period handling
- Cheating / duplicate-completion prevention
- Data history retention

## Infrastructure
- Auth provider/strategy
- Database choice and schema
- Specific GCP services for hosting/deploy
