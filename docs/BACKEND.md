# Nori — Backend Plan (Firebase)

Decided 2026-09-16: **Firebase Auth + Cloud Firestore + Cloud Functions (Node.js/TypeScript)**.
This doc is the technical reference for the **Backend, Data, and GCP** phases in
[ROADMAP.md](ROADMAP.md) — the course's own three-way sprint split. What gets built, in what
shape, and by whom. It does not reopen product/scope questions;
[FEATURES.md](FEATURES.md) stays the source of truth for *what* the app does, and
[OPEN_DECISIONS.md](OPEN_DECISIONS.md) stays the source of truth for unresolved game-balance
numbers (XP curve, adaptive-XP formula, cadence multipliers, shop prices, etc). Backend
implements whatever balance math already exists in the mock repos (`lib/data/*.dart`) — it does
not invent new balance numbers.

[firestore.rules](../firestore.rules) is the source of truth for what clients may write. This doc
explains the intent behind it. History of how the doc got here (bugs found, deploys, verification
runs) lives in [RESOLVED_LOG.md](RESOLVED_LOG.md).

## Starting point

The frontend is built against a repository-interface seam (`lib/data/app_data.dart`): every
screen depends on abstract repositories (`HabitRepository`, `PetRepository`, `UserRepository`,
`InventoryRepository`, ...). Each has an in-memory `Mock*` implementation and a real
`Firestore*` one; `app_data.dart` is the only file that decides which is used.

Stack in place: Firebase project `nori-pet` (Android + web), `firebase_core`, `cloud_firestore`,
`firebase_auth` and `cloud_functions` in `pubspec.yaml`, `firestore.rules`, and a single shared
`functions/` TypeScript codebase.

## How this maps to the course's Backend / Data / GCP sprints

Splitting by technical layer gives three sprints that are each substantial on their own:

- **Data phase** — Firestore schema + security rules + indexes, **and** the persistence layer
  itself: the direct-write `Firestore*Repository` classes doing plain CRUD (habit
  create/update/reorder, progress logging, pet care actions, inventory equip, profile edits,
  bucket list, achievements), plus the seed script.
- **Backend phase** — Firebase Auth wiring (sign up/login, Google Sign-In, password reset,
  session persistence) + the Cloud Functions that enforce currency/business rules + the
  client-side calling code for those. The business-logic/orchestration layer, not "everything
  that isn't UI."
- **GCP phase** — Firebase/GCP project + console config, environment/secrets, CI/CD, deploying
  Cloud Functions/rules to the live project, cost awareness.

The rule from the architecture table below decides *what* each piece of logic does; this section
just says which sprint builds it: plain reads/writes → Data, currency-affecting logic + Auth →
Backend, config/deploy → GCP.

## Architecture: what's a Cloud Function vs. a direct client write

**Rule of thumb: Cloud Functions guard the two currencies (XP, coins) and anything derived
from them (level, evolution stage). Everything else is a direct, rules-guarded client write.**
This is the "moderate" option — not full server-authoritative, not fully client-trusted — chosen
to keep the Cloud Functions surface small enough for a 2-person team on a semester timeline,
while closing the one real cheat vector (a client overwriting its own XP/coins field).

| Operation | How | Sprint | Why |
|---|---|---|---|
| Habit create/update/reorder/archive | Direct client write | Data | No currency involved |
| Habit delete (almost no history only) | **Cloud Function (callable)** | Backend | Must take back what its claims paid |
| `logProgress` / `setProgress` (non-claiming) | Direct client write | Data | FEATURES.md §3: logging progress alone never earns XP |
| `claimHabit` / `unclaimHabit` (today or a past date) | **Cloud Function (callable)** | Backend | Mints XP + coins, must update habit log + user + pet atomically |
| Feed / groom / play (+ stat decay) | Direct client write (client-side transaction) | Data | Spends an already-owned consumable for a pet stat, not currency; pet "cannot die" so stakes are low |
| Spending the care item | Same transaction as above (`PetRepository.useCareItem` reads and writes `pet/main` + `inventory/main` together) | Data | Same reasoning |
| Buying a care item or accessory from the shop | **Cloud Function (callable)** | Backend | Spends coins to mint an owned item — currency-affecting |
| Equip/unequip an already-owned accessory | Direct client write | Data | No currency involved |
| Profile edit, vacation mode toggle | Direct client write | Data | No currency involved |
| First-user provisioning (user doc, starter pet, starter care items) | **Cloud Function (`onCreate` auth trigger)** | Backend | Grants starting resources |
| Onboarding answer (pet name) | Direct client write, after sign-up | Data | An auth trigger can't see it — it's typed on a later screen, and it isn't currency |
| One-time sunglasses gift on first habit completion | **Inside the `claimHabit` Cloud Function** | Backend | Grants an item; must be atomic with the claim that triggers it |

