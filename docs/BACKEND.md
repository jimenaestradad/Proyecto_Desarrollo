# Nori — Backend Plan (Firebase)

Decided 2026-09-16: **Firebase Auth + Cloud Firestore + Cloud Functions (Node.js/TypeScript)**.
This doc is the technical plan spanning the **Backend, Data, and GCP** phases in
[ROADMAP.md](ROADMAP.md) — the course's own three-way sprint split, not something this doc
invents. What gets built, in what shape, in what order, and by whom. It does not reopen
product/scope questions;
[FEATURES.md](FEATURES.md) stays the source of truth for *what* the app does, and
[OPEN_DECISIONS.md](OPEN_DECISIONS.md) stays the source of truth for unresolved game-balance
numbers (XP curve, adaptive-XP formula, cadence multipliers, shop prices, etc). Backend
implements whatever placeholder math already exists in the mock repos (`lib/data/*.dart`) —
it does not invent new balance numbers.

## Starting point

The frontend was deliberately built against a repository-interface seam
(`lib/data/app_data.dart`): every screen depends on abstract repositories
(`HabitRepository`, `PetRepository`, `UserRepository`, `InventoryRepository`, ...), each
currently backed by an in-memory `Mock*` implementation. Backend work means writing real
implementations of those same interfaces, not redesigning how screens talk to data.

Also already in place: a Firebase project (`nori-pet`), registered for Android + web
(`firebase_options.dart`, `firebase.json`), with `firebase_core` in `pubspec.yaml`. Nothing
else — no Firestore/Auth/Functions SDKs, no `firestore.rules`, no `functions/` directory.

## How this maps to the course's Backend / Data / GCP sprints

The ClickUp backlog PDF (a crude first-pass draft, written to have *something* to turn in early
— not a committed plan) tags most tasks `2. backend`, which is part of why the plan below first
read as backend-heavy: that draft lumped Auth, every Cloud Function, *and* all the plain
Firestore read/write code into one bucket. Splitting by actual technical layer instead gives
three sprints that are each substantial on their own, not one dumping ground plus two thin ones:

- **Data phase** — Firestore schema + security rules + indexes, **and** the persistence layer
  itself: the direct-write repository implementations (`Firestore*Repository` classes doing
  plain CRUD — habit create/update/reorder, progress logging, pet care actions, inventory
  equip, profile edits, bucket list, achievements), plus seed/migration scripts. This is real,
  substantial code, not just an upfront design doc — it's "how the app talks to its own
  database."
- **Backend phase** — narrower than the draft implied: Firebase Auth wiring (sign up/login,
  Google Sign-In, password reset, session persistence) + the Cloud Functions that enforce
  currency/business rules (`claimHabit`, `unclaimHabit`,
  `purchaseCareItem`, `purchaseAccessory`, `onUserCreate`) + the client-side calling code for
  those. This is specifically the business-logic/orchestration layer, not "everything that
  isn't UI."
- **GCP phase** — Firebase/GCP project + console config, environment/secrets, CI/CD, deploying
  Cloud Functions/rules to the live project, cost awareness.

The rule from the architecture table below (Cloud Functions guard the two currencies) still
decides *what* each piece of logic does — this section just reassigns *which sprint* builds it:
plain reads/writes → Data, currency-affecting logic + Auth → Backend, config/deploy → GCP.

## Architecture: what's a Cloud Function vs. a direct client write

**Rule of thumb: Cloud Functions guard the two currencies (XP, coins) and anything derived
from them (level, evolution stage). Everything else is a direct, rules-guarded client write.**
This is the "moderate" option — not full server-authoritative, not fully client-trusted — chosen
to keep the Cloud Functions surface small enough for a 2-person team on a semester timeline,
while closing the one real cheat vector (a client overwriting its own XP/coins field).

| Operation | How | Sprint | Why |
|---|---|---|---|
| Habit create/update/delete/reorder | Direct client write | Data | No currency involved |
| `logProgress` / `setProgress` (non-claiming) | Direct client write | Data | FEATURES.md §3: logging progress alone never earns XP |
| `claimHabit` / `unclaimHabit` (today or a past date) | **Cloud Function (callable)** | Backend | Mints/burns XP + coins, must update habit + user + pet atomically |
| Feed / groom / play (+ stat decay) | Direct client write (client-side transaction) | Data | Spends an already-owned consumable for a pet stat, not currency; pet "cannot die" so stakes are low |
| Spending the care item | Direct client write, same transaction as above (`PetRepository.useCareItem` reads and writes `pet/main` + `inventory/main` together since 2026-10-06; they were two transactions before) | Data | Same reasoning |
| Buying a care item or accessory from the shop | **Cloud Function (callable)** | Backend | Spends coins to mint an owned item — currency-affecting |
| Equip/unequip an already-owned accessory | Direct client write | Data | No currency involved |
| Profile edit, vacation mode toggle | Direct client write | Data | No currency involved |
| First-user provisioning (user doc, starter pet, starter care items) | **Cloud Function (`onCreate` auth trigger)** | Backend | Grants starting resources |
| Onboarding answer (pet name) | Direct client write, after sign-up | Data | An auth trigger can't see it — it's typed on a later screen, and it isn't currency |
| One-time sunglasses gift on first habit completion | **Inside the `claimHabit` Cloud Function** | Backend | Grants an item; must be atomic with the claim that triggers it |

## Firestore schema

All per-user data lives under `/users/{uid}`, secured by `request.auth.uid == uid`. No
cross-user queries exist yet (friends/social is vision-only, not built — see FEATURES.md §10),
so there's no need for top-level collections keyed by `userId`. The **one** exception is the
`/usernames` index, which has to be global precisely because it enforces uniqueness *across*
users — see "Username uniqueness" below.

```
/users/{uid}                        profile + progression (single doc)
  name, username, email, avatarUrl, createdAt
  level, totalXp, xpIntoLevel, xpForNextLevel, coins
  vacationModeEnabled, vacationRanges: [{start, end}]   # small + always read with the user; array is fine
  # Resolved 2026-09-23: a currently-open freeze is the last array entry with
  # end == null; vacationModeEnabled mirrors that as a quick boolean so a
  # settings toggle doesn't need to parse the array to render itself. See
  # FirestoreVacationLog in lib/data/vacation_log.dart.
  habitCategories: [string]         # user-editable via Settings — NOT a static catalog, see below
  firstHabitCompletedAt: Timestamp? # null until first claim; gates the one-time sunglasses gift
  # NOTE: currentStreak is deliberately NOT stored — see "Derived, never stored" below

/users/{uid}/habits/{habitId}      # a pure definition — no day-specific state, see below
  name, subtitle, iconKey (string), colorKey (string),   # see "Serialization" below — never store codePoints
  xpReward, coinReward, repeat, type, difficulty,        # enums stored as .name strings
  targetValue, unit, minThreshold,
  quickLogAmount, adaptiveMultiplier, customDays, allowVacationFreeze,
  startDate, endDate, order, archived (bool, default false — see deletion rule),
  archivedRanges ([{start, end}] dayKeys — see "Deleting vs. archiving a habit"),
  createdAt   # implicit lower bound for isScheduledOn — see "Resolved 2026-09-24" below
  # Resolved 2026-09-24 (supersedes the original plan): currentValue,
  # isCompletedToday, lastAwardedXp, lastAwardedCoins do NOT live here.
  # The original plan stored "today's" values directly on the habit doc,
  # which turned out to have no way to roll over at midnight — see
  # docs/KNOWN_ISSUES.md's 2026-09-23 entry for the bug this caused. Fixed
  # by moving that state into habitLogs for *every* day, today included, so
  # there's nothing on the habit doc that needs resetting when the date
  # changes. A day's Habit is now always built by reading the definition +
  # that day's habitLogs entry and merging them (Habit.hydrate) — never by
  # reading stored "current" fields.

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
```

