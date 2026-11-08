# Nori — Backend Plan (Firebase)

Decided 2026-09-16: **Firebase Auth + Cloud Firestore + Cloud Functions (Node.js/TypeScript)**.
This doc is the technical reference for the **Backend, Data, and GCP** phases in
[ROADMAP.md](ROADMAP.md). It does not reopen product/scope questions;
[FEATURES.md](FEATURES.md) stays the source of truth for *what* the app does, and
[OPEN_DECISIONS.md](OPEN_DECISIONS.md) for unresolved game-balance numbers (XP curve, adaptive-XP
formula, cadence multipliers, shop prices, etc). Backend implements whatever balance math already
exists in the mock repos (`lib/data/*.dart`); it does not invent new balance numbers.

[firestore.rules](../firestore.rules) is the source of truth for what clients may write. This doc
explains the intent behind it. History (bugs found, deploys, verification runs) lives in
[RESOLVED_LOG.md](RESOLVED_LOG.md).

## Starting point

Every screen depends on abstract repositories (`HabitRepository`, `PetRepository`,
`UserRepository`, `InventoryRepository`, ...) in `lib/data/`. Each has an in-memory `Mock*`
implementation and a real `Firestore*` one; `app_data.dart` is the only file that decides which
is used. Firebase project `nori-pet` (Android + web) with one shared `functions/` TypeScript
codebase.

Course phases: **Data** = schema, rules, indexes, the plain-CRUD `Firestore*Repository` classes
and the seed script. **Backend** = Auth wiring, the Cloud Functions that enforce currency rules,
and the client code calling them. **GCP** = project/console config, secrets, CI/CD, deploys, cost.

## Architecture: what's a Cloud Function vs. a direct client write

**Rule of thumb: Cloud Functions guard the two currencies (XP, coins) and anything derived
from them (level, evolution stage). Everything else is a direct, rules-guarded client write.**
This is the "moderate" option — not full server-authoritative, not fully client-trusted — chosen
to keep the Cloud Functions surface small for a 2-person team while closing the one real cheat
vector (a client overwriting its own XP/coins field).

| Operation | How | Why |
|---|---|---|
| Habit create/update/reorder/archive | Direct client write | No currency involved |
| Habit delete (almost no history only) | **Cloud Function** | Must take back what its claims paid |
| `logProgress` / `setProgress` (non-claiming) | Direct client write | FEATURES.md §3: logging progress alone never earns XP |
| `claimHabit` / `unclaimHabit` (today or a past date) | **Cloud Function** | Mints XP + coins, must update habit log + user + pet atomically |
| Feed / groom / play (+ stat decay), spending the care item | Direct client write (one client transaction: `PetRepository.useCareItem` writes `pet/main` + `inventory/main`) | Spends an owned consumable for a pet stat, not currency; the pet "cannot die" so stakes are low |
| Buying a care item or accessory | **Cloud Function** | Spends coins to mint an owned item |
| Equip/unequip an owned accessory | Direct client write | No currency involved |
| Profile edit, vacation mode toggle | Direct client write | No currency involved |
| First-user provisioning (user doc, starter pet, care items) | **Cloud Function (`onCreate` auth trigger)** | Grants starting resources |
| Onboarding answer (pet name) | Direct client write, after sign-up | An auth trigger can't see it — it's typed on a later screen, and it isn't currency |
| One-time sunglasses gift on first completion | **Inside `claimHabit`** | Grants an item; must be atomic with the claim that triggers it |

## Firestore schema

All per-user data lives under `/users/{uid}`, secured by `request.auth.uid == uid`. No
cross-user queries exist (social is not built — FEATURES.md §10). The **one** exception is the
`/usernames` index, global because it enforces uniqueness *across* users.

```
/users/{uid}                        profile + progression (single doc)
  name, username, email, avatarUrl, createdAt
  level, totalXp, xpIntoLevel, xpForNextLevel, coins    # Cloud-Function-only
  vacationModeEnabled, vacationRanges: [{start, end}]   # small + always read with the user; array is fine
  # An open freeze is the last array entry with end == null; vacationModeEnabled mirrors
  # that as a quick boolean. See FirestoreVacationLog in lib/data/vacation_log.dart.
  habitCategories: [string]         # user-editable via Settings — NOT a static catalog, see below
  firstHabitCompletedAt: Timestamp? # null until first claim; gates the one-time sunglasses gift
  # currentStreak is deliberately NOT stored — see "Derived, never stored" below
  # avatarUrl stays null: profile and social proof photos are held in memory for the session
  # only (lib/data/session_photos.dart), standing in for Firebase Storage, which isn't set up.

/users/{uid}/habits/{habitId}      # a pure definition — no day-specific state
  name, subtitle, iconKey (string), colorKey (string),   # see "Conventions" — never store codePoints
  xpReward, coinReward, repeat, type, difficulty,        # enums stored as .name strings
  targetValue, unit, minThreshold,
  quickLogAmount, adaptiveMultiplier, customDays, allowVacationFreeze,
  startDate, endDate, order, archived (bool, default false — see deletion rule),
  archivedRanges ([{start, end}] dayKeys — see "Deleting vs. archiving a habit"),
  createdAt   # implicit lower bound for isScheduledOn: a new habit isn't "missed" before it existed
  # Today's value, completion and payout do NOT live here: they live in habitLogs for every
  # day, today included, so nothing on the habit doc needs resetting at midnight. A day's Habit
  # is built by merging the definition with that day's habitLogs entry (Habit.hydrate).

/users/{uid}/habitLogs/{dayKey}_{habitId}     # flat, not nested under habits/ — see below
  habitId, dayKey (string 'yyyy-mm-dd'), date (Timestamp, local midnight), value,
  claimed, awardedXp, awardedCoins              # ← Cloud-Function-only fields, see rules

/users/{uid}/pet/main                 # a collection with one doc today — see multi-pet note below
  name, hunger, hygiene, happiness, lastDecayAt,
  stage, evolutionLevelThreshold        # ← Cloud-Function-only fields, see rules

/users/{uid}/inventory/main
  careItemCounts (map<string,int>),      # client may only DECREASE known keys, see rules
  ownedAccessoryIds (array<string>),     # client may never ADD an id, see rules
  equippedAccessoryId                    # client may only set to an id already owned

/users/{uid}/bucketList/{itemId}
  title, description, iconKey, colorKey, xpReward, coinReward, isCompleted, completedAt,
  awardedXp, awardedCoins        # ← Cloud-Function-only; what completion ACTUALLY paid out

/users/{uid}/notifications/{id}        # in-app feed — see "In-app notifications"
  kind, message, createdAt, isRead

/users/{uid}/notificationState/main    # what has already been notified, so nothing repeats
  achievementIds, streakMilestone, streakMilestoneDay    # client-owned
  level, petEvolved, petCareAt                           # ← Cloud-Function-only

/usernames/{usernameLower}             # global — see "Username uniqueness"
  uid, username, createdAt
```

