# Nori — Feature Definitions

This is the working feature spec, built up incrementally as product decisions get made — it is
**not complete**. Each section below states what's actually **decided**; anything still open
lives in [OPEN_DECISIONS.md](OPEN_DECISIONS.md), not here. When a section here gets a firm
answer to one of those, move it here and delete the row there.

Status as of 2026-08-27: habits, completion, and XP are the most defined. Pet mechanics
(sections 5-7 below) are the least defined and the next thing to nail down.

## 1. Concept

Habit tracker + virtual pet game, closer to **Club Penguin Puffles** than a traditional RPG —
not a simple Tamagotchi. Three layers:

- **Habit tracker** — tracks real-world behavior.
- **Virtual pet** — turns consistency into progression, care, collection, rewards.
- **Social/accountability** — friends, competition, social pressure (vision-only, not MVP — see § MVP boundary).

```
complete habits → earn XP + coins → progress & care for pet(s) →
level / evolve / collect / customize pets → stay motivated
```

## 2. Habits

- User-defined, no fixed catalog.
- Five habit types by how progress is measured:
  - **Binary** — yes/no (e.g. "update finances this week").
  - **Quantity** — incremental amount, either a single running total (e.g.
    250→1000ml water) or a sum of entries across a period (e.g. 45 min
    creative work/week, logged in pieces). Was two separate types
    (Quantity/Cumulative) — merged since they behaved identically.
  - **Duration** — time-based (e.g. 45 min workout).
  - **Multiple-completion** — count out of N (e.g. 2/3 healthy meals).
  - **Limit/negative** — stay under a max, not reach a min (e.g. <2h social media).
- Recurring schedules: daily, weekly, selected-day. (Specific-days-of-week vs. X-times-per-period
  is still open — see OPEN_DECISIONS.)
- Optional start/end date. When the period ends, the habit is **archived, not deleted** —
  history/stats/streaks stay visible.
- **Vacation Mode / pause** — freezes scheduled obligations so paused time doesn't break streaks
  or hurt the pet. (Per-habit pause vs. a global mode — probably both, not formally decided.)

## 3. Completion & thresholds

- Logging partial progress alone does **not** earn XP — only meeting the commitment does. (Stops
  XP-farming via tiny repeated entries.)
- A habit can define a **minimum success threshold** separate from its **ideal target**:
  - below minimum → no success
  - minimum–target → streak preserved, no XP/reward (see below)
  - ≥ target → full XP/reward, streak preserved
  - above target → no extra XP; logging is capped at the target for now
- **How rewards are paid (current default, 2026-09-28 — open to revisiting):** claiming is always
  a manual button press. **Complete** snaps a progress habit to its target and pays full, even
  from 30/100 — it's an honor-system "I did it", same as a binary checkbox. **Mark Day Safe**
  (limit habits) claims the value as logged: full reward at or under the ceiling, nothing over it.
  Logging alone never pays. So the minimum threshold's job is streaks, not XP: a day logged to
  its minimum but never claimed still keeps the streak and isn't "missed" on the calendar
  (`Habit.keptStreak`).
- **Future idea — partial reward after the day ends.** Pay a reduced reward (e.g. ~70–75%) for a
  day that reached its minimum but wasn't claimed, settled once the day is over — e.g. a callable
  the app runs on open for past days, so no scheduled job or server-side timezone is needed.
  Deferred because past days stay editable from the calendar, so a settled payout would have to
  be re-checked and reversed whenever a past log changes. Paying the moment the minimum is
  crossed was ruled out: undoing the log would have to claw it back, and every log would become
  a Cloud Function call instead of a direct write.
- **Future idea — logging beyond the target** (e.g. 120/100) as a tracked-but-unrewarded value.

## 4. XP

- XP = permanent progression (never spent), separate from coins/resources (spendable). Drives
  levels → pet evolution.
- Scales with habit difficulty; user cannot self-assign arbitrary XP. Relies partly on the honor
  system by design — not trying to eliminate every possible exploit.