**The pet is a collection with one document, not a field on the user.** That's deliberate:
FEATURES.md §7's multi-pet vision (max a pet out, buy an egg, hatch another) becomes additional
documents in `pet/` plus an `activePetId` on the user doc — no migration, no reshaping of
existing data. Don't build any of that now; just don't collapse the pet into the user doc and
foreclose it.

**There is no `achievements` collection, on purpose.** `achievement_repository.dart` computes
every achievement's unlocked state on the fly from habits, calendar history, bucket list, pet
and inventory — nothing is stored. Keep it that way: the real implementation just reads the
other repositories, exactly like the mock does. Don't create a collection for it.

**Why `habitLogs` is a flat collection, not a subcollection per habit:** the calendar/history
views need a range query across *all* habits for a month (`date >= X && date <= Y`), which a
per-habit subcollection would turn into a fan-out query per habit. A flat collection with a
`date` field supports that directly. This mirrors what the mock code already anticipates —
`habit_history_store.dart`'s own comment says a real backend replaces it with "a `habit_logs`
table keyed by (habit id, date)."

**Static content catalogs** — `care_item_catalog.dart`, `accessory_catalog.dart`, and the
achievement *definitions* stay bundled Dart constants, same as today; nothing requires updating
them without an app release. Their string ids (`'food'`, `'cake'`, `'shampoo'`, `'hair-brush'`,
`'plushie'`, `'blanket'`; `'flower-crown'`, `'sunglasses'`, …) are already stable and are what
Firestore stores.

**`habit_category_repository.dart` is NOT one of those.** Categories are user-editable from
Settings (add/rename/delete), so they're user data and need persisting — hence
`habitCategories` on the user doc above. Renaming a category deliberately does **not** cascade
to habits already using it (habits keep their `subtitle` text); preserve that behavior.

## Conventions — shared defaults

These are the questions a Firestore implementation forces someone to answer. They're answered
here so nobody has to stop and work them out mid-task.

Most of them need to *match* across both verticals — if one side stores enums as strings and the
other as ints, or one side switches to streams, the app stops agreeing with itself. That's the
reason to keep them in step, not the fact that they're written down. If a better answer turns up
while building, change it here so the other half follows.

**Keep `Future`, do not switch to `Stream`.** Every repository method today returns a `Future`
and screens call them from `initState`/button handlers with `setState`. Firestore's `snapshots()`
is tempting but converting even one repository to streams means rewriting that screen's state
management. Use `.get()` / `.set()` / `.update()`. Live-updating UI is not an MVP requirement.

**Icons: use a string-key registry, never store `codePoint`.** `Habit.icon` and
`BucketListItem.icon` are `IconData`. Build one `Map<String, IconData>` registry (suggested:
`lib/data/icon_registry.dart`) keyed by the Material icon name (`'water_drop'`,
`'fitness_center'`, `'menu_book'`, …) and store that key. Reconstructing `IconData(codePoint,
fontFamily: 'MaterialIcons')` from a stored int **looks fine in debug and renders blank boxes in
the release APK** — Flutter's `--tree-shake-icons` (on by default for release builds) strips any
icon not referenced as a constant. Unknown key on read → fall back to a default icon, don't crash.

**Colors: store the palette key, not an int.** `Habit.color` values come from `AppColors`
(`'sky'`, `'mossLight'`, `'blushPink'`, `'mustardLight'`, `'blush'`, `'linenAlt'`, …). Store the
field name as a string and resolve it through a registry the same way, so a palette tweak
doesn't strand old rows on stale hex values. Unknown key → fall back to a default.

**Enums: store `.name`** (`'daily'`, `'quantity'`, `'hard'`, `'baby'`), not index ints — index
order changes silently when someone adds an enum value; names don't. Unknown value on read →
fall back to the current default (`HabitRepeat.daily`, `HabitDifficulty.medium`, …).

**Dates and the day-rollover rule.** `dayKey()` in `habit_history_store.dart` already produces
the canonical `yyyy-mm-dd` key in **device-local** time. The client computes it and passes it
explicitly to every Cloud Function call. **Cloud Functions must never derive the day themselves**
— server time is UTC, so a claim at 9pm local would file under tomorrow for some users. Store
both `dayKey` (string, used in the doc id, what claim/unclaim look up) and `date` (Timestamp at
local midnight, used only for calendar range queries). The wider timezone question (user travels,
DST) stays open in OPEN_DECISIONS.md — this rule is enough for MVP and avoids the obvious bug.

**Derived, never stored.** Two values are computed on read today and must stay that way, because
a stored copy already went stale once (see the comment in `user_repository.dart`):
- `currentStreak` — derived from habit history via `CalendarRepository`.
- achievement unlock state — derived from the other repositories, as above.

**Balance numbers are still open**, so porting the mock's behavior as-is is the safe move —
filling the gaps in passing means the eventual real answer has to be un-picked from the code.
OPEN_DECISIONS.md tracks what's genuinely unresolved. The level curve is the one that *has* been
settled — see below.
- `adaptiveMultiplier` is **computed by `claimHabit` on every claim** since 2026-10-06
  (`functions/src/adaptiveXp.ts`) from the habit's last 14 days, within per-difficulty caps, and
  stored on the habit doc only so the app can preview the next reward. The client never writes
  it (`FirestoreHabitRepository._definitionFields` leaves it out). Rule and numbers:
  OPEN_DECISIONS.md "XP balancing".
- Claims pay `full` (1.0×) or `none` — no partial tier since 2026-09-28: the minimum threshold
  keeps streaks but pays nothing (FEATURES.md §3). The Dart mock's `HabitRewardTier.min` (0.75×)
  is a leftover, see KNOWN_ISSUES.md.
- Care-item restore amounts and prices come from `care_item_catalog.dart` as-is.

**XP curve: `xpForNextLevel = 100 × currentLevel`** (decided 2026-09-16; supersedes the mock's
flat value, which was unfinished rather than intentional). Level 1→2 costs 100, 2→3 costs 200,
6→7 costs 600. Cumulative XP to *reach* level n is `50 × n × (n − 1)`.

Only the Cloud Function needs this formula. It writes `level`, `xpIntoLevel` and
`xpForNextLevel` to the user doc, and the client just displays the stored values — so the curve
lives in exactly one place and the two languages can't drift apart. Don't reimplement it in Dart.

**In-app notifications (2026-10-21).** In-app only, no push. The feed lives at
`/users/{uid}/notifications/{id}` (`kind`, `message`, `createdAt`, `isRead`), and
`/users/{uid}/notificationState/main` records what has already been notified so nothing repeats.
Whoever can see the event writes the notification, in the same transaction as the event when there
is one:

| Kind | Written by | When |
|---|---|---|
| `levelUp`, `petEvolved`, `gift` | `claimHabit`, `completeBucketListItem` (`functions/src/notifications.ts`) | The reward crosses a level, evolves the pet, or grants the first-completion gift |
| `petCare` | `petCareCheck`, a scheduled function that runs every hour | A pet vital (after lazy decay) is below 30, at most once per 24h |
| `achievement`, `streak` | The app (`FirestoreNotificationRepository`), when Notifications opens | A new unlocked achievement, or the streak reaches 3/7/14/30/60/100/180/365 |

Things to know:
- **Streaks and achievements stay on the client** because only the client computes them today
  (the streak is derived and never stored; achievements come from `MockAchievementRepository`).
  Moving them means porting those calculations to the server first. Until then they appear
  when Notifications is opened, timestamped then, and the rules only let the client create those
  two kinds.
- **No duplicates.** Level and evolution ratchet in `notificationState` (server-only fields
  `level`, `petEvolved`, `petCareAt`), so unclaiming and re-claiming doesn't repeat them.
  Achievements ratchet too. The streak milestone resets when the streak breaks, but not on the
  same day. The client's first sync only records a baseline, so an existing account isn't
  flooded.
- **Unread dot.** The bell on Habits listens to a `limit(1)` unread query, so server-written
  notifications show up live.
- **Icon, label and color come from `kind`** on the client, so restyling doesn't need a
  migration.
- **Cost.** `petCareCheck` reads every pet once an hour (24 reads per user per day), which is
  fine at this scale. `PET_DECAY_PER_HOUR` in `notifications.ts` must match
  `FirestorePetRepository._decayPerHour`.