## Firestore schema

All per-user data lives under `/users/{uid}`, secured by `request.auth.uid == uid`. No
cross-user queries exist (friends/social is not built — see FEATURES.md §10), so there's no
need for top-level collections keyed by `userId`. The **one** exception is the `/usernames`
index, which has to be global precisely because it enforces uniqueness *across* users — see
"Username uniqueness" below.

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
achievement *definitions* stay bundled Dart constants; nothing requires updating them without an
app release. Their string ids (`'food'`, `'cake'`, `'shampoo'`, `'hair-brush'`, `'plushie'`,
`'blanket'`; `'flower-crown'`, `'sunglasses'`, …) are stable and are what Firestore stores.

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

**Keep `Future`, do not switch to `Stream`.** Every repository method returns a `Future` and
screens call them from `initState`/button handlers with `setState`. Firestore's `snapshots()` is
tempting but converting even one repository to streams means rewriting that screen's state
management. Use `.get()` / `.set()` / `.update()`. Live-updating UI is not an MVP requirement.
(The one exception is the unread-dot query on Habits; see "In-app notifications".)

**Icons: use a string-key registry, never store `codePoint`.** `Habit.icon` and
`BucketListItem.icon` are `IconData`. Build one `Map<String, IconData>` registry (see
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

**Dates and the day-rollover rule.** `dayKey()` in `habit_history_store.dart` produces the
canonical `yyyy-mm-dd` key in **device-local** time. The client computes it and passes it
explicitly to every Cloud Function call. **Cloud Functions must never derive the day themselves**
— server time is UTC, so a claim at 9pm local would file under tomorrow for some users. Store
both `dayKey` (string, used in the doc id, what claim/unclaim look up) and `date` (Timestamp at
local midnight, used only for calendar range queries). The wider timezone question (user travels,
DST) stays open in OPEN_DECISIONS.md — this rule is enough for MVP and avoids the obvious bug.

**Derived, never stored.** Two values are computed on read and must stay that way, because a
stored copy already went stale once (see the comment in `user_repository.dart`):
- `currentStreak` — derived from habit history via `CalendarRepository`.
- achievement unlock state — derived from the other repositories, as above.

**Balance numbers are still open**, so porting the mock's behavior as-is is the safe move —
filling the gaps in passing means the eventual real answer has to be un-picked from the code.
OPEN_DECISIONS.md tracks what's genuinely unresolved. The level curve is the one that *has* been
settled — see below.
- `adaptiveMultiplier` is **computed by `claimHabit` on every claim**
  (`functions/src/adaptiveXp.ts`) from the habit's last 14 days, within per-difficulty caps, and
  stored on the habit doc only so the app can preview the next reward. The client never writes
  it (`FirestoreHabitRepository._definitionFields` leaves it out). Rule and numbers:
  OPEN_DECISIONS.md "XP balancing".
- Claims pay `full` (1.0×) or `none` — no partial tier: the minimum threshold keeps streaks but
  pays nothing (FEATURES.md §3). The Dart mock's `HabitRewardTier.min` (0.75×) is a leftover, see
  KNOWN_ISSUES.md.
- Care-item restore amounts and prices come from `care_item_catalog.dart` as-is.

**XP curve: `xpForNextLevel = 100 × currentLevel`** (decided 2026-09-16; supersedes the mock's
flat value, which was unfinished rather than intentional). Level 1→2 costs 100, 2→3 costs 200,
6→7 costs 600. Cumulative XP to *reach* level n is `50 × n × (n − 1)`.

Only the Cloud Function needs this formula. It writes `level`, `xpIntoLevel` and
`xpForNextLevel` to the user doc, and the client just displays the stored values — so the curve
lives in exactly one place and the two languages can't drift apart. Don't reimplement it in Dart.

**In-app notifications.** In-app only, no push. The feed lives at
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
- **Firestore's offline persistence is off** (`persistenceEnabled: false` in
  `FirebaseFirestore.instance.settings`, set in `main.dart`). It's on by default on mobile, and
  leaving it on gives the worst of both worlds: Cloud Function calls fail instantly offline while
  direct writes silently queue, so half the app appears to work and half doesn't. Off means
  everything fails the same way, which is far easier to reason about and to demo.