- **Adaptive XP** (Habitica-inspired): a habit starts at a difficulty-based XP value (user picks
  Easy/Medium/Hard at creation) and the system nudges it up if the user struggles, down if it's
  consistently easy — because the same habit isn't equally hard for everyone. Needs a bounded
  adjustment range (discussed ~0.5×–1.5×) so long neglect can't inflate XP indefinitely.
- **Cadence modifier**: less-frequent habits (weekly) should be worth more per completion than
  frequent ones (daily), but not proportionally more (a weekly shouldn't equal 7 dailies).
  Direction: `XP = base difficulty × cadence modifier × adaptive modifier`.
- All exact numbers (starting XP per difficulty, adaptive bounds, cadence multipliers) are
  undecided — see OPEN_DECISIONS.

## 5. Streaks

- Follow the habit's own schedule, not raw calendar days — a weekly habit's streak counts
  consecutive successful weeks; an M–F habit isn't broken by weekends.
- Minimum-threshold completion (not just full target) maintains a streak.
- Paused/Vacation-Mode time doesn't break a streak.
- Streak behavior for flexible schedules ("5x any day this week") is undecided.

## 6. Pet progression

- Levels and evolutions are separate: evolutions span level *ranges*, not one evolution per
  level. XP-per-level increases progressively (a curve).
- **XP curve (decided 2026-09-16):** `xpForNextLevel = 100 × currentLevel`. Level 1→2 costs 100
  XP, 2→3 costs 200, 6→7 costs 600. Cumulative XP to reach level n is `50 × n × (n − 1)`.
- **Evolution stages (decided 2026-09-16)** — three stages, spanning level ranges:

  | Stage | Levels | Cumulative XP to enter | Roughly, at ~100 XP/day |
  |---|---|---|---|
  | Baby | 1–6 | 0 | from day one |
  | Evolution 1 | 7–14 | 2,100 | ~3 weeks |
  | Evolution 2 (final) | 15+ | 10,500 | ~3–4 months |

  A "maxed out" pet means reaching Evolution 2. The pacing assumes a moderately consistent user
  with ~5 habits earning 50–150 XP/day; adjust the thresholds, not the curve, if that turns out
  wrong in practice.
- **MVP ships only the first evolution** (Baby → Evolution 1 at level 7). Evolution 2 is
  specified here so the art and thresholds are known, but is not built this semester.
- Pokémon is the inspiration for staged evolution only, not for gameplay.

## 7. Multiple pets (vision, not MVP)

Users can eventually own more than one pet (so reaching max evolution doesn't kill motivation):
adopt → care/level/evolve → unlock more pets → maintain a collection; friends can visit pets.

**Unlock mechanic (direction set 2026-09-16, still not MVP):** once a pet is maxed out —
Evolution 2, level 15 per §6 — the user can **buy an egg with coins and hatch a new pet**. That
ties the collection loop to the existing economy rather than inventing a separate unlock
currency, and gives late-game coins somewhere to go once the shop is exhausted. Egg price,
whether eggs are the *only* way to get a new pet, and whether species/appearance vary per egg
are all still open.

Still undecided: whether XP belongs to the user or the active pet, whether only one pet
progresses at a time, inactive-pet stat behavior, per-pet vs. shared inventory. See
OPEN_DECISIONS.

## 8. Pet care

- Explicitly **not** "habit completion directly heals the pet." Instead: habits → resources →
  user actively cares for the pet (feed/groom/play/medicine) — gives another reason to open the app.
- Stats: Hunger, Hygiene, Happiness, possibly Sickness/Health. Stats decay over time; actions
  (Feed, Groom/bathe, Play, Medicine) restore them.
- Key rule: missing a habit does **not** directly damage the pet. The chain is indirect — poor
  consistency → fewer resources → harder to maintain the pet → stats drift down.
- **The pet cannot die.** It can end up unhappy/dirty/hungry/sick, but there's no permanent
  punishment — coming back to the app should never feel discouraging.

## 9. Resources, currency & shop

- XP (progression) and coins/resources (spendable) are separate; completing a habit can award both.
- Coins spend on pet care/customization via a shop: normal food, better food, cake (pricier,
  possibly a power-up), grooming supplies, toys, medicine, cosmetics/hats.
- Shop economy isn't designed yet — coin amounts, prices, consumable vs. permanent items,
  power-ups, per-pet vs. shared inventory, cosmetic ownership are all undecided.
- **MVP**: a deliberately simplified version — roughly 3 stats + a few basic care actions/items —
  not a full economy, but not zero pet interaction either.

## 10. Social (vision, not MVP)

- Friend-based accountability (GymRats-inspired), not stranger leaderboards/global competition.
- Usernames, add/find friends.
- Vision features: friend leaderboard, friend competitions, activity feed, proof-of-completion
  posts, reactions/comments, friend streaks (Duolingo-style), visiting friends' pets.
- **Decided distinction**: normal/private habit completion is honor-system — counts toward XP,
  streak, pet progress, and the friend leaderboard without proof. **Formal competitions require
  proof** to count, but proof needs no friend approval (accountability, not moderation).
- Everything else here (scoring, leaderboard period, streak rules, privacy) is undecided and
  out of MVP scope regardless.
- A design-only mock (`SocialScreen`) ships in the bottom nav (2026-09-10), replacing the old
  Achievements tab slot — activity feed, leaderboard, competitions, circles, all static/unwired
  behind a "Preview only" banner. This is a visual placeholder, not a scope change: none of the
  above is built or decided by its existence. Achievements itself moved under Profile.

## 11. Bucket list

Built (2026-09-10, on explicit direction — moved up from the prior "future product" lean since it
turned out cheap to build on top of the existing habit reward plumbing). Habits reward consistency
(XP/progression); bucket-list goals reward a one-time major accomplishment with a bigger flat
XP/coin payout instead — no schedule, no streak, no adaptive multiplier, just add → mark achieved.
Reached from the Habits screen topbar (flag icon), not the bottom nav. Example items shipped as
seed data: visit Japan, run a marathon, graduate. Still open: themed mementos per item (e.g. a
Japan-themed pet accessory) instead of a flat XP/coin reward — not built, plain rewards for now.

## 12. Integrations — vision only, not MVP

Apple Health / Fitbit (auto-verify activity habits) and Duolingo-like services (achievement
unlocks) are documented as future possibilities only. External APIs add disproportionate
complexity for this semester's scope — do not build these without an explicit decision to do so.

## MVP boundary

**Must build:** account/profile; create/edit/pause habits; habit targets & schedules; progress
logging; minimum/full completion; XP; adaptive XP (some working form); levels; streaks; one pet;
at least one evolution; basic pet stats/care; basic coins/resources; basic care interactions;
possibly a few accessories/rewards.

**If time permits:** more evolution stages; multiple pets; a fuller shop/economy; more cosmetics.

(Bucket list moved out of this list — see §11, built 2026-09-10.)

**Vision/planning only — not this semester:** friend system, activity feed, proof uploads,
reactions/comments, friend leaderboard, competitions, friend streaks, visiting pets, Apple
Health, Fitbit, Duolingo/external integrations.

Rationale: the course requires a functional MVP *plus* later data/deploy/QA phases — scope has
to stay small enough to actually finish, not grow into a full social/game platform.

## Competitors / inspiration

- **Habitica** — habit gamification, XP, adaptive difficulty, rewards/consequences.
- **Finch** — virtual-pet-driven self-improvement.
- **GymRats** — social accountability, proof, friend activity, competitions.
- **Habit Tracker by Lightbyte Apps** — UI/UX inspiration, flexible habit tracking.
- **Club Penguin Puffles** — pet ownership/care/collection/emotional-attachment design inspiration.
- **Pokémon** — evolution-stage inspiration only, not overall gameplay.
