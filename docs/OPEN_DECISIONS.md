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
- Evolution XP requirements / level thresholds per stage
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
- Cosmetic ownership rules

## Social (vision-only — still not MVP regardless of these answers)
- Competition types & scoring
- Leaderboard period/scoring
- Friend-streak rules
- Privacy rules for feed/proof posts

## Bucket list
- Whether it ships at all — MVP, future product, or cut (current lean: future product)
- What rewards/mementos it grants if built

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