- Network calls have a timeout so nothing can hang on a spinner forever.
- One shared helper (`RemoteLoadState` in `lib/utils/remote_errors.dart`) does "call, catch, show
  error"; it shouldn't become a per-screen pattern.

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
| Level / XP | `level: 1`, `totalXp: 0`, `xpIntoLevel: 0`, `xpForNextLevel: 100` (the curve's first step — see "XP curve" above) |
| Coins | `0` — the starter care items below cover the first care actions, so no float is needed |
| Care items | `{food: 3, shampoo: 2, plushie: 1}` |
| Accessories | **None.** `ownedAccessoryIds: []`, `equippedAccessoryId: null` — the mock's pre-owned `sunglasses` is a demo artifact; see the first-completion gift below |
| Pet stats | `hunger/hygiene/happiness: 100`, `stage: baby`, `lastDecayAt: now`, `evolutionLevelThreshold: 7` (a real balance decision, FEATURES.md §6) |
| Pet name | Chosen by the user during onboarding — see the sequencing note below |
| First-completion flag | `firstHabitCompletedAt: null` — see the gift rule below |

**The sunglasses are the one and only free accessory, granted on the user's first habit
completion** — not at sign-up, and never again for anything else. Every other accessory is
bought with coins.

- **Where it lives:** inside the `claimHabit` transaction. If `firstHabitCompletedAt` is null, the
  same transaction adds `'sunglasses'` to `ownedAccessoryIds`, sets `equippedAccessoryId` to it,
  and stamps `firstHabitCompletedAt`.
- **It is deliberately one-way.** Un-claiming that first habit does **not** take the accessory
  back or clear `firstHabitCompletedAt` — a gift that appears and vanishes while the user
  toggles a checkbox is worse than a tiny inconsistency. (Un-claiming never takes XP/coins back
  either, see the pay-once rule under Cloud Functions #3.)
- Until then the pet simply renders with no accessory equipped.

**Pet naming changes the `onUserCreate` sequence.** A Firebase Auth `onCreate` trigger only
receives the auth record — it cannot know a name the user types on a later onboarding screen.
So: `onUserCreate` provisions the pet with the name `'Nori'`, and the onboarding screen writes
the chosen name afterward as a **direct client write** to `pet/main` (a pet's name isn't
currency, so it needs no Cloud Function). If the user skips onboarding, the name simply stays
`'Nori'`. Don't try to pass the name into the auth trigger; it isn't possible.

**Deleting vs. archiving a habit** (decided 2026-09-30 by valevasqc).
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
  Function, in one transaction: it removes the habit and all its logs, takes back whatever those
  claims paid (the exact stored amounts, including days later unclaimed), re-syncs `pet.stage`,
  and keeps the sunglasses gift. It is rejected if those coins were already spent. The client can
  never delete a habit doc directly.
- **Hard delete of a habit with real history is deferred**: whether its earned XP/coins
  should stay or be taken back is undecided. See OPEN_DECISIONS.md.

## Security rules

[firestore.rules](../firestore.rules) is authoritative; this is the intent.

- Default deny everywhere.
- `/users/{uid}` and everything under it: read/write only if `request.auth.uid == uid`.
- On the user doc: clients may write profile fields (`name`, `username`, `email`, `avatarUrl`) +
  `vacationModeEnabled`/`vacationRanges`/`habitCategories`. `level`, `totalXp`, `xpIntoLevel`,
  `xpForNextLevel`, `coins` are **denied to client writes** — only reachable via Cloud
  Functions, which use the Admin SDK and bypass rules entirely.
- Habit docs: clients may create them and edit the definition fields plus `order`, `archived`
  and `archivedRanges`. Clients can never delete one (`deleteHabit` does, see above).
- `habitLogs` docs: clients may create a log only with `claimed: false` and zero awards, and may
  update **only `value`**. `claimed` / `awardedXp` / `awardedCoins` are Cloud-Function-only.
  Never deletable by clients.
- `pet/main`: clients may write `name`, `hunger`, `hygiene`, `happiness`, `lastDecayAt`.
  `stage` and `evolutionLevelThreshold` are **denied to client writes** — otherwise a client
  could set its own evolution stage directly, which is exactly the currency-adjacent write the
  Cloud-Functions boundary exists to prevent. Only the Cloud Functions touch them (`claimHabit`
  and the bucket-list functions via `syncPetStage`).
- `inventory/main` needs different rules on different fields of the same document, because
  `consumeCareItem` and a purchase both write `careItemCounts`/`ownedAccessoryIds`, but only one
  of them should be able to grant something new:
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
- `bucketList/{itemId}`: clients may create an item only with `isCompleted: false` and zero
  awards, and edit only title/description/icon/color/rewards. Delete directly only while the item
  has never paid; anything that paid goes through `deleteBucketListItem`.
- `notifications/{id}`: clients may create only `achievement` and `streak` kinds (unread, server
  timestamp) and afterwards only flip `isRead`. The rest are written by Cloud Functions.
  `notificationState/main`: clients own `achievementIds`, `streakMilestone`,
  `streakMilestoneDay`; `level`, `petEvolved`, `petCareAt` are server-only.
- `/usernames/{usernameLower}`: the one global collection. Public `read` (availability check
  happens before an account exists), `create` only when authenticated and the payload's `uid`
  matches the caller, `delete` only by the owning uid, `update` never. The atomicity of
  "create fails if it already exists" is what enforces uniqueness — see "Username uniqueness".

## Cloud Functions

All callable except #1 (Auth trigger) and #11 (scheduled). Functions 1, 5, 6, 7, 8, 9 are
Jimena's; 2, 3, 10, 11, 12 are Valeria's. Keep this list short.

1. `onUserCreate` (Auth trigger) — provisions `/users/{uid}`, starter pet, starter inventory.
   The pet name doesn't go through this function — an auth trigger only sees the auth record,
   not a value typed on a later onboarding screen. It's a direct client write after sign-up
   instead; see "New-account provisioning".
2. `claimHabit({habitId, dayKey, dayStartMillis})` — computes the claim value + reward tier,
   writes habitLog + user (XP/coins/level) + pet (evolution sync) + inventory (first-completion
   gift) in one transaction (`functions/src/claimHabit.ts`, pure math in
   `functions/src/rewards.ts`). Calls made while building it:
   - **Day args are required, not optional.** `dayKey` is the client's device-local
     `yyyy-mm-dd`; `dayStartMillis` is that day's local midnight (becomes the log's `date`).
     The server checks they agree (within ±14h, the UTC-offset range), rejects impossible dates
     (`2026-02-31`), future days, days before the habit's `createdAt`, days outside its
     `startDate`/`endDate`, and archived days.
   - **Base XP/coins come from `difficulty`, not the habit doc's `xpReward`/`coinReward`.**
     `firestore.rules` lets clients edit those two fields, so trusting them would let anyone
     mint arbitrary XP. The add-habit screen already writes exactly `difficulty.baseXp`/
     `baseCoins`, so real habits see no change. The stored `adaptiveMultiplier` is ignored
     for the same reason: `claimHabit` recomputes it from the last 14 days' logs (read with
     `getAll` on their known doc ids, so no index is needed) and writes the new value back in
     the same transaction.
   - **Level math uses `applyXpDelta` from `functions/src/xpCurve.ts`** — the single shared
     curve implementation, also used by the bucket-list functions. Handles multi-level jumps both
     ways; claim → unclaim → claim lands on the identical level.
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
   user or pet (XP and coins stay as paid). Not claimed → no-op. Bucket-list complete/uncomplete follow the same rule. Deletes (`deleteHabit`,
   `deleteBucketListItem`) still reverse every stored payout, and are rejected if those coins
   were already spent (`coinsAfterReversal`), so create → claim → delete can't mint either.
   Returns the same shape as `claimHabit`.