**The pet is a collection with one document, not a field on the user.** FEATURES.md §7's
multi-pet vision (buy an egg, hatch another) becomes additional documents in `pet/` plus an
`activePetId` on the user doc — no migration. Don't build any of that now; just don't collapse
the pet into the user doc.

**There is no `achievements` collection, on purpose.** `achievement_repository.dart` computes
every achievement's unlocked state on the fly from habits, calendar history, bucket list, pet
and inventory. Keep it that way.

**Why `habitLogs` is a flat collection, not a subcollection per habit:** the calendar/history
views need a range query across *all* habits for a month (`date >= X && date <= Y`), which a
per-habit subcollection would turn into a fan-out query per habit. This mirrors what
`habit_history_store.dart`'s comment anticipates (a table keyed by habit id and date). No
composite indexes are needed: every query filters on a single field.

**Static content catalogs** — `care_item_catalog.dart`, `accessory_catalog.dart`, and the
achievement *definitions* stay bundled Dart constants. Their string ids (`'food'`, `'cake'`,
`'shampoo'`, `'hair-brush'`, `'plushie'`, `'blanket'`; `'flower-crown'`, `'sunglasses'`, …) are
stable and are what Firestore stores.

**`habit_category_repository.dart` is NOT one of those.** Categories are user-editable from
Settings (add/rename/delete), so they're user data (`habitCategories` on the user doc). Renaming
a category deliberately does **not** cascade to habits already using it (habits keep their
`subtitle` text); preserve that behavior.

## Conventions — shared defaults

These need to *match* across both verticals (enums as strings on one side and ints on the other,
or one side switching to streams, and the app stops agreeing with itself). If a better answer
turns up while building, change it here so the other half follows.