**Mocks stay until their replacement works.** Swap one repository at a time in `app_data.dart`
(that's the only file that decides mock vs. real). Don't delete the `Mock*` classes — they're
the fallback if a Firestore path misbehaves during the demo, and they document intended
behavior.

**Online only — no offline mode.** Decided 2026-09-16: the app requires connectivity, and
building offline support is explicitly out of scope. What this means in practice:

- Every action that hits Firestore or a Cloud Function can fail. Surface a plain error ("Couldn't
  reach the server — try again") and leave the UI in its previous state. No optimistic updates
  that need rolling back, no retry queues, no sync layer.
- **Turn Firestore's offline persistence off** (`persistenceEnabled: false` in
  `FirebaseFirestore.instance.settings`). It's on by default on mobile, and leaving it on gives
  the worst of both worlds: Cloud Function calls fail instantly offline while direct writes
  silently queue, so half the app appears to work and half doesn't. Off means everything fails
  the same way, which is far easier to reason about and to demo.
- Give network calls a timeout so nothing can hang on a spinner forever.
- One shared helper for "call, catch, show error" is enough — this shouldn't become a
  per-screen pattern.

## When something isn't specified here

**Calls inside your own vertical are yours to make.** Whoever is building a piece ends up
knowing it better than whoever sketched it in advance, so the defaults in this doc are a
starting point, not a verdict — if something here turns out to be wrong or awkward once you're
in the code, change it.

The one thing worth doing consistently is **writing the answer down** — in this doc or
OPEN_DECISIONS.md — rather than leaving it only in the code. Two people, or two AI sessions,
can each make a perfectly reasonable call in different directions and only find out weeks later
that the halves don't fit. A line in the doc costs nothing next to reconciling that.

Worth a quick conversation before changing, because it lands on someone else's work: anything
that crosses the seam between the two verticals (see Division of labor), changes a number or
rule the user actually sees, or contradicts FEATURES.md.

## New-account provisioning — decided 2026-09-16

These are the values `onUserCreate` writes. Worth flagging because the obvious reference point —
the demo user (level 5, 7220 XP, 340 coins) — is screenshot dressing, not a starting state.

| What | Value |
|---|---|
| Level / XP | `level: 1`, `totalXp: 0`, `xpIntoLevel: 0`, `xpForNextLevel: 100` (the curve's first step — see "XP curve" below) |
| Coins | `0` — the starter care items below cover the first care actions, so no float is needed |
| Care items | `{food: 3, shampoo: 2, plushie: 1}` |
| Accessories | **None.** `ownedAccessoryIds: []`, `equippedAccessoryId: null` — the mock's pre-owned `sunglasses` is a demo artifact; see the first-completion gift below |
| Pet stats | `hunger/hygiene/happiness: 100`, `stage: baby`, `lastDecayAt: now`, `evolutionLevelThreshold: 7` — now a real balance decision (FEATURES.md §6), no longer the old placeholder |
| Pet name | Chosen by the user during onboarding — see the sequencing note below |
| First-completion flag | `firstHabitCompletedAt: null` — see the gift rule below |

**The sunglasses are the one and only free accessory, granted on the user's first habit
completion** — not at sign-up, and never again for anything else. Every other accessory is
bought with coins.

- **Where it lives:** inside the `claimHabit` transaction (Valeria's
  vertical). If `firstHabitCompletedAt` is null, the same transaction adds `'sunglasses'` to
  `ownedAccessoryIds`, sets `equippedAccessoryId` to it, and stamps `firstHabitCompletedAt`.
- **It is deliberately one-way.** Un-claiming that first habit reverses XP and coins exactly, as
  always, but does **not** take the accessory back or clear `firstHabitCompletedAt` — a gift
  that appears and vanishes while the user toggles a checkbox is worse than a tiny
  inconsistency. This is the only intentional exception to "unclaim reverses everything."
- Until then the pet simply renders with no accessory equipped.

**Pet naming changes the `onUserCreate` sequence.** A Firebase Auth `onCreate` trigger only
receives the auth record — it cannot know a name the user types on a later onboarding screen.
So: `onUserCreate` provisions the pet with the name `'Nori'`, and the onboarding screen writes
the chosen name afterward as a **direct client write** to `pet/main` (a pet's name isn't
currency, so it needs no Cloud Function). If the user skips onboarding, the name simply stays
`'Nori'`. Don't try to pass the name into the auth trigger; it isn't possible.

**Deleting vs. archiving a habit** (decided 2026-09-30 by valevasqc; replaces the 2026-09-16
"deleting always archives" rule).
- **Archive** works for any habit. It hides the habit from today onward and keeps every
  `habitLogs` document, because past streaks, calendar days and achievements are derived from
  them. Archived habits are listed on the Archived Habits screen (reached from the Habits header)
  and can be **restored**. Stored as `archived` (is it archived right now, used for that list)
  plus `archivedRanges`, the stretches it was archived as `{start, end}` device-local dayKeys.
  `end` is exclusive (the restore day counts again) and null while it's still archived.
  `Habit.isActiveOn` treats a day inside a stretch like a day past `endDate`: the habit isn't
  scheduled, so the stretch never reads as missed after a restore, and the days before the
  archive keep their history. `claimHabit` enforces the same rule via `isArchivedOn`.
  Past-day reads (`FirestoreHabitRepository.fetchAllDefinitions`, the calendar) use every
  definition and let `isActiveOn` decide per day. Filtering archived habits out up front would
  erase them from history.
- **Delete** is only offered for a habit with almost no history: at most
  `kMaxDeletableActiveDays` (2) days with any logged progress or a claim. The threshold is a
  default from this decision, so change it in both `habit_repository.dart` and
  `functions/src/deleteHabit.ts` if it's wrong. Delete goes through the `deleteHabit` Cloud
  Function: it removes the habit and all its logs and takes back whatever those claims paid
  (exact stored amounts, including days later unclaimed, rejected if those coins were already spent, `pet.stage` re-synced, the sunglasses gift kept),
  all in one transaction. The client can never delete a habit doc directly.
- **Hard delete of a habit with real history is deferred**: whether its earned XP/coins
  should stay or be taken back is undecided. See OPEN_DECISIONS.md.

## Security rules (sketch)

- Default deny everywhere.
- `/users/{uid}` and everything under it: read/write only if `request.auth.uid == uid`.
- On the user doc: clients may write profile fields + `vacationModeEnabled`/`vacationRanges`.
  `level`, `totalXp`, `xpIntoLevel`, `xpForNextLevel`, `coins` are **denied to client writes** —
  only reachable via Cloud Functions, which use the Admin SDK and bypass rules entirely.
- On habit docs and `habitLogs` docs: clients may write everything except
  `isCompletedToday` / `lastAwardedXp` / `lastAwardedCoins` (habit) and
  `claimed` / `awardedXp` / `awardedCoins` (log) — same split, enforced the same way.
- `pet/main`: clients may write `name`, `hunger`, `hygiene`, `happiness`, `lastDecayAt`.
  `stage` and `evolutionLevelThreshold` are **denied to client writes** — otherwise a client
  could set its own evolution stage directly, which is exactly the currency-adjacent write the
  Cloud-Functions boundary exists to prevent. Only `claimHabit`'s transaction (Admin SDK) touches
  them.
- `inventory/main` needs two different rules on the same document, because `consumeCareItem` and
  a purchase both write `careItemCounts`/`ownedAccessoryIds`, but only one of them should be able
  to grant something new:
  - `careItemCounts`: a client write may only **decrease** any of the known item ids (`food`,
    `cake`, `shampoo`, `hair-brush`, `plushie`, `blanket` — the catalog is small and closed, so
    checking each by name is practical) and may not add a new key. This is what lets
    `consumeCareItem` stay a direct write while `purchaseCareItem` stays the only way to
    *increase* a count.
  - `ownedAccessoryIds`: a client write must satisfy
    `request.resource.data.ownedAccessoryIds.hasOnly(resource.data.ownedAccessoryIds)` — every
    id in the new list must already be in the old list, so a client can never add an accessory
    it doesn't own. Only `purchaseAccessory` and the sunglasses gift inside `claimHabit` add ids.
  - `equippedAccessoryId`: a client write must be `null` or already present in
    `resource.data.ownedAccessoryIds` — equip-only-what-you-own, enforced server-side rather
    than just by the UI hiding the option.

  Without these, the earlier statement that "the client cannot grant itself items by writing
  Firestore directly" would be false — a blanket "pet/inventory are client-writable" rule
  contradicts the Cloud-Functions boundary this whole doc is built around. This is the one real
  hole a review caught (2026-09-16): everywhere else already had this field-level split, this
  section just hadn't been written to match.
- `/usernames/{usernameLower}`: the one global collection. Public `read` (availability check
  happens before an account exists), `create` only when authenticated and the payload's `uid`
  matches the caller, `delete` only by the owning uid, `update` never. The atomicity of
  "create fails if it already exists" is what enforces uniqueness — see "Username uniqueness".

## Cloud Functions (concrete list — keep this short)

1. `onUserCreate` (Auth trigger) — provisions `/users/{uid}`, starter pet, starter inventory.
   The pet name doesn't go through this function — an auth trigger only sees the auth record,
   not a value typed on a later onboarding screen. It's a direct client write after sign-up
   instead; see the provisioning table below.
2. `claimHabit({habitId, dayKey, dayStartMillis})` — computes the claim value + reward tier,
   writes habitLog + user (XP/coins/level) + pet (evolution sync) + inventory (first-completion
   gift) in one transaction. **Implemented 2026-09-24** (`functions/src/claimHabit.ts`, pure
   math in `functions/src/rewards.ts`). Calls made while building it:
   - **Day args are required, not optional.** `dayKey` is the client's device-local
     `yyyy-mm-dd`; `dayStartMillis` is that day's local midnight (becomes the log's `date`).
     The server checks they agree (within ±14h, the UTC-offset range) and rejects future days
     and days before the habit's `createdAt`.
   - **Base XP/coins come from `difficulty`, not the habit doc's `xpReward`/`coinReward`.**
     `firestore.rules` lets clients edit those two fields, so trusting them would let anyone
     mint arbitrary XP. The add-habit screen already writes exactly `difficulty.baseXp`/
     `baseCoins`, so real habits see no change. The stored `adaptiveMultiplier` is ignored
     for the same reason: since 2026-10-06 `claimHabit` recomputes it from the last 14 days'
     logs (read with `getAll` on their known doc ids, so no index is needed) and writes the new
     value back in the same transaction.
   - **Level math uses `applyXpDelta` from `functions/src/xpCurve.ts`** — the single shared
     curve implementation, also used by the bucket-list functions (merged 2026-09-28; an
     earlier separate `levelStateForTotalXp` was removed so the curve lives in one place).
     Handles multi-level jumps both ways; claim → unclaim → claim lands on the identical level.
   - **Sunglasses gift** needs a non-`none` reward tier (a failed limit day isn't a
     "completion"), only equips if nothing is equipped yet, and is skipped (not stamped) if
     `inventory/main` doesn't exist, so it isn't lost before provisioning lands.
   - Already claimed → no-op returning `changed: false` and zero deltas. Returns `{changed,
     xpDelta, coinsDelta, previousLevel, level, previousPetStage, petStage, giftedAccessoryId}`
     so the client can fire level-up/evolution/gift celebrations without extra reads.
3. `unclaimHabit({habitId, dayKey, dayStartMillis})` — exact reversal using the log's stored
   `awardedXp`/`awardedCoins`, same atomic scope as above. **Implemented 2026-09-24**
   (`functions/src/unclaimHabit.ts`; shared refs/result type/pet sync in
   `functions/src/habitTransaction.ts`). Keeps the log's `value` (so progress stays editable),
   demotes the pet if the level drops below its threshold, never revokes the sunglasses gift.
   Not claimed → no-op. **Pay once per day (2026-10-26):** unclaim no longer reverses
   anything. It only sets `claimed: false` and keeps `awardedXp`/`awardedCoins` on the log, and
   `claimHabit` pays nothing for a log that already paid (`rewardPaid` in
   `habitTransaction.ts`). This replaced exact reversal clamped at 0, which let claim → spend →
   unclaim → re-claim mint coins. Bucket-list complete/uncomplete follow the same rule. Deletes
   (`deleteHabit`, `deleteBucketListItem`) still reverse every stored payout, and are rejected
   if those coins were already spent (`coinsAfterReversal`), so create → claim → delete can't
   mint either.
   Both functions return the same shape: `{changed, xpDelta, coinsDelta, previousLevel, level,
   previousPetStage, petStage, giftedAccessoryId}`.
4. ~~`setHabitCompleted`~~ — **removed 2026-09-28** as a duplicate endpoint: it only dispatched
   to claim/unclaim. The binary checkbox's Dart `setHabitCompleted(id, completed)` calls
   `claimHabit` or `unclaimHabit` directly instead.
5. `purchaseCareItem(itemId, quantity)` — validates cost ≤ coins, decrements coins, increments
   `careItemCounts`.
6. `purchaseAccessory(accessoryId)` — validates cost ≤ coins, decrements coins, adds to
   `ownedAccessoryIds`. Rejects an accessory the user already owns.
7. `completeBucketListItem(itemId)` — awards the item's XP/coins and **stores what it paid into
   `awardedXp`/`awardedCoins`** on the item. Syncs `pet.stage` in the same transaction, like
   `claimHabit` (added 2026-09-30: before that a bucket-list reward could cross the evolution
   level without evolving the pet, since the client can't write `stage`).
8. `uncompleteBucketListItem(itemId)` — un-marks the item but keeps what it paid (pay once,
   2026-10-26, see #3); completing it again pays nothing. Before that it reversed the stored
   values.
9. `deleteBucketListItem(itemId)` — added 2026-09-30. Deletes the item, first reversing its
   stored payout if it ever paid one (completed now or earlier), in one transaction.
   `firestore.rules` only lets the client delete an item directly while it isn't completed and
   has never paid (`awardedXp`/`awardedCoins` both 0).
10. `deleteHabit(habitId)` — added 2026-09-30 (Valeria's). Deletes a habit with at most 2
   active days plus all its logs, taking back what its claims paid, in one transaction. Rejects
   anything with more history with "archive it instead". See "Deleting vs. archiving a habit".
11. `petCareCheck` (scheduled, hourly) — added 2026-10-21 (Valeria's). Writes a "pet needs you"
   notification when a pet's decayed vital is below 30, at most once per 24h. See "In-app
   notifications". 2 and 7 also write level-up/evolution/gift notifications inside their
   transactions now.
12. `deleteAccount()` — added 2026-10-26 (Valeria's). Deletes the caller's `/usernames`
   entries, the whole `/users/{uid}` tree (`recursiveDelete`), then the Auth user. Data goes
   first so a failure leaves a signed-in user who can retry; every step is idempotent.
   Settings → Delete Account, behind typing the username. Verified live 2026-10-26 on throwaway
   accounts (Auth user and `pet/main` both gone afterwards).

That's the whole server-side surface for this phase — eleven functions, all callable except #1
(Auth trigger) and #11 (scheduled) (#4 removed, #9–#12 added). Functions 1, 5, 6, 7, 8, 9 are
Jimena's; 2, 3, 10, 11, 12 are Valeria's.

**Why 7 and 8 store what they paid:** bucket-list rewards are editable by the user at any time
(the add/edit sheet has free-text XP and coin fields). Reversing an un-completion against the
item's *current* value lets someone complete an item at 150 XP, edit it to 3000, un-complete it,
and walk away +2850 XP — not a cheat anyone would necessarily set out to find, just an
inconsistency that produces impossible totals. Habits already solved this with
`lastAwardedXp`/`lastAwardedCoins`; bucket list needs the same treatment. Same rule as always:
reverse exactly what was paid, never a recomputation.

**Bucket-list rewards are capped server-side at 500 XP / 250 coins** (decided 2026-09-16).
`completeBucketListItem` clamps whatever the item asks for before awarding it, so the free-text
fields in the add/edit sheet stay as they are and no frontend change is needed. Rationale: the
seeded 3000 XP "graduate" item would otherwise carry a brand-new user most of the way to their
first evolution in a single tap. Lower the seed data's 3000 to 500 to match. Bucket-list items
are still meant to feel much larger than a habit (10–30 XP); the cap bounds them, it doesn't
shrink them.

**No limit on how many bucket-list items exist — honor system** (decided 2026-09-30 by
valevasqc). The per-item cap above is the only server-side limit: someone could create many
maxed-out items and complete each one. That's accepted as a self-reward feature, not patched.
Deleting a completed item does take its reward back (`deleteBucketListItem`), so you can't keep
a reward and reuse the slot.

**Level-up must handle multi-level jumps.** A capped 500 XP award still crosses levels 1→3 for
a new user, so the level loop in `MockUserRepository.addXp` (a `while`, not an `if`) must be
ported as a loop — and whatever the UI does to celebrate a level-up needs to survive several
firing from one call.

## Auth

Firebase Auth: email/password sign-up + login, Google Sign-In, password reset (Firebase's
built-in flow), session persistence. Sign-up collects name, username, email and password —
the same four fields `MockAuthRepository.signUp` already takes.

Auth has more fiddly edge cases than anything else in the plan, so here's a default for each —
they're here to save time, not to settle anything you'd rather do differently once you're in it:

- **Email verification: in scope, but the first thing to cut** if the sprint runs short. Send
  Firebase's verification email on sign-up and show a dismissible "verify your email" banner
  with a resend action. It does **not** gate anything — an unverified user can still use the
  whole app. Blocking the core loop behind a verification click would wreck the demo and isn't
  worth it for a habit tracker with no sensitive data.
- **Password rules: Firebase's defaults** (6+ characters). Show Firebase's own error message
  rather than writing custom validation.
- **Google Sign-In has no username**, so a Google sign-up is two steps: authenticate with Google,
  then show a username picker before landing in the app. Pre-fill it with a suggestion derived
  from the email's local part (`valeriaxvasquez@…` → `valeriaxvasquez`), sanitized to
  letters/digits/underscores, with digits appended if it's taken — but it is **only** a
  suggestion. The user picks their own username at account creation, same as the email/password
  path, with the same live availability check.
- **Same email, two methods: link the accounts** — don't turn the user away. Both directions
  need handling, and they're different:
  - *Signed up with password, now signing in with Google:* Firebase throws
    `account-exists-with-different-credential`. Ask for their existing password, sign in with it,
    then `linkWithCredential(googleCredential)`.
  - *Signed up with Google, now registering with email/password:* Firebase throws
    `email-already-in-use`. Have them sign in with Google, then attach a password via
    `linkWithCredential(EmailAuthProvider.credential(...))` in account settings.

  Linking means **one** account, one uid, one user doc, one username — the point is to avoid a
  duplicate account that would strand the user's pet and history behind the wrong sign-in
  button. Both paths must end with the user signed in, not at a dead end.
- **Usernames must be unique** (decided 2026-09-16). Firestore can't enforce this with a field
  constraint, so it needs the `/usernames/{usernameLower}` index collection described in the
  schema section, claimed atomically. Details and the exact flow are below under "Username
  uniqueness" — this is the one part of Auth with real machinery behind it.
- **No account deletion in MVP.** Firestore doesn't cascade deletes, so a real "delete my
  account" needs a recursive subcollection wipe. Sign-out only.
- **Onboarding completion** is tracked with `onboardingCompletedAt` on the user doc — set when
  the user finishes *or* skips, so it doesn't reappear on next launch.

### Username uniqueness

Firestore has no unique-field constraint. Uniqueness comes from making the username the
**document ID** of a dedicated collection, since a create fails if the document already exists —
that failure is atomic, so two people racing for the same name can't both win.

```
/usernames/{usernameLower}     # the ONLY collection outside /users/{uid}
  uid
```

- The doc ID is the username **lowercased**, so `Valeria` and `valeria` collide as they should.
  The display casing the user typed lives in `users/{uid}.username`.
- **No Cloud Function needed.** Rules do the work: `allow create` already fails on an existing
  document, so claiming is a plain client write that either succeeds or throws.
- **The user picks their username at account creation** — it's one of the four fields on the
  sign-up form, alongside name, email and password. Check availability live as they type and
  block the submit button on a taken name, so the choice is resolved on the form, not after.
- **Claiming still happens a moment after the account exists**, because Firestore rules require
  an authenticated user and the auth `onCreate` trigger can't see form fields (same limitation
  as the pet name). Order: validate on the form → create the auth account → immediately, in one
  client transaction, create `/usernames/{lower}` and set `users/{uid}.username`. The race
  window is sub-second, so the claim effectively always succeeds; if someone does take the name
  in between, keep the account and re-prompt for a new one rather than rolling back the sign-up.
- **Changing a username** is a transaction: create the new index doc, delete the old one, update
  `users/{uid}.username`. If the create fails, abort the whole thing and keep the old name.
- **Availability check needs an unauthenticated read**, because the user is still typing on the
  sign-up form before any account exists. That means anyone can test whether a username is
  taken. Every app with usernames leaks this; it's the accepted trade.
- Rules sketch: `read` open; `create` only when authenticated and `request.resource.data.uid ==
  request.auth.uid`; `delete` only by the uid that owns it; `update` never (a change is a delete
  plus a create).

Rare edge case: account created, claim lost the race, user closes the app before re-picking.
That leaves a user doc with no username. Treat a missing username as "prompt on next launch"
rather than an error state — it shouldn't happen, but it shouldn't brick the account either.

## Pet, inventory & shop rules

Same idea — defaults so nothing stalls, most of them just describing what the mock already does:

- **Decay** is 2 points/hour per stat, clamped 0–100, ported unchanged from `MockPetRepository`.
  It's applied lazily whenever the pet is read or acted on — there is no scheduled function.
- **Tapping Feed/Groom/Play with zero of that item left** does nothing and reports failure:
  `consumeCareItem` returns `false`, exactly as it does today. It must not throw, must not let
  the count go negative, and must not restore the pet stat "for free" when there was nothing to
  consume.
- **Care actions are one transaction**: apply decay, consume the item, and restore the stat
  together, so a failure can't consume an item without restoring anything.
- **Buying something already owned** is rejected server-side, even if the UI already hides it.
- **No cap on care-item counts** — nothing in FEATURES.md calls for an inventory limit.
- **Restore amounts and prices** come from `care_item_catalog.dart` unchanged.

## Local dev

**Changed 2026-09-23 from the original plan below:** given this is a 2-person course project
(not a production app with real users or real stakes), Valeria's side has been developing and
testing directly against the live `nori-pet` project instead of the emulator — using a disposable
test account (credentials in the gitignored `TEST_ACCOUNT.local.md`; since 2026-10-05 the one to
use is `demo@test.com`, which went through the real sign-up — the older `test@nori.com` there was
made in the console before `onUserCreate` existed and has no Firestore docs), verifying each repository
method against real Firestore, then deleting the test documents afterward via
`firebase firestore:delete`. No Java runtime was available locally, and the emulator's main
value (cost control, blast-radius limits, instant resets) matters much less at this scale than the
faster iteration loop of skipping it. `firebase.json` has an `emulators` block from Jimena's branch;
Valeria's side doesn't use it. Jimena can use either approach — this isn't a hard rule, just what
happened in practice.

The seed-data script (replacing `HabitHistoryStore.seedHistory`'s demo generator) turned out to
be blocked by the same rule as claiming a habit: `firestore.rules` denies a plain client from
writing `claimed: true`/`awardedXp`/`awardedCoins` on a habit log — on purpose, since that's
exactly how someone would fake themselves free rewards — so a script running as a normal signed-in
user can only ever seed *unclaimed* progress, never a believable "completed" history. A real
version needs the Firebase Admin SDK (bypasses rules, same mechanism Cloud Functions use), which
means it belongs with the Backend-sprint Cloud Functions work, not before it.

**Written 2026-10-04: `functions/src/seedHistory.ts`** (planning logic in `seedPlan.ts`, tested in
`seedPlan.test.ts`). It seeds past days for an account's *existing* habits (create them in the app
first), with the same odds as the mock generator, and pays each claim through the server's own
`computeReward`/`applyXpDelta`/`syncPetStage`, plus the sunglasses gift. Logs and the rewards they
paid are written in the same transaction. It skips today, vacation days, archived days, days
outside a habit's start/end window, and any day that already has a log, so re-running it is safe.
It also leaves one whole day in every ~8 empty (`--off-days`, default 0.12). Without those, a
handful of habits always has *something* kept each day, and since the calendar's streak only breaks
on a day with nothing kept, every seed came out as one unbroken streak (decided by valevasqc
2026-10-05: no perfect streak).
It also moves each seeded habit's `createdAt` back to its first seeded day, since the app hides
every day before `createdAt`. Day keys use the machine's time zone (`TZ=…` to override). Run it
from `functions/` after a one-time `gcloud auth application-default login`:

```
npm run build && node lib/seedHistory.js --uid <uid> --days 30          # dry run, prints the plan
npm run build && node lib/seedHistory.js --uid <uid> --days 30 --apply  # writes to nori-pet
```

**Run 2026-10-05 on the demo account** (`demo@test.com`, see `TEST_ACCOUNT.local.md`): 6 habits,
30 days → 117 logs, level 5, 1,480 XP, 740 coins, sunglasses gifted, pet still baby (evolves at 7),
4 missed days and a short current streak. Verified against Firestore afterward. It isn't exported from `index.ts`, so it never deploys as a
function.

Original plan (superseded by the above for this project's actual scale, kept for context): use
the **Firebase Local Emulator Suite** (Firestore + Auth + Functions emulators) for both of you
during development — never point local `flutter run` at the production `nori-pet` project.
Emulator config is GCP-sprint setup work; how the two of you share/reset emulator state is worth
agreeing on before either sprint starts coding if you do end up using it.

## Phased rollout

### Data sprint
1. Firestore schema for every collection above, security rules, indexes (`habitLogs` needs a
   composite index on `date` for calendar range queries).
2. `Firestore*Repository` implementations — the plain-CRUD half of every repository interface:
   habit create/update/delete/reorder + progress logging, pet feed/groom/play (+ decay),
   inventory consume/equip, profile edits, vacation-mode toggle, bucket list, achievements.
3. Seed/migration script replacing `HabitHistoryStore.seedHistory`'s in-memory demo data with
   real Firestore documents (via the emulator, see "Local dev" below).

This is the schema design *and* most of the actual repository code — deliberately more than
just "design the DB," so it isn't a thin sprint sitting next to a heavy Backend one.

### Backend sprint
1. **Auth.** Sign up/login (email), Google Sign-In, session persistence, password reset,
   basic account settings; `onUserCreate` provisions the starter user/pet/inventory docs.
2. **Cloud Functions.** `claimHabit` / `unclaimHabit` (level-up math and
   evolution sync happen inside this same transaction, not a separate function);
   `purchaseCareItem` / `purchaseAccessory`.
3. **Client-side calling code.** Done for habits (2026-09-28) and for bucket list (Jimena's side)
   — the repository methods that are Cloud-Function-backed call the callable instead of
   mutating local state, the glue between the Data-sprint repositories and these functions.
4. **Bucket list.** `completeBucketListItem` / `uncompleteBucketListItem` /
   `deleteBucketListItem` — same currency-minting
   reasoning as habit claims, plus the reward cap (see "Bucket-list rewards" above). This is real
   Backend-sprint work, not an afterthought — it just wasn't in the original draft's task list.
5. **Achievements need no Backend-sprint work at all.** Unlock state is fully derived from the
   other repositories (habits, calendar, bucket list, pet, inventory) — there's no currency
   action and nothing to guard. Only its Data-sprint read-the-repositories code exists.

### GCP sprint
`Setup Firebase project` ✅ done. `cloud_firestore`/`firebase_auth`/`cloud_functions` added to
`pubspec.yaml` ✅ done (2026-09-21). `functions/` scaffolded (TypeScript) ✅ done 2026-09-24 — the
two branches' separate `functions/` folders were merged into one shared codebase 2026-09-28 (a
`firebase deploy` from either separate folder would have deleted the other's live functions —
this actually happened once, to `onUserCreate`, and was redeployed from Jimena's branch; see
docs/RESOLVED_LOG.md's 2026-09-28 entry). **All 7 Cloud Functions deployed to the
live `nori-pet` project 2026-09-29** (`onUserCreate`, `claimHabit`, `unclaimHabit`,
`purchaseCareItem`, `purchaseAccessory`, `completeBucketListItem`, `uncompleteBucketListItem` —
confirmed via `firebase functions:list`), Blaze plan therefore active. `firestore.rules`
deployed the same pass. **2026-10-04:** the 2026-09-30 changes deployed too — `deleteBucketListItem`
and `deleteHabit` (9 functions live, confirmed via `firebase functions:list`), the `pet.stage` sync
in the two other bucket-list functions, `claimHabit`'s archived-day check, and the matching
`firestore.rules` changes (bucket-list delete, habit `archivedRanges`). **2026-10-26:** adaptive
XP (morning deploy), then the coin-reversal rule and the new `deleteAccount` (11 functions live,
confirmed via `firebase deploy` output). Left: CI/CD básico. **Cost check-in done 2026-10-26:** a $5/month
budget ("Firebase Project nori-pet") alerts at 50/90/100%; `gcf-artifacts` has Firebase's 3-day
cleanup policy (~0.56 GB, a cent or less a month over the 0.5 GB free tier); last 30 days peaked
at ~1.2k Firestore reads/day (free tier 50k) and a few hundred writes total. `petCareCheck`
(hourly, 1 read per pet) is the only cost that grows with users unprompted. Firebase Local Emulator Suite deliberately
not used for this project (see "Local dev").

Google Sign-In's console configuration (enabling the provider, OAuth client, SHA-1 fingerprints
for the Android build) sits in this sprint by category but belongs to **Jimena**, since it's
inseparable from implementing the sign-in itself — splitting the console setup from the code
would just create a handoff for no reason.

## Division of labor

Split by feature vertical — each person owns their vertical's schema/rules, CRUD repository
code, and Cloud Functions, across all three sprints, rather than one person per sprint.
The two verticals are sized to be comparable, but they're shaped differently: one is narrow and
deep (fewer pieces, more intricate logic per piece), the other is broad (more surfaces to build,
each self-contained). Splitting straight down "habit tracker vs. virtual pet" would have put
both the depth *and* half the breadth on one side, so Auth/onboarding/account sits with the pet
vertical to even it out.

- **Valeria — Core habit loop.** Habit CRUD + progress logging, `claimHabit` /
  `unclaimHabit` Cloud Functions (incl. XP/level-up math and the
  `pet.stage` write — see the seam note below), streaks, vacation mode. Narrow and deep: the
  atomic multi-document claim transaction plus the streak/XP edge cases OPEN_DECISIONS.md
  hasn't settled yet.
- **Jimena — Account & virtual pet.** The whole auth stack (sign-up/login, Google Sign-In
  including its console setup, account linking, password reset, session, email verification,
  username uniqueness), onboarding, profile/account settings, pet stats/care/decay, inventory,
  and four Cloud Functions (`purchaseCareItem`, `purchaseAccessory`, `completeBucketListItem`,
  `uncompleteBucketListItem`), plus bucket list and achievements. Broad: many independent
  surfaces, and auth has grown the most of anything here.

This is a judgment call about effort, not a measured estimate — nobody has built any of it yet,
so treat it as a starting split and rebalance once real progress gives a better read.
Achievements and bucket list are the most self-contained pieces and the easiest to move across
if one side runs heavier than expected.

**Owning a vertical includes owning its decisions.** The defaults written into this doc for
auth, pet care, inventory and the rest were worked out before anyone started building, which
means they're guesses made with less information than whoever ends up implementing them will
have. Change them where they're wrong — the only ask is that the change lands in the doc too,
so the other vertical isn't built against the old assumption.

**The seam between the two verticals is kept deliberately small.** `claimHabit`/`unclaimHabit`
is one atomic transaction, so it can't be split mid-function — Valeria writes the whole thing,
including the two places it reaches into Jimena's data:
1. `pet.stage`, when the user's level crosses `pet.evolutionLevelThreshold`. (Jimena's
   bucket-list functions also move the level, so since 2026-09-30 they call the same
   `syncPetStage` helper from `functions/src/habitTransaction.ts`. The rule lives in one
   place either way.)
2. `inventory.ownedAccessoryIds` + `equippedAccessoryId`, for the one-time sunglasses gift on
   first completion.

Both only need the field *shapes* agreed upfront (already fixed by the schema above), not
ongoing back-and-forth. Jimena still owns everything else about the pet and inventory: stat
values, care actions, decay, purchases, equip/unequip, and what the threshold values are.

## Task checklist

Roughly ordered, with a "done when" on each so it's clear when to move on. Shared setup comes
first, since neither vertical can start without it. Order within a vertical is a suggestion —
whoever's building it will have a better sense of what unblocks what.

### Shared setup (do together, or one person while the other reads this doc)
- [x] Add `cloud_firestore`, `firebase_auth`, `cloud_functions` to `pubspec.yaml` — done
      2026-09-21, `flutter analyze` clean.
- [x] Scaffold `functions/` as a TypeScript Firebase Functions project — done 2026-09-24; the two
      branches' separate copies merged into one codebase 2026-09-28.
- [ ] ~~Firebase Local Emulator Suite~~ — **skipped for this project**, see "Local dev" above.
      Testing instead against the live `nori-pet` project with a disposable test account.
- [x] `firestore.rules` field-level locks — **both verticals done**: Valeria's (`/users/{uid}`
      split, `habits/{habitId}`, `habitLogs/{logId}`) and Jimena's (`pet/main`, `inventory/main`,
      `/usernames`, `bucketList/{itemId}`) merged into one ruleset 2026-09-28, deployed
      2026-09-29.
- [x] `icon_registry.dart` + color-key registry — done for every icon/color the habit vertical
      actually uses (the closed add/edit-habit picker + the mock's seed-habit demo variety).
      Jimena's side added a parallel registry for bucket-list icons/colors — the two haven't been
      merged into one, logged in docs/KNOWN_ISSUES.md. **Not yet verified:** a release build
      (`flutter build apk --release`) hasn't been run to confirm `--tree-shake-icons` doesn't
      break either registry.

### Jimena — Account & virtual pet

**Status note (2026-09-29, added while merging her branch into Valeria's):** every item below is
checked off based on the code existing, matching this doc's spec, and (for the Cloud Functions)
being live on `nori-pet` with no stub/`UnimplementedError` bodies — not on independently
exercising each flow end-to-end the way `claimHabit`/`unclaimHabit` was verified. The one
exception is `onUserCreate`, which that same verification run exercised directly (real sign-up →
provisioned user/pet/inventory docs matched every value below exactly). Treat the rest as "looks
complete, confirm with Jimena or run it once" rather than fully proven.

- [x] `FirestoreUserRepository` — profile fields + `habitCategories` + vacation toggle only;
      `addXp`/`addCoins` correctly throw (Cloud-Function-only).
- [x] `FirestorePetRepository` — `getPet`, `useCareItem` (replaced `feed`/`groom`/`play` 2026-10-06); `syncEvolution` is a
      deliberate no-op (stage is Cloud-Function-only, set inside `claimHabit`).
- [x] `FirestoreInventoryRepository` — `getInventory`, `consumeCareItem`, accessory/equip methods.
- [x] `FirestoreBucketListRepository` — CRUD, payout goes through the Cloud Functions below;
      `deleteItem` calls `deleteBucketListItem` (2026-09-30) so a completed item's reward is
      taken back.
- [x] `completeBucketListItem` / `uncompleteBucketListItem` Cloud Functions — deployed, store
      `awardedXp`/`awardedCoins` for exact reversal, same pattern as habits.
- [x] `deleteBucketListItem` + `pet.stage` sync in the two above + rules delete change —
      written 2026-09-30 (by Valeria), deployed 2026-10-04. Not exercised live yet.
- [x] Achievements: `AppData.bindToUser` rebuilds `MockAchievementRepository` against the real
      bucket list/pet/inventory (and Valeria's real habits/calendar) — still no Firestore
      collection, as intended.
- [x] Firebase Auth: email sign-up/login, session persistence, password reset, account settings —
      `firebase_auth_repository.dart` has no stub methods.
- [x] Google Sign-In end to end, including the post-Google username picker
      (`choose_username_screen.dart`) and Android SHA-1 registration.
- [x] Account linking, both directions (password→Google and Google→password) — see
      `git log --grep=linking`.
- [x] Email verification — `email_verification_banner.dart`.
- [x] Username uniqueness — `/usernames` index, `username_repository.dart`.
- [x] `onUserCreate` Cloud Function — **independently verified 2026-09-29**: a fresh disposable
      sign-up landed with `level: 1`, `totalXp: 0`, `coins: 0`, pet `stage: baby` with full
      stats, the exact starter `careItemCounts`, and an empty `ownedAccessoryIds` — matches
      "New-account provisioning" above exactly.
- [x] Onboarding writes the chosen pet name to `pet/main` — `name_pet_screen.dart`.
- [x] `purchaseCareItem` / `purchaseAccessory` Cloud Functions — deployed, validate cost ≤ coins
      server-side against the duplicated catalog (see functions/src/shop.ts's own comment on
      why prices are hand-synced rather than trusted from the client).

### Valeria — Core habit loop
- [x] `FirestoreHabitRepository` — create/update/reorder, `logProgress`/`setProgress`, and the
      `*ForDate` variants; `habitLogs` writes for progress (the non-claim half), for every day
      including today. Smoke-tested against the live project.
      **Fixed 2026-09-24:** the midnight-rollover bug (today's state was stored on the habit doc
      instead of `habitLogs`) — see `docs/KNOWN_ISSUES.md`'s 2026-09-23 entry for the original bug
      and `docs/RESOLVED_LOG.md` once it's logged there. Habit docs are now pure definitions;
      `getTodayHabits()` is structurally `getHabitsForDate(today)` minus the schedule filter.
      Also fixed in the same pass: `Habit.createdAt` gives `isScheduledOn` an implicit lower
      bound (a new habit no longer counts as "missed" on days before it existed), and habit
      definitions are filtered `archived == false` in memory.
      Archive/restore/delete added 2026-09-30 — see "Deleting vs. archiving a habit".
      `deleteHabit` + rules deployed 2026-10-04; not exercised live yet.
- [x] `FirestoreCalendarRepository` + streak derivation over `habitLogs` range queries (one query
      per range, not one per day — see `logsInRange`). Vacation ranges wired to read from
      `FirestoreVacationLog`; the old blocker (no user doc) is gone since `onUserCreate`, but the
      flow is still unexercised live — see KNOWN_ISSUES.md "Vacation mode has never been
      exercised live".
- [x] `claimHabit` / `unclaimHabit` Cloud Functions — one transaction over habit + habitLog +
      user + pet + inventory (first-completion gift). **Implemented and deployed 2026-09-28/29**;
      **independently verified end-to-end 2026-09-29** against live `nori-pet` with a disposable
      test account (25 checks): claim/unclaim round trip lands on identical XP/coins/level,
      sunglasses gift is granted once and never revoked, a direct client write to `coins` is
      rejected by `firestore.rules`, an impossible `dayKey` is rejected, and claiming outside a
      habit's `startDate`/`endDate` window is rejected. `setHabitCompleted` was removed as a pure
      dispatcher over these two — see the Cloud Functions list above.
- [x] Rewrite the call sites in `habits_list_screen.dart`, `home_screen.dart`, and the calendar
      day-detail sheet to call `claimHabit`/`unclaimHabit` instead of the old three-step repo
      sequence (see gap #1 below) — done 2026-09-28. `bucket_list_screen.dart` wasn't touched
      here; it already calls Jimena's bucket-list Cloud Functions directly, a separate code path.
- [x] Seed script — `functions/src/seedHistory.ts`, written 2026-10-04 (Admin SDK, since
      `firestore.rules` block clients from writing claims; see "Local dev" for how to run it).
      Unit-tested, and run 2026-10-05 on the demo account (30 days, verified).

## Explicit non-goals this phase

Matches FEATURES.md's MVP boundary — don't build backend for: friends/social, activity feed,
leaderboards, competitions, proof uploads (the Social tab's frontend exists since 2026-10-21 but
runs entirely on `MockSocialRepository` — see KNOWN_ISSUES.md — so there is still no backend for it). Also not this phase: push notifications/FCM (the in-app feed exists since
2026-10-21; phone notifications are still open in OPEN_DECISIONS.md, and the backlog lists FCM
under a later QA & Release epic), Apple Health/Fitbit/Duolingo integrations and health wearables (watch/ring — FEATURES.md §12), analytics, store listing.

## Gaps/risks found while planning this

1. ~~**The current claim flow isn't atomic.**~~ — **fixed 2026-09-28.** `claimHabit`/
   `unclaimHabit` now do the habit + user + pet + inventory writes in one Firestore transaction
   server-side; the three screens (`home_screen.dart`, `habits_list_screen.dart`, the calendar
   day-detail sheet) no longer call `AppData.user.addXp`/`addCoins`/`AppData.pet.syncEvolution`
   after a claim — they reload and let the function's own before/after result decide whether to
   celebrate.
2. **Notifications/FCM**: in-app feed built 2026-10-21 (see "In-app notifications"). Phone
   notifications (local reminders or FCM push) are still undecided in OPEN_DECISIONS.md and
   out of scope here.
3. **~~The habit schema originally stored `currentValue`/`isCompletedToday`/`lastAwardedXp`/
   `lastAwardedCoins` on the habit doc, which didn't survive a day change~~ — found 2026-09-23,
   fixed 2026-09-24.** Habit docs are now pure definitions; that state lives in `habitLogs` for
   every day, today included. See `docs/KNOWN_ISSUES.md`'s 2026-09-23 entry for the original bug
   and the schema block above for the current shape. This was worth resolving before writing
   `claimHabit`, since that function needed to know which place is the real source of truth for
   "today" before it could write to it — it now does.