4. ~~`setHabitCompleted`~~ — removed as a duplicate endpoint: it only dispatched to
   claim/unclaim. The binary checkbox's Dart `setHabitCompleted(id, completed)` calls
   `claimHabit` or `unclaimHabit` directly instead.
5. `purchaseCareItem(itemId, quantity)` — validates cost ≤ coins, decrements coins, increments
   `careItemCounts`. Prices are hand-synced with the Dart catalog (see `functions/src/shop.ts`
   for why they aren't trusted from the client).
6. `purchaseAccessory(accessoryId)` — validates cost ≤ coins, decrements coins, adds to
   `ownedAccessoryIds`. Rejects an accessory the user already owns.
7. `completeBucketListItem(itemId)` — awards the item's XP/coins and **stores what it paid into
   `awardedXp`/`awardedCoins`** on the item. Syncs `pet.stage` in the same transaction, like
   `claimHabit` (the client can't write `stage`, so otherwise a bucket-list reward could cross
   the evolution level without evolving the pet).
8. `uncompleteBucketListItem(itemId)` — un-marks the item but keeps what it paid (pay once, see
   #3); completing it again pays nothing.
9. `deleteBucketListItem(itemId)` — deletes the item, first reversing its stored payout if it
   ever paid one (completed now or earlier), in one transaction. `firestore.rules` only lets the
   client delete an item directly while it isn't completed and has never paid (`awardedXp`/
   `awardedCoins` both 0).
10. `deleteHabit(habitId)` — deletes a habit with at most 2 active days plus all its logs,
    taking back what its claims paid, in one transaction. Rejects anything with more history
    with "archive it instead". See "Deleting vs. archiving a habit".
11. `petCareCheck` (scheduled, hourly) — writes a "pet needs you" notification when a pet's
    decayed vital is below 30, at most once per 24h. See "In-app notifications". #2 and #7 also
    write level-up/evolution/gift notifications inside their transactions.
12. `deleteAccount()` — deletes the caller's `/usernames` entries, the whole `/users/{uid}` tree
    (`recursiveDelete`), then the Auth user. Data goes first so a failure leaves a signed-in
    user who can retry; every step is idempotent. Settings → Delete Account, behind typing the
    username.

**Why 7 and 8 store what they paid:** bucket-list rewards are editable by the user at any time
(the add/edit sheet has free-text XP and coin fields). Reversing an un-completion against the
item's *current* value lets someone complete an item at 150 XP, edit it to 3000, un-complete it,
and walk away +2850 XP — not a cheat anyone would necessarily set out to find, just an
inconsistency that produces impossible totals. Habits solve this with the log's
`awardedXp`/`awardedCoins`; bucket list needs the same treatment. Same rule as always: reverse
exactly what was paid, never a recomputation.

**Bucket-list rewards are capped server-side at 500 XP / 250 coins** (decided 2026-09-16).
`completeBucketListItem` clamps whatever the item asks for before awarding it, and the add/edit
sheet shows and enforces the same caps (`BucketListItem.maxXpReward` / `maxCoinReward`).
Rationale: an uncapped 3000 XP item would carry a brand-new user most of the way to their first
evolution in a single tap. Bucket-list items are still meant to feel much larger than a habit
(10–30 XP); the cap bounds them, it doesn't shrink them.

**No limit on how many bucket-list items exist — honor system** (decided 2026-09-30 by
valevasqc). The per-item cap above is the only server-side limit: someone could create many
maxed-out items and complete each one. That's accepted as a self-reward feature, not patched.
Deleting a completed item does take its reward back (`deleteBucketListItem`), so you can't keep
a reward and reuse the slot.

**Level-up must handle multi-level jumps.** A capped 500 XP award still crosses levels 1→3 for
a new user, so the level loop must be a loop (a `while`, not an `if`) — `applyXpDelta` on the
server, and whatever the UI does to celebrate a level-up needs to survive several firing from
one call.

## Auth

Firebase Auth: email/password sign-up + login, Google Sign-In, password reset (Firebase's
built-in flow), session persistence. Sign-up collects name, username, email and password —
the same four fields `MockAuthRepository.signUp` takes.

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
  constraint, so it needs the `/usernames/{usernameLower}` index collection, claimed atomically.
  See "Username uniqueness" — this is the one part of Auth with real machinery behind it.
- **Account deletion** is the `deleteAccount` Cloud Function (#12). Firestore doesn't cascade
  deletes, so it does the recursive wipe itself; Settings → Delete Account.
- **Onboarding** is the sign-up → name-your-pet screens. There is no stored "onboarding
  completed" flag (an earlier plan had `onboardingCompletedAt` on the user doc; it was never
  built, and the rules wouldn't allow the write).

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
- Rules: `read` open; `create` only when authenticated and `request.resource.data.uid ==
  request.auth.uid`; `delete` only by the uid that owns it; `update` never (a change is a delete
  plus a create).

Rare edge case: account created, claim lost the race, user closes the app before re-picking.
That leaves a user doc with no username. Treat a missing username as "prompt on next launch"
rather than an error state — it shouldn't happen, but it shouldn't brick the account either.

## Pet, inventory & shop rules

Defaults so nothing stalls, most of them just describing what the mock already does:

- **Decay** is 2 points/hour per stat, clamped 0–100, ported unchanged from `MockPetRepository`.
  It's applied lazily whenever the pet is read or acted on, so the pet's stats need no scheduled
  function. (`petCareCheck` is separate: it only reads the decayed value to raise a
  notification.)
- **Tapping Feed/Groom/Play with zero of that item left** does nothing and reports failure:
  `consumeCareItem` returns `false`. It must not throw, must not let the count go negative, and
  must not restore the pet stat "for free" when there was nothing to consume.
- **Care actions are one transaction**: apply decay, consume the item, and restore the stat
  together, so a failure can't consume an item without restoring anything.
- **Buying something already owned** is rejected server-side, even if the UI already hides it.
- **No cap on care-item counts** — nothing in FEATURES.md calls for an inventory limit.
- **Restore amounts and prices** come from `care_item_catalog.dart` unchanged.

## Local dev

Valeria's side develops and tests directly against the live `nori-pet` project, not the
emulator, using a disposable test account (credentials in the gitignored `TEST_ACCOUNT.local.md`;
the one to use is `demo@test.com`, which went through the real sign-up). Each repository method
is verified against real Firestore, and test documents are deleted afterward via
`firebase firestore:delete`. Reasoning: this is a 2-person course project with no real users, no
Java runtime was available locally, and the emulator's benefits (cost control, blast-radius
limits, instant resets) matter little at this scale next to the faster loop of skipping it.
`firebase.json` has an `emulators` block from Jimena's branch that Valeria's side doesn't use;
Jimena can use either approach — this isn't a hard rule.

**Seed script: `functions/src/seedHistory.ts`** (planning logic in `seedPlan.ts`, tested in
`seedPlan.test.ts`). It needs the Firebase Admin SDK because `firestore.rules` deny a plain
client from writing `claimed: true`/`awardedXp`/`awardedCoins` — on purpose, since that's
exactly how someone would fake free rewards. It seeds past days for an account's *existing*
habits (create them in the app first), with the same odds as the mock generator, and pays each
claim through the server's own `computeReward`/`applyXpDelta`/`syncPetStage`, plus the sunglasses
gift. Logs and the rewards they paid are written in the same transaction. It skips today,
vacation days, archived days, days outside a habit's start/end window, and any day that already
has a log, so re-running it is safe. It leaves about one whole day in eight empty (`--off-days`,
default 0.12) so the calendar's streak isn't one unbroken run (decided by valevasqc: no perfect
streak). It moves each seeded habit's `createdAt` back to its first seeded day, since the app
hides every day before `createdAt`. Day keys use the machine's time zone (`TZ=…` to override).
It isn't exported from `index.ts`, so it never deploys as a function. Run it from `functions/`
after a one-time `gcloud auth application-default login`:

```
npm run build && node lib/seedHistory.js --uid <uid> --days 30          # dry run, prints the plan
npm run build && node lib/seedHistory.js --uid <uid> --days 30 --apply  # writes to nori-pet
```

**Demo account reset: `resetDemoAccount`** (`functions/src/resetDemoAccount.ts`). A dev-only
callable behind Settings → Developer → "Reset demo account", so the bucket-list evolution flow
can be re-tested without running scripts. It takes back every bucket-list payout (XP, coins,
completed state — the stored `awardedXp`/`awardedCoins`, like `deleteBucketListItem`), drops
the level and pet stage that XP had earned, and clears the `notificationState` level/evolved
flags plus the old level-up / evolved notifications so they fire again. Habits, logs,
inventory and achievements are untouched. The function rejects any caller whose verified
token email isn't `demo@test.com`; the Settings row also hides itself for everyone else, but
that is cosmetic.

## Phased rollout

Status per phase lives in [ROADMAP.md](ROADMAP.md); this is what each one contains.

### Data sprint
1. Firestore schema for every collection above, security rules, indexes. No composite indexes
   are needed: every query filters on a single field.
2. `Firestore*Repository` implementations — the plain-CRUD half of every repository interface:
   habit create/update/reorder/archive + progress logging, pet care (+ decay), inventory
   consume/equip, profile edits, vacation-mode toggle, bucket list, achievements.
3. Seed script replacing `HabitHistoryStore.seedHistory`'s in-memory demo data with real
   Firestore documents (see "Local dev").

This is the schema design *and* most of the actual repository code — deliberately more than
just "design the DB," so it isn't a thin sprint sitting next to a heavy Backend one.

### Backend sprint
1. **Auth.** Sign up/login (email), Google Sign-In, session persistence, password reset,
   basic account settings; `onUserCreate` provisions the starter user/pet/inventory docs.
2. **Cloud Functions.** `claimHabit` / `unclaimHabit` (level-up math and evolution sync happen
   inside this same transaction, not a separate function); `purchaseCareItem` /
   `purchaseAccessory`; the bucket-list functions (same currency-minting reasoning as habit
   claims, plus the reward cap); `deleteHabit`, `petCareCheck`, `deleteAccount`.
3. **Client-side calling code.** The repository methods that are Cloud-Function-backed call the
   callable instead of mutating local state, the glue between the Data-sprint repositories and
   these functions.
4. **Achievements need no Backend-sprint work at all.** Unlock state is fully derived from the
   other repositories — there's no currency action and nothing to guard.

### GCP sprint
Done: Firebase project, Blaze plan, `cloud_firestore`/`firebase_auth`/`cloud_functions` in
`pubspec.yaml`, the shared `functions/` codebase, and all 11 Cloud Functions plus
`firestore.rules` deployed to the live `nori-pet` project (latest deploy 2026-10-26, confirmed
via `firebase functions:list`). Left: CI/CD básico, and a release APK build (never run; it would
also confirm `--tree-shake-icons` doesn't break the icon/color registries).

**One shared `functions/` folder, always deploy from it.** The two branches once had separate
`functions/` folders, and a `firebase deploy` from either one deleted the other's live functions
(this happened once, to `onUserCreate`; see RESOLVED_LOG.md's 2026-09-28 entry). They were merged
into one codebase.

**Cost** (checked 2026-10-26): a $5/month budget ("Firebase Project nori-pet") alerts at
50/90/100%; `gcf-artifacts` has Firebase's 3-day cleanup policy (~0.56 GB, a cent or less a month
over the 0.5 GB free tier); the last 30 days peaked at ~1.2k Firestore reads/day (free tier 50k)
and a few hundred writes total. `petCareCheck` (hourly, 1 read per pet) is the only cost that
grows with users unprompted. The Firebase Local Emulator Suite is deliberately not used (see
"Local dev").

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
  `pet.stage` write — see the seam note below), streaks, vacation mode, archive/delete,
  notifications, account deletion. Narrow and deep: the atomic multi-document claim transaction
  plus the streak/XP edge cases OPEN_DECISIONS.md hasn't settled yet.
- **Jimena — Account & virtual pet.** The whole auth stack (sign-up/login, Google Sign-In
  including its console setup, account linking, password reset, session, email verification,
  username uniqueness), onboarding, profile/account settings, pet stats/care/decay, inventory,
  and the shop and bucket-list Cloud Functions (`purchaseCareItem`, `purchaseAccessory`,
  `completeBucketListItem`, `uncompleteBucketListItem`, `deleteBucketListItem`), plus bucket
  list and achievements. Broad: many independent surfaces, and auth has grown the most of
  anything here.

The split was a judgment call about effort, not a measured estimate, so rebalance it if real
progress gives a better read. Achievements and bucket list are the most self-contained pieces
and the easiest to move across if one side runs heavier than expected.

**Owning a vertical includes owning its decisions.** The defaults written into this doc for
auth, pet care, inventory and the rest were worked out before anyone started building, which
means they're guesses made with less information than whoever ends up implementing them will
have. Change them where they're wrong — the only ask is that the change lands in the doc too,
so the other vertical isn't built against the old assumption.

**The seam between the two verticals is kept deliberately small.** `claimHabit`/`unclaimHabit`
is one atomic transaction, so it can't be split mid-function — Valeria writes the whole thing,
including the two places it reaches into Jimena's data:
1. `pet.stage`, when the user's level crosses `pet.evolutionLevelThreshold`. (The bucket-list
   functions also move the level, so they call the same `syncPetStage` helper from
   `functions/src/habitTransaction.ts`. The rule lives in one place either way.)