**Keep `Future`, do not switch to `Stream`.** Every repository method returns a `Future` and
screens call them from `initState`/button handlers with `setState`; converting even one
repository to streams means rewriting that screen's state management. Live-updating UI is not an
MVP requirement. (The one exception is the unread-dot query on Habits; see "In-app
notifications".)

**Icons: use a string-key registry, never store `codePoint`.** Store the Material icon name
(`'water_drop'`, `'fitness_center'`, …) resolved through `lib/data/icon_registry.dart`.
Reconstructing `IconData(codePoint, fontFamily: 'MaterialIcons')` from a stored int **looks fine
in debug and renders blank boxes in the release APK** — `--tree-shake-icons` (on by default for
release builds) strips any icon not referenced as a constant. Unknown key on read → default
icon, don't crash.

**Colors: store the palette key, not an int.** `Habit.color` values come from `AppColors`
(`'sky'`, `'mossLight'`, `'blushPink'`, `'mustardLight'`, `'blush'`, …). Store the
field name and resolve it through `lib/data/color_registry.dart`, so a palette tweak doesn't
strand old rows. Unknown key → default (this is how retired `'linenAlt'` rows load, as `mossLight`).

**Enums: store `.name`** (`'daily'`, `'quantity'`, `'hard'`, `'baby'`), not index ints. Unknown
value on read → the current default (`HabitRepeat.daily`, `HabitDifficulty.medium`, …).

**Dates and the day-rollover rule.** `dayKey()` in `habit_history_store.dart` produces the
canonical `yyyy-mm-dd` key in **device-local** time. The client computes it and passes it
explicitly to every Cloud Function call. **Cloud Functions must never derive the day themselves**
— server time is UTC, so a claim at 9pm local would file under tomorrow for some users. Store
both `dayKey` (string, used in the doc id, what claim/unclaim look up) and `date` (Timestamp at
local midnight, used only for calendar range queries). The wider timezone question (travel, DST)
stays open in OPEN_DECISIONS.md.

**Derived, never stored.** Computed on read, because a stored copy already went stale once (see
the comment in `user_repository.dart`): `currentStreak` (from habit history via
`CalendarRepository`) and achievement unlock state.

**Balance numbers are still open**, so porting the mock's behavior as-is is the safe move —
filling the gaps in passing means the eventual real answer has to be un-picked from the code.
OPEN_DECISIONS.md tracks what's unresolved.
- `adaptiveMultiplier` is **computed by `claimHabit` on every claim**
  (`functions/src/adaptiveXp.ts`) from the habit's last 14 days, within per-difficulty caps, and
  stored on the habit doc only so the app can preview the next reward. The client never writes
  it (`FirestoreHabitRepository._definitionFields` leaves it out). Rule and numbers:
  OPEN_DECISIONS.md "XP balancing".
- Claims pay `full` (1.0×) or `none` — no partial tier: the minimum threshold keeps streaks but
  pays nothing (FEATURES.md §3). The Dart mock's `HabitRewardTier.min` (0.75×) is a leftover, see
  KNOWN_ISSUES.md.
- Care-item restore amounts and prices come from `care_item_catalog.dart` as-is.

**XP curve: `xpForNextLevel = 100 × currentLevel`** (decided 2026-09-16). Level 1→2 costs 100,
2→3 costs 200, 6→7 costs 600. Cumulative XP to *reach* level n is `50 × n × (n − 1)`. Only the
Cloud Function needs this formula: it writes `level`, `xpIntoLevel` and `xpForNextLevel` to the
user doc and the client displays the stored values, so the curve lives in one place. Don't
reimplement it in Dart.

**In-app notifications.** In-app only, no push. Whoever can see the event writes the
notification, in the same transaction as the event when there is one:

| Kind | Written by | When |
|---|---|---|
| `levelUp`, `petEvolved`, `gift` | `claimHabit`, `completeBucketListItem` (`functions/src/notifications.ts`) | The reward crosses a level, evolves the pet, or grants the first-completion gift |
| `petCare` | `petCareCheck`, a scheduled function that runs every hour | A pet vital (after lazy decay) is below 30, at most once per 24h, and only while the pet was cared for within the last 7 days |
| `achievement`, `streak` | The app (`FirestoreNotificationRepository`), when Notifications opens | A new unlocked achievement, or the streak reaches 3/7/14/30/60/100/180/365 |

- **Streaks and achievements stay on the client** because only the client computes them today.
  Moving them means porting those calculations to the server first. Until then they appear when
  Notifications is opened, timestamped then, and the rules only let the client create those two
  kinds.
- **No duplicates.** Level and evolution ratchet in `notificationState` (server-only fields
  `level`, `petEvolved`, `petCareAt`), so unclaiming and re-claiming doesn't repeat them.
  Achievements ratchet too. The streak milestone resets when the streak breaks, but not on the
  same day. The client's first sync only records a baseline, so an existing account isn't flooded.
- **Unread dot.** The bell on Habits listens to a `limit(1)` unread query, so server-written
  notifications show up live.
- **Icon, label and color come from `kind`** on the client, so restyling needs no migration.
- **Cost.** `petCareCheck` reads every pet once an hour (24 reads per user per day), fine at this
  scale. `PET_DECAY_PER_HOUR` in `notifications.ts` must match
  `FirestorePetRepository._decayPerHour`.

**Mocks stay until their replacement works.** Swap one repository at a time in `app_data.dart`.
Don't delete the `Mock*` classes — they're the fallback if a Firestore path misbehaves, they
back previews, and they document intended behavior.

**Online only — no offline mode.** Decided 2026-09-16: the app requires connectivity; offline
support is out of scope.

- Every action that hits Firestore or a Cloud Function can fail. Surface a plain error ("Couldn't
  reach the server — try again") and re-sync from the server. Habit actions (`OptimisticHabits`
  in `habit_day_actions.dart`), shop purchases and equip, care items, and bucket-list actions show
  the change on screen first and sync in the background. Each keeps a copy of what it showed
  before the first change in flight and restores it the moment a call fails, then shows the error
  and re-reads, so the undo works even when the server can't be reached. No retry queues, no sync
  layer; actions not listed here wait for the server and leave the UI as it was on failure.
- **Firestore's offline persistence is off** (`persistenceEnabled: false`, set in `main.dart`).
  It's on by default on mobile, and leaving it on gives the worst of both worlds: Cloud Function
  calls fail instantly offline while direct writes silently queue. Off means everything fails the
  same way, which is easier to reason about and to demo. With persistence off the SDK still holds
  a plain `set`/`update` in memory while offline and sends it when the connection returns, so a
  write behind an optimistic screen goes in a transaction that reads first (habit progress,
  bucket-list add/edit): a transaction needs the server and fails at once instead of landing
  after the screen has undone it.
- Network calls have a timeout (20s) so nothing hangs on a spinner forever.
- One shared helper (`RemoteLoadState` in `lib/utils/remote_errors.dart`) does "call, catch, show
  error"; it shouldn't become a per-screen pattern.

**Calls inside your own vertical are yours to make.** The defaults in this doc were worked out
before building, so they are a starting point, not a verdict — change what turns out wrong or
awkward. The one ask is to **write the answer down** (here or in OPEN_DECISIONS.md) so two people, or two AI sessions, don't diverge
unnoticed. Anything that crosses the seam between the two verticals (see Division of labor),
changes a number or rule the user sees, or contradicts FEATURES.md is worth a quick conversation
first.

## New-account provisioning — decided 2026-09-16

The values `onUserCreate` writes. The demo user (level 5, 7220 XP, 340 coins) is screenshot
dressing, not a starting state.

| What | Value |
|---|---|
| Level / XP | `level: 1`, `totalXp: 0`, `xpIntoLevel: 0`, `xpForNextLevel: 100` |
| Coins | `0` — the starter care items cover the first care actions |
| Care items | `{food: 3, shampoo: 3, plushie: 3}` (the other catalog ids are written as `0`; economy pass 2026-11-07) |
| Accessories | **None.** `ownedAccessoryIds: []`, `equippedAccessoryId: null` — the mock's pre-owned `sunglasses` is a demo artifact |
| Pet stats | `hunger/hygiene/happiness: 100`, `stage: baby`, `lastDecayAt: now`, `evolutionLevelThreshold: 5` (informational: every pet uses `EVOLUTION_LEVEL` in `functions/src/rewards.ts` / `kEvolutionLevel` in the app, so the 7 stored on older accounts is ignored; FEATURES.md §6) |
| Pet name | `'Nori'` until the user picks one — see below |
| First-completion flag | `firstHabitCompletedAt: null` |

**The sunglasses are the one and only free accessory, granted on the user's first habit
completion** — not at sign-up, and never again. Every other accessory is bought with coins.

- **Where it lives:** inside the `claimHabit` transaction. If `firstHabitCompletedAt` is null,
  the same transaction adds `'sunglasses'` to `ownedAccessoryIds`, sets `equippedAccessoryId` to
  it, and stamps `firstHabitCompletedAt`. Until then the pet renders with no accessory.
- **It is deliberately one-way.** Un-claiming that first habit does **not** take the accessory
  back or clear `firstHabitCompletedAt` — a gift that appears and vanishes while the user toggles
  a checkbox is worse than a tiny inconsistency. (Un-claiming never takes XP/coins back either,
  see the pay-once rule under Cloud Functions #3.)

**Pet naming changes the sequence.** An auth `onCreate` trigger only receives the auth record, so
`onUserCreate` provisions the pet as `'Nori'` and the onboarding screen writes the chosen name
afterward as a **direct client write** to `pet/main` (max 20 characters, `validatePetName`). If
the user skips onboarding, the name stays `'Nori'`.

**Deleting vs. archiving a habit** (decided 2026-09-30 by valevasqc).
- **Archive** works for any habit. It hides the habit from today onward and keeps every
  `habitLogs` document, because past streaks, calendar days and achievements are derived from
  them. Archived habits are listed on the Archived Habits screen (reached from Settings)
  and can be **restored**. Stored as `archived` (archived right now, used for that list) plus
  `archivedRanges`, the stretches it was archived as `{start, end}` device-local dayKeys. `end`
  is exclusive (the restore day counts again) and null while it's still archived.
  `Habit.isActiveOn` treats a day inside a stretch like a day past `endDate`: the habit isn't
  scheduled, so the stretch never reads as missed after a restore, and the days before the
  archive keep their history. `claimHabit` enforces the same rule via `isArchivedOn`.
  Past-day reads (`FirestoreHabitRepository.fetchAllDefinitions`, the calendar) use every
  definition and let `isActiveOn` decide per day; filtering archived habits out up front would
  erase them from history.
- **Delete** is only offered for a habit with almost no history: at most
  `kMaxDeletableActiveDays` (2) days with any logged progress or a claim. The threshold is a
  default; change it in both `habit_repository.dart` and `functions/src/deleteHabit.ts`. Delete
  goes through the `deleteHabit` Cloud Function, in one transaction: it removes the habit and all
  its logs, takes back whatever those claims paid (the exact stored amounts, including days
  later unclaimed), re-syncs `pet.stage`, and keeps the sunglasses gift. It is rejected if those
  coins were already spent. The client can never delete a habit doc directly.
- **Hard delete of a habit with real history is deferred**: whether its earned XP/coins should
  stay or be taken back is undecided. See OPEN_DECISIONS.md.

## Security rules

[firestore.rules](../firestore.rules) is authoritative; this is the intent.

- Default deny everywhere.
- `/users/{uid}` and everything under it: read/write only if `request.auth.uid == uid`.
- On the user doc: clients may write profile fields (`name`, `username`, `email`, `avatarUrl`) +
  `vacationModeEnabled`/`vacationRanges`/`habitCategories`. `level`, `totalXp`, `xpIntoLevel`,
  `xpForNextLevel`, `coins` are **denied to client writes** — only reachable via Cloud
  Functions, which use the Admin SDK and bypass rules entirely.
- Habit docs: clients may create them and edit the definition fields plus `order`, `archived`
  and `archivedRanges`. Clients can never delete one (`deleteHabit` does).
- `habitLogs` docs: clients may create a log only with `claimed: false` and zero awards, and may
  update **only `value`**. `claimed` / `awardedXp` / `awardedCoins` are Cloud-Function-only.
  Never deletable by clients.
- `pet/main`: clients may write `name`, `hunger`, `hygiene`, `happiness`, `lastDecayAt`.
  `stage` and `evolutionLevelThreshold` are **denied to client writes** — otherwise a client
  could set its own evolution stage, a currency-adjacent write. Only the Cloud Functions touch
  them (`claimHabit` and the bucket-list functions via `syncPetStage`).
- `inventory/main` needs different rules on different fields of the same document, because
  `consumeCareItem` and a purchase both write `careItemCounts`/`ownedAccessoryIds`, but only one
  of them should be able to grant something new:
  - `careItemCounts`: a client write may only **decrease** any of the known item ids (`food`,
    `cake`, `shampoo`, `hair-brush`, `plushie`, `blanket` — the catalog is small and closed, so
    checking each by name is practical) and may not add a new key. This lets `consumeCareItem`
    stay a direct write while `purchaseCareItem` stays the only way to *increase* a count.
  - `ownedAccessoryIds`: must satisfy
    `request.resource.data.ownedAccessoryIds.hasOnly(resource.data.ownedAccessoryIds)`, so a
    client can never add an accessory it doesn't own. Only `purchaseAccessory` and the sunglasses
    gift inside `claimHabit` add ids.
  - `equippedAccessoryId`: must be `null` or already in `resource.data.ownedAccessoryIds` —
    equip-only-what-you-own, enforced server-side rather than just by the UI.
- `bucketList/{itemId}`: clients may create an item only with `isCompleted: false` and zero
  awards, and edit only title/description/icon/color/rewards. Delete directly only while the item
  has never paid; anything that paid goes through `deleteBucketListItem`.
- `notifications/{id}`: clients may create only `achievement` and `streak` kinds (unread, server
  timestamp) and afterwards only flip `isRead`. The rest are written by Cloud Functions.
  `notificationState/main`: clients own `achievementIds`, `streakMilestone`,
  `streakMilestoneDay`; `level`, `petEvolved`, `petCareAt` are server-only.
- `/usernames/{usernameLower}`: the one global collection. Public `read` (availability is checked
  before an account exists). `create` only when authenticated, the id matches
  `[a-z0-9_]{3,20}`, `username` is a string that lowercases to the id, the keys are limited to
  `uid`/`username`/`createdAt`, and `uid` is the caller's. `delete` only by the owning uid,
  `update` never. The atomicity of "create fails if it already exists" is what enforces
  uniqueness — see "Username uniqueness".

## Cloud Functions

All callable except #1 (Auth trigger) and #11 (scheduled). Functions 1, 5, 6, 7, 8, 9 are
Jimena's; 2, 3, 10, 11, 12 are Valeria's. Keep this list short.

1. `onUserCreate` (Auth trigger) — provisions `/users/{uid}`, starter pet, starter inventory
   (see "New-account provisioning"; the pet name is a later client write).
2. `claimHabit({habitId, dayKey, dayStartMillis})` — computes the claim value + reward tier,
   writes habitLog + user (XP/coins/level) + pet (evolution sync) + inventory (first-completion
   gift) in one transaction (`functions/src/claimHabit.ts`, pure math in
   `functions/src/rewards.ts`).
   - **Day args are required.** `dayKey` is the client's device-local `yyyy-mm-dd`;
     `dayStartMillis` is that day's local midnight (becomes the log's `date`). The server checks
     they agree (within ±14h, the UTC-offset range), rejects impossible dates (`2026-02-31`),
     future days, days before the habit's `createdAt`, days outside its `startDate`/`endDate`,
     and archived days.
   - **Base XP/coins come from `difficulty`, not the habit doc's `xpReward`/`coinReward`.**
     `firestore.rules` lets clients edit those two fields, so trusting them would let anyone mint
     arbitrary XP. The add-habit screen writes exactly `difficulty.baseXp`/`baseCoins`, so real
     habits see no change. The stored `adaptiveMultiplier` is ignored for the same reason:
     `claimHabit` recomputes it from the last 14 days' logs (read with `getAll` on their known
     doc ids, so no index is needed) and writes the new value back in the same transaction.
   - **Level math uses `applyXpDelta` from `functions/src/xpCurve.ts`**, the single shared curve
     implementation, also used by the bucket-list functions. Handles multi-level jumps both
     ways (a `while` loop, not an `if`); claim → unclaim → claim lands on the identical level.
     The UI's level-up celebration must survive several firing from one call.
   - **Sunglasses gift** needs a non-`none` reward tier (a failed limit day isn't a
     "completion"), only equips if nothing is equipped yet, and is skipped (not stamped) if
     `inventory/main` doesn't exist, so it isn't lost before provisioning lands.
   - Already claimed → no-op returning `changed: false` and zero deltas. Returns `{changed,
     xpDelta, coinsDelta, previousLevel, level, previousPetStage, petStage, giftedAccessoryId}`
     so the client can fire level-up/evolution/gift celebrations without extra reads.
