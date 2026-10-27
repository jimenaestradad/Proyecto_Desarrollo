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
- **Vacation Mode** — freezes scheduled obligations so paused time doesn't break streaks
  or hurt the pet. A global mode only: per-habit pause is out of MVP scope (decided 2026-09-30).
  Archiving a habit (see BACKEND.md) covers "stop tracking this one for now".

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
  adjustment range so long neglect can't inflate XP indefinitely. **Built 2026-10-06:** bounds
  are per difficulty so tiers never overlap (easy 9–13, medium 16–24, hard 26–36 XP; XP only, coins stay flat) — a hard
  habit can't break the curve and an easy one never stops paying. Rule and numbers in
  OPEN_DECISIONS.md "XP balancing".
- **Cadence modifier**: less-frequent habits (weekly) should be worth more per completion than
  frequent ones (daily), but not proportionally more (a weekly shouldn't equal 7 dailies).
  Direction: `XP = base difficulty × cadence modifier × adaptive modifier`.
- Starting XP per difficulty and cadence multipliers are still undecided — see OPEN_DECISIONS.

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
- **Frontend built on mock data (2026-10-21, on explicit direction from valevasqc):** the Social
  tab is now a full click-through frontend — hub, activity feed + post detail + proof composer,
  friends/requests/add/invite, friend profile + pet visits, leaderboard, competitions (list,
  create wizard, detail, invites, results, proof submission), circles (list, editor, detail),
  friend streaks, notifications, privacy/blocking, and a first-run intro. All of
  it reads and writes an in-memory `MockSocialRepository` (`AppData.social`, resets on restart):
  **no backend work, no cross-user data.** (Social achievements live under Profile → Achievements, not on the tab.) (Only "you" is real: name, username, level, XP, streak, pet and weekly XP are read from the signed-in account's existing data; everyone else is seeded.) Scope is unchanged for the semester: the
  backend for social is still a non-goal (see BACKEND.md), and every rule the screens show —
  competition types and scoring, leaderboard metric/period, friend-streak rule, privacy options,
  reward amounts — is a **mock placeholder, not a decision** (see OPEN_DECISIONS.md § Social).
  **Scope note (2026-10-26): the social backend is not being built for this MVP.** The tab exists
  to *show how Social would look*, not to work end to end, so bugs in the mock behavior (stale
  state after switching accounts, competitions that never expire, blocked users still listed, and
  so on) are accepted and aren't being fixed. Only fix something here if it crashes, or if it
  breaks a *real* screen (Home, Habits, Profile, Achievements) that shares code with it.
  Layouts came from two Stitch exports, rebuilt on our own design system (`docs/DESIGN.md`).
  The earlier design-only mock (2026-09-10) it replaces took the old Achievements tab slot;
  Achievements itself lives under Profile.

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
The one integration with a worked-out idea behind it is the health wearable below.

### Health wearable (watch / ring) — vision only, **out of scope**

**The idea (added 2026-10-21 by valevasqc):** connect a wearable — a smartwatch or a smart ring —
so Nori can react to how the user's body is doing, most memorably their **stress**. A stressed
day could show up as a pet that's a little subdued and comes to sit with you; a calm or
well-rested one as a pet that's bright and playful. It makes the pet feel *aware* of the person
rather than only of their checkbox history, which fits the "emotional attachment" goal in §6/§8.

**Ways Nori could use the data (brainstorm — none decided):**
- **Pet reacts to stress** — mood/animation and a gentle line ("rough day? I'm here"), plus an
  optional nudge toward a calming habit (breathing, a walk, water). This is the headline idea.
- **Sleep → energy** — a well-slept user gets a rested pet; a short night gets a sleepy one.
- **Auto-verify activity habits** — steps, workouts and sleep habits complete themselves from
  device data instead of a manual check-off (the older "Apple Health / Fitbit" idea above).
- **Stress-aware suggestions** — on a high-stress day, surface the lighter habits first or offer
  Vacation Mode (§2) rather than showing a long list.

**Guardrails to carry over from existing decisions (INFERRED — these follow from §8 and §2, they
aren't new rules):**
- **Never punish.** §8 says the pet cannot die and coming back should never feel discouraging;
  a high-stress reading must not drain stats, break a streak, or cut XP. Reacting = comfort, not
  consequence.
- **Don't let health data touch the economy.** XP, coins and streaks stay driven by habits, so
  nobody is rewarded for (or locked out by) what their body happens to do.
- **Opt-in, minimal and private.** Health data is among the most sensitive a user has. It would
  need an explicit permission prompt, a plain "what we read and why" screen, no sharing to the
  Social tab by default, and no medical claims — Nori reflects a signal, it doesn't diagnose.

**Technical shape (INFERRED — nothing researched or prototyped yet):**
- Android-only target (OVERVIEW.md), so Apple Health is moot; the natural route is **Android's
  Health Connect**, which wearables sync into, read from a Flutter plugin — one integration
  instead of one SDK per brand. The alternative (a Wear OS companion app) is a second app to
  build and ship, which is far heavier.
- Which watches and rings actually write to Health Connect, and which metrics they expose, is
  **UNRESOLVED** and should be checked before promising a specific device.
- **"Stress" is not a plain measurement.** Vendors compute their own stress/readiness scores,
  and it's unverified whether those reach Health Connect at all; the standard signals are things
  like heart rate, resting heart rate, heart-rate variability and sleep. A Nori-side "stress" would
  likely be derived from those, which is a modeling decision, not a field to read (see
  OPEN_DECISIONS.md).
- Health data would need to be handled on-device or in a locked-down user-owned subtree
  (BACKEND.md's `/users/{uid}` rule), and Google Play has its own review requirements for apps
  that request health permissions — both are extra work beyond the code.

Everything here is a direction for a later phase, not a commitment. Do not build any of it —
including a permission prompt, a plugin dependency, or a "connect a device" placeholder screen —
without an explicit decision from valevasqc.

## MVP boundary

**Must build:** account/profile; create/edit/pause habits; habit targets & schedules; progress
logging; minimum/full completion; XP; adaptive XP (some working form); levels; streaks; one pet;
at least one evolution; basic pet stats/care; basic coins/resources; basic care interactions;
possibly a few accessories/rewards.

**If time permits:** more evolution stages; multiple pets; a fuller shop/economy; more cosmetics.

(Bucket list moved out of this list — see §11, built 2026-09-10.)

**Vision/planning only — not this semester:** friend system, activity feed, proof uploads,
reactions/comments, friend leaderboard, competitions, friend streaks, visiting pets, health
wearable integration (watch/ring — §12), Apple Health, Fitbit, Duolingo/external integrations.

Rationale: the course requires a functional MVP *plus* later data/deploy/QA phases — scope has
to stay small enough to actually finish, not grow into a full social/game platform.

## Competitors / inspiration

- **Habitica** — habit gamification, XP, adaptive difficulty, rewards/consequences.
- **Finch** — virtual-pet-driven self-improvement.
- **GymRats** — social accountability, proof, friend activity, competitions.
- **Habit Tracker by Lightbyte Apps** — UI/UX inspiration, flexible habit tracking.
- **Club Penguin Puffles** — pet ownership/care/collection/emotional-attachment design inspiration.
- **Pokémon** — evolution-stage inspiration only, not overall gameplay.