2. `inventory.ownedAccessoryIds` + `equippedAccessoryId`, for the one-time sunglasses gift on
   first completion.

Both only need the field *shapes* agreed upfront (already fixed by the schema above), not
ongoing back-and-forth. Jimena still owns everything else about the pet and inventory: stat
values, care actions, decay, purchases, equip/unequip, and what the threshold values are.

## Task checklist

Shared setup first, since neither vertical can start without it.

### Shared setup
- [x] `cloud_firestore`, `firebase_auth`, `cloud_functions` in `pubspec.yaml`.
- [x] `functions/` scaffolded as a TypeScript Firebase Functions project (one shared codebase).
- [ ] ~~Firebase Local Emulator Suite~~ — **skipped for this project**, see "Local dev".
- [x] `firestore.rules` field-level locks for both verticals, merged into one ruleset and deployed.
- [x] `icon_registry.dart` + color-key registry for the habit vertical. Jimena's side has a
      parallel registry for bucket-list icons/colors; the two haven't been merged into one,
      logged in docs/KNOWN_ISSUES.md. **Not yet verified:** a release build
      (`flutter build apk --release`) to confirm `--tree-shake-icons` doesn't break either one.

### Jimena — Account & virtual pet

Checked off on the basis of the code existing, matching this doc's spec, and (for the Cloud
Functions) being live on `nori-pet`. Only `onUserCreate` has been independently verified
end to end; treat the rest as "looks complete, confirm with Jimena or run it once."