3. `unclaimHabit({habitId, dayKey, dayStartMillis})` (`functions/src/unclaimHabit.ts`; shared
   refs/result type/pet sync in `functions/src/habitTransaction.ts`) — **pay once per day:**
   unclaim only sets `claimed: false` and keeps `awardedXp`/`awardedCoins` on the log, and
   `claimHabit` pays nothing for a log that already paid (`rewardPaid` in `habitTransaction.ts`).
   Exact reversal would let claim → spend → unclaim → re-claim mint coins. Keeps the log's
   `value` (so progress stays editable), never revokes the sunglasses gift, and doesn't touch the
   user or pet. Not claimed → no-op. Bucket-list complete/uncomplete follow the same rule.
   Deletes (`deleteHabit`, `deleteBucketListItem`) still reverse every stored payout, and are
   rejected if those coins were already spent (`coinsAfterReversal`), so create → claim → delete
   can't mint either. Returns the same shape as `claimHabit`. (Whether Undo should claw back is
   reopened in OPEN_DECISIONS.md; the client's auto-complete at target and session-only restore
   of pre-Complete progress, `lib/data/habit_local_edits.dart`, change nothing server-side.)
4. *(unused: `setHabitCompleted` was removed as a duplicate; the binary checkbox calls
   `claimHabit`/`unclaimHabit` directly.)*
