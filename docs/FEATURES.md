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
- Six habit types by how progress is measured:
  - **Binary** — yes/no (e.g. "update finances this week").
  - **Quantity** — incremental amount (e.g. 250→1000ml water).
  - **Duration** — time-based (e.g. 45 min workout).
  - **Multiple-completion** — count out of N (e.g. 2/3 healthy meals).
  - **Limit/negative** — stay under a max, not reach a min (e.g. <2h social media).
  - **Cumulative** — sum of entries across a period (e.g. 45 min creative work/week, logged in pieces).
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
  - minimum–target → partial XP/reward, streak preserved
  - ≥ target → full XP/reward, streak preserved
  - above target → no extra XP (not unlimited farming)
- Exact XP % for minimum-only completion is undecided (was discussed as ~70%, not final).

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

- Levels and evolutions are separate: evolutions span level *ranges* (e.g. levels 1–X = Baby,
  X–Y = Evolution 1), not one evolution per level. XP-per-level increases progressively (a curve).
- Vision: ~3 evolution stages (Pokémon is the inspiration for staged evolution only, not gameplay).
- MVP may ship with only **one** evolution implemented, while the fuller system stays documented
  for later.
- Exact XP requirements / level curve / evolution thresholds are undecided.

## 7. Multiple pets (vision, not MVP)

Users can eventually own more than one pet (so reaching max evolution doesn't kill motivation):
adopt → care/level/evolve → unlock more pets → maintain a collection; friends can visit pets.
Mechanics almost entirely undecided — how pets unlock, whether XP belongs to the user or the
active pet, whether only one pet progresses at a time, inactive-pet stat behavior, per-pet vs.
shared inventory. See OPEN_DECISIONS.

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

## 11. Bucket list / achievements (undecided whether it's even in scope)

Direction, not a commitment: habits reward consistency (XP/progression); bucket-list goals would
reward a one-time major accomplishment with a themed memento (e.g. "visit Japan" → a Japan-themed
pet item), without needing external APIs. Example items: travel, a concert, finishing a course,
a marathon, graduating. Current lean: **future product**, not MVP, unless it turns out trivial
to build.

## 12. Integrations — vision only, not MVP

Apple Health / Fitbit (auto-verify activity habits) and Duolingo-like services (achievement
unlocks) are documented as future possibilities only. External APIs add disproportionate
complexity for this semester's scope — do not build these without an explicit decision to do so.

## MVP boundary

**Must build:** account/profile; create/edit/pause habits; habit targets & schedules; progress
logging; minimum/full completion; XP; adaptive XP (some working form); levels; streaks; one pet;
at least one evolution; basic pet stats/care; basic coins/resources; basic care interactions;
possibly a few accessories/rewards.

**If time permits:** more evolution stages; multiple pets; a fuller shop/economy; bucket list;
more cosmetics.

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