- [x] `FirestoreUserRepository` — profile fields + `habitCategories` + vacation toggle only;
      `addXp`/`addCoins` correctly throw (Cloud-Function-only).
- [x] `FirestorePetRepository` — `getPet`, `useCareItem`; `syncEvolution` is a deliberate no-op
      (stage is Cloud-Function-only).
- [x] `FirestoreInventoryRepository` — `getInventory`, `consumeCareItem`, accessory/equip methods.
- [x] `FirestoreBucketListRepository` — CRUD, payout goes through the Cloud Functions;
      `deleteItem` calls `deleteBucketListItem` so a completed item's reward is taken back.
- [x] Bucket-list Cloud Functions (complete / uncomplete / delete) — deployed, store
      `awardedXp`/`awardedCoins` for exact reversal. `deleteBucketListItem` not exercised live yet.
- [x] Achievements: `AppData.bindToUser` rebuilds `MockAchievementRepository` against the real
      bucket list/pet/inventory/habits/calendar — still no Firestore collection, as intended.
- [x] Firebase Auth: email sign-up/login, session persistence, password reset, account settings.
- [x] Google Sign-In end to end, including the post-Google username picker
      (`choose_username_screen.dart`) and Android SHA-1 registration.
- [x] Account linking, both directions (password→Google and Google→password).
- [x] Email verification — `email_verification_banner.dart`.
- [x] Username uniqueness — `/usernames` index, `username_repository.dart`.
- [x] `onUserCreate` — independently verified: a fresh sign-up landed with the exact values in
      "New-account provisioning".