5. `purchaseCareItem(itemId, quantity)` — validates cost ≤ coins, decrements coins, increments
   `careItemCounts`. Prices are hand-synced with the Dart catalog (see `functions/src/shop.ts`
   for why they aren't trusted from the client).
6. `purchaseAccessory(accessoryId)` — validates cost ≤ coins, decrements coins, adds to
   `ownedAccessoryIds`. Rejects an accessory the user already owns, even if the UI hides it.
7. `completeBucketListItem(itemId)` — awards the item's XP/coins and **stores what it paid into
   `awardedXp`/`awardedCoins`** on the item. Syncs `pet.stage` in the same transaction, like
   `claimHabit` (the client can't write `stage`, so otherwise a bucket-list reward could cross
   the evolution level without evolving the pet).
8. `uncompleteBucketListItem(itemId)` — un-marks the item but keeps what it paid (pay once, see
   #3); completing it again pays nothing.
9. `deleteBucketListItem(itemId)` — deletes the item, first reversing its stored payout if it
   ever paid one, in one transaction. `firestore.rules` only lets the client delete an item
   directly while it isn't completed and has never paid.
10. `deleteHabit(habitId)` — deletes a habit with at most 2 active days plus all its logs,
    taking back what its claims paid, in one transaction. Rejects anything with more history
    with "archive it instead". See "Deleting vs. archiving a habit".
11. `petCareCheck` (scheduled, hourly) — writes a "pet needs you" notification when a pet's
    decayed vital is below 30, at most once per 24h. See "In-app notifications".
12. `deleteAccount()` — deletes the caller's `/usernames` entries, the whole `/users/{uid}` tree
    (`recursiveDelete`), then the Auth user. Data goes first so a failure leaves a signed-in
    user who can retry; every step is idempotent. Settings → Delete Account, behind typing the
    username. It also rejects a session that signed in more than 5 minutes ago
    (`requireRecentLogin`, `RECENT_LOGIN_MAX_AGE_MS` in `functions/src/requestArgs.ts`), so the
    app re-asks for the password (or a fresh Google sign-in) first and a phone left unlocked
    can't be used to wipe the account.

Also `resetDemoAccount`, dev-only; see "Local dev".

**Why 7 and 8 store what they paid:** bucket-list rewards are editable by the user at any time.
Reversing against the item's *current* value would let someone complete at 150 XP, edit to 3000,
un-complete, and walk away +2850 XP. Habits solve this with the log's `awardedXp`/`awardedCoins`;
the bucket list needs the same. Rule: reverse exactly what was paid, never a recomputation.

**Bucket-list rewards come in three sizes and are limited server-side** (sizes 2026-11-07,
supersedes the 500 XP / 250 coin cap of 2026-09-16). The add/edit sheet offers Small 75 XP / 25
coins, Medium 150 / 50 and Big 300 / 100 (`BucketGoalSize`) instead of typed numbers.
`completeBucketListItem` clamps whatever the item asks for to the biggest size
(`BUCKET_LIST_XP_CAP` 300 / `BUCKET_LIST_COIN_CAP` 100 in `functions/src/bucketRewards.ts`, mirrored
by `BucketListItem.maxXpReward` / `maxCoinReward`), and pays at most **2 goals in any rolling
week**: it stamps `paidAt` (function-only field) on each payout and counts the ones in the last 7
days. A third goal still becomes achieved but pays nothing and returns `limited: true` (the app
says so); it stays unpaid, so completing it again after the week pays it. Rationale: typed rewards
plus unlimited self-made goals paid up to 281 coins a day, buying the whole shop in 8 days
(`tool/economy_sim.py final`); sizes plus the weekly limit cut that to about 63. Bucket-list items
are still meant to feel much larger than a habit (10-30 XP); the limits bound them, they don't
shrink them.

**No limit on how many bucket-list items exist — honor system** (decided 2026-09-30 by
valevasqc). The per-item cap is the only server-side limit; someone could create many maxed-out
items and complete each one. Accepted as a self-reward feature. Deleting a completed item does
take its reward back, so you can't keep a reward and reuse the slot.

## Auth

Firebase Auth: email/password sign-up + login, Google Sign-In, password reset (Firebase's
built-in flow), session persistence. Sign-up collects name, username, email and password.

Defaults for the fiddly edge cases, there to save time rather than settle anything:

- **Email verification: in scope, but the first thing to cut** if the sprint runs short. Send
  Firebase's verification email on sign-up and show a dismissible "verify your email" banner
  with a resend action. It does **not** gate anything.
- **Sign-up/profile validation** lives in `lib/utils/validators.dart`, checked in the app before
  the Firebase call (Firebase's own error is still shown if it rejects anyway). Username 3–20
  characters `[A-Za-z0-9_]`, email format, **password 8+ characters with a letter and a number**
  (changed 2026-11-05; Firebase itself still accepts 6), name ≤ 50, pet name ≤ 20.
- **Google Sign-In has no username**, so a Google sign-up is two steps: authenticate, then a
  username picker (`choose_username_screen.dart`) before landing in the app. Pre-fill it with a
  suggestion from the email's local part (`valeriaxvasquez@…` → `valeriaxvasquez`), sanitized to
  letters/digits/underscores, with digits appended if taken — **only** a suggestion, with the
  same live availability check as the email/password path.
- **Same email, two methods: link the accounts** rather than turn the user away:
  - *Signed up with password, now signing in with Google:* Firebase throws
    `account-exists-with-different-credential`. Ask for their existing password, sign in with it,
    then `linkWithCredential(googleCredential)`.
  - *Signed up with Google, now registering with email/password:* Firebase throws
    `email-already-in-use`. Have them sign in with Google, then attach a password via
    `linkWithCredential(EmailAuthProvider.credential(...))` in account settings.

  Linking means **one** account, one uid, one user doc, one username, so the user's pet and
  history aren't stranded behind the wrong sign-in button. Both paths must end signed in.
- **Usernames must be unique** (decided 2026-09-16) via the `/usernames` index; see below.
- **Account deletion** is the `deleteAccount` function (#12); Firestore doesn't cascade deletes.
- **Onboarding** is the sign-up → name-your-pet screens (then the intro cards). There is no
  stored "onboarding completed" flag.
- **Route guards** (`lib/main.dart`, `_SignedInOnly`): `/home` and `/finish-signup` need a
  signed-in user (otherwise Login); an unknown address goes to Home or Login. At startup and
  after Login, an account that has not finished sign-up (no claimed username, or a claimed one
  with an empty profile) goes to `/finish-signup` (`isSignUpComplete` in
  `lib/utils/account_setup.dart`). A session that ends on its own while the app is open
  (`AuthRepository.sessionLost`, handled in `NoriApp`) returns to Login with a message.

### Username uniqueness

Firestore has no unique-field constraint. Uniqueness comes from making the username the
**document ID** of a dedicated collection (`/usernames/{usernameLower}`, fields `uid`,
`username`, `createdAt`), since a create fails if the document already exists — atomically, so
two people racing for the same name can't both win. Rules: see "Security rules".

- The doc ID is the username **lowercased**, so `Valeria` and `valeria` collide as they should.
  The display casing lives in `users/{uid}.username`.
- **No Cloud Function needed.** Claiming is a plain client write that either succeeds or throws.
- **The user picks their username at account creation**, checked live as they type; the submit
  button is blocked on a taken name.
- **Claiming still happens a moment after the account exists**, because Firestore rules require
  an authenticated user and the auth `onCreate` trigger can't see form fields. Order: validate
  on the form → create the auth account → immediately, in one client transaction, create
  `/usernames/{lower}` and set `users/{uid}.username`. The race window is sub-second; if someone
  does take the name in between, keep the account and re-prompt rather than rolling back.
- **Changing a username** is a transaction: create the new index doc, delete the old one, update
  `users/{uid}.username`. If the create fails, abort and keep the old name.
- **Availability check needs an unauthenticated read**, because the user is still on the sign-up
  form. Anyone can test whether a username is taken; every app with usernames leaks this.
- Edge case: account created, claim lost the race, app closed before re-picking → a user doc with
  no username; or the claim landed but the profile save did not → a claimed name on an empty
  profile. Startup and Login send such an account to `/finish-signup` (`FinishSignUpScreen`:
  username, profile, pet name; an already-claimed name is kept). If the check itself can't be made it counts as claimed, so a read
  failure never locks out a fine account.

## Pet, inventory & shop rules

Defaults, mostly describing what the mock already does:

- **Decay** is 1 point/hour per stat (was 2 until 2026-11-07), clamped 0–100. It's
  applied lazily whenever the pet is read or acted on, so no scheduled function is needed.
  (`petCareCheck` only reads the decayed value to raise a notification.)
- **Tapping Feed/Groom/Play with zero of that item left** does nothing and reports failure:
  `consumeCareItem` returns `false`. It must not throw, let the count go negative, or restore the
  stat "for free".
- **Care actions are one transaction**: apply decay, consume the item, restore the stat together.
- **Buying something already owned** is rejected server-side.
- **No cap on care-item counts**; restore amounts and prices come from `care_item_catalog.dart`.

## Local dev

Valeria's side develops and tests directly against the live `nori-pet` project, not the emulator,
using a disposable test account (credentials in the gitignored `TEST_ACCOUNT.local.md`; the one to
use is `demo@test.com`). Test documents are deleted afterward via `firebase firestore:delete`.
Reasoning: a 2-person course project with no real users, no Java runtime locally, and the
emulator's benefits matter little at this scale. `firebase.json` has an `emulators` block from
Jimena's branch that Valeria's side doesn't use; Jimena can use either approach.

**Seed script: `functions/src/seedHistory.ts`** (planning logic in `seedPlan.ts`, tested in
`seedPlan.test.ts`). It needs the Firebase Admin SDK because `firestore.rules` deny a plain
client from writing `claimed: true`/`awardedXp`/`awardedCoins`. It seeds past days for an
account's *existing* habits (create them in the app first), with the same odds as the mock
generator, and pays each claim through the server's own `computeReward`/`applyXpDelta`/
`syncPetStage`, plus the sunglasses gift; logs and rewards are written in the same transaction.
It skips today, vacation days, archived days, days outside a habit's start/end window, and days
that already have a log, so re-running is safe. About one whole day in eight stays empty
(`--off-days`, default 0.12; decided by valevasqc: no perfect streak). It moves each seeded
habit's `createdAt` back to its first seeded day, since the app hides days before `createdAt`.
Day keys use the machine's time zone (`TZ=…` to override). Not exported from `index.ts`, so it
never deploys. Run from `functions/` after a one-time `gcloud auth application-default login`:

```
npm run build && node lib/seedHistory.js --uid <uid> --days 30          # dry run, prints the plan
npm run build && node lib/seedHistory.js --uid <uid> --days 30 --apply  # writes to nori-pet
```

**Demo account reset: `resetDemoAccount`** (`functions/src/resetDemoAccount.ts`). A dev-only
callable behind Settings → Developer → "Reset demo account", so the bucket-list evolution flow
can be re-tested without scripts. It takes back every bucket-list payout (XP, coins, completed
state — the stored `awardedXp`/`awardedCoins`, like `deleteBucketListItem`), drops the level and
pet stage that XP had earned, and clears the `notificationState` level/evolved flags plus the old
level-up / evolved notifications so they fire again. It then tops the account up to its test
baseline (`functions/src/demoBaseline.ts`): every care item at least 3 (food, cake, shampoo, hair
brush, plushie, blanket) and at least 500 coins, floors only, never lowering anything. The local
`seedHistory` script applies the same top-up after seeding. Habits, logs, accessories and
achievements are untouched. It rejects any caller whose verified token email isn't `demo@test.com`; the Settings
row also hides itself for everyone else, but that is cosmetic. **Deployed 2026-11-07** (in
`firebase functions:list`; answers a CORS preflight with 204), **without the baseline top-up, which
needs a redeploy of `resetDemoAccount`**. Its callable behaviour has not yet been exercised from the Settings button.

## GCP sprint status

Done: Firebase project, Blaze plan, the 11 product Cloud Functions plus the dev-only `resetDemoAccount` and `firestore.rules`
deployed to the live `nori-pet` project (latest deploy 2026-11-07, confirmed via `firebase
functions:list`). Left: CI/CD básico, and a release APK build (never run; it would also confirm
`--tree-shake-icons` doesn't break the icon/color registries).

**One shared `functions/` folder, always deploy from it.** The two branches once had separate
`functions/` folders, and a `firebase deploy` from either one deleted the other's live functions
(it happened once, to `onUserCreate`; see RESOLVED_LOG.md, 2026-09-28). They were merged.

**Cost** (checked 2026-10-26): a $5/month budget ("Firebase Project nori-pet") alerts at
50/90/100%; `gcf-artifacts` has Firebase's 3-day cleanup policy (~0.56 GB, a cent or less a month
over the 0.5 GB free tier); the last 30 days peaked at ~1.2k Firestore reads/day (free tier 50k)
and a few hundred writes total. `petCareCheck` is the only cost that grows with users unprompted.

Google Sign-In's console configuration (provider, OAuth client, SHA-1 fingerprints for the
Android build) sits in this sprint by category but belongs to **Jimena**, since it's inseparable
from implementing the sign-in itself.

## Division of labor

Split by feature vertical — each person owns their vertical's schema/rules, CRUD repository code,
and Cloud Functions across all three phases. The split was a judgment call, not a measured
estimate; rebalance it if real progress gives a better read (achievements and bucket list are
the easiest to move).

- **Valeria — Core habit loop.** Habit CRUD + progress logging, `claimHabit` / `unclaimHabit`
  (incl. XP/level-up math and the `pet.stage` write — see the seam note below), streaks, vacation
  mode, archive/delete, notifications, account deletion.
- **Jimena — Account & virtual pet.** The whole auth stack (sign-up/login, Google Sign-In
  including its console setup, account linking, password reset, session, email verification,
  username uniqueness), onboarding, profile/account settings, pet stats/care/decay, inventory,
  the shop and bucket-list Cloud Functions (`purchaseCareItem`, `purchaseAccessory`,
  `completeBucketListItem`, `uncompleteBucketListItem`, `deleteBucketListItem`), plus bucket list
  and achievements.

**The seam between the two verticals is kept deliberately small.** `claimHabit`/`unclaimHabit` is
one atomic transaction, so Valeria writes the whole thing, including the two places it reaches
into Jimena's data:
1. `pet.stage`, when the user's level crosses `pet.evolutionLevelThreshold`. (The bucket-list
   functions also move the level, so they call the same `syncPetStage` helper from
   `functions/src/habitTransaction.ts`.)
2. `inventory.ownedAccessoryIds` + `equippedAccessoryId`, for the one-time sunglasses gift.

Both only need the field *shapes* agreed upfront (fixed by the schema above). Jimena still owns
everything else about the pet and inventory: stat values, care actions, decay, purchases,
equip/unequip, and the threshold values.

## Explicit non-goals this phase

Matches FEATURES.md's MVP boundary — don't build backend for: friends/social, activity feed,
leaderboards, competitions, proof uploads (the Social tab runs entirely on `MockSocialRepository`,
and picked photos live in memory only — KNOWN_ISSUES.md). Also not this phase: push
notifications/FCM (the in-app feed exists; phone notifications are still open in
OPEN_DECISIONS.md), Apple Health/Fitbit/Duolingo integrations and health wearables (FEATURES.md
§12), analytics, store listing. Streak and achievement notifications stay client-side until those
calculations are ported to the server.