- [x] Onboarding writes the chosen pet name to `pet/main` — `name_pet_screen.dart`.
- [x] `purchaseCareItem` / `purchaseAccessory` — deployed, validate cost ≤ coins server-side.

### Valeria — Core habit loop
- [x] `FirestoreHabitRepository` — create/update/reorder, `logProgress`/`setProgress` and the
      `*ForDate` variants, archive/restore/delete. Habit docs are pure definitions;
      `getTodayHabits()` is structurally `getHabitsForDate(today)` minus the schedule filter.
      `deleteHabit` not exercised live yet.
- [x] `FirestoreCalendarRepository` + streak derivation over `habitLogs` range queries (one query
      per range, not one per day — see `logsInRange`). Vacation ranges read from
      `FirestoreVacationLog`; the flow is still unexercised live — see KNOWN_ISSUES.md "Vacation
      mode has never been exercised live".
- [x] `claimHabit` / `unclaimHabit` — one transaction over habit + habitLog + user + pet +
      inventory (first-completion gift). Verified end to end against live `nori-pet` (claim/unclaim
      round trip, one-time gift, direct `coins` write rejected by rules, impossible `dayKey` and
      out-of-window claims rejected).
- [x] Call sites in `habits_list_screen.dart`, `home_screen.dart` and the calendar day-detail
      sheet call `claimHabit`/`unclaimHabit`.
- [x] Seed script — `functions/src/seedHistory.ts`, see "Local dev".
- [x] In-app notifications and `petCareCheck`; `deleteAccount`.

## Explicit non-goals this phase

Matches FEATURES.md's MVP boundary — don't build backend for: friends/social, activity feed,
leaderboards, competitions, proof uploads (the Social tab's frontend runs entirely on
`MockSocialRepository` — see KNOWN_ISSUES.md — so there is no backend for it). Also not this
phase: push notifications/FCM (the in-app feed exists; phone notifications are still open in
OPEN_DECISIONS.md, and the backlog lists FCM under a later QA & Release epic), Apple
Health/Fitbit/Duolingo integrations and health wearables (watch/ring — FEATURES.md §12),
analytics, store listing.

## Open gaps

1. **Phone notifications** (local reminders or FCM push) are undecided in OPEN_DECISIONS.md and
   out of scope here.
2. **Streak and achievement notifications are client-side** until those calculations are ported
   to the server — see "In-app notifications".
