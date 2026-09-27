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
  currency/business rules (`claimHabit`, `unclaimHabit`, `setHabitCompleted`,
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
| `claimHabit` / `unclaimHabit` / `setHabitCompleted` (today or a past date) | **Cloud Function (callable)** | Backend | Mints/burns XP + coins, must update habit + user + pet atomically |
| Feed / groom / play (+ stat decay) | Direct client write (client-side transaction) | Data | Spends an already-owned consumable for a pet stat, not currency; pet "cannot die" so stakes are low |
| `consumeCareItem` as part of feed/groom/play | Direct client write, same transaction as above | Data | Same reasoning |
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
  habitCategories: [string]         # user-editable via Settings — NOT a static catalog, see below
  firstHabitCompletedAt: Timestamp? # null until first claim; gates the one-time sunglasses gift
  # NOTE: currentStreak is deliberately NOT stored — see "Derived, never stored" below

/users/{uid}/habits/{habitId}
  name, subtitle, iconKey (string), colorKey (string),   # see "Serialization" below — never store codePoints
  xpReward, coinReward, repeat, type, difficulty,        # enums stored as .name strings
  targetValue, unit, minThreshold,
  quickLogAmount, currentValue, adaptiveMultiplier, customDays, allowVacationFreeze,
  startDate, endDate, order, archived (bool, default false — new field, see deletion rule),
  isCompletedToday, lastAwardedXp, lastAwardedCoins    # ← Cloud-Function-only fields, see rules

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
- `adaptiveMultiplier` is a **static stored field clamped 0.5–1.5**, not an algorithm. Adaptive
  XP isn't built yet and isn't part of this round.
- Reward tiers are `none` / `min` (0.75×) / `full` (1.0×) from `HabitRewardTier` — retuning them
  is a balance question, not an implementation one.
- Care-item restore amounts and prices come from `care_item_catalog.dart` as-is.

**XP curve: `xpForNextLevel = 100 × currentLevel`** (decided 2026-09-16; supersedes the mock's
flat value, which was unfinished rather than intentional). Level 1→2 costs 100, 2→3 costs 200,
6→7 costs 600. Cumulative XP to *reach* level n is `50 × n × (n − 1)`.

Only the Cloud Function needs this formula. It writes `level`, `xpIntoLevel` and
`xpForNextLevel` to the user doc, and the client just displays the stored values — so the curve
lives in exactly one place and the two languages can't drift apart. Don't reimplement it in Dart.

**Notifications aren't in scope yet.** `notification_repository.dart` is hardcoded demo data,
and whether notifications exist at all is still an open product question in OPEN_DECISIONS.md —
so `MockNotificationRepository` stays wired in `app_data.dart` for now. A half-built
notifications collection would be worse than none until that question is answered.

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

- **Where it lives:** inside the `claimHabit` / `setHabitCompleted` transaction (Valeria's
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

**Deleting a habit archives it, never deletes its logs.** This extends FEATURES.md §2's
archive-not-delete rule to manual deletion. It needs a schema field that doesn't exist in the
current `Habit` model: add **`archived: bool`** (default `false`) to the habit doc, have the
habit list and "today" queries filter `archived == false`, and leave every `habitLogs` document
untouched. Past streaks, calendar days and achievements are all derived from those logs, so
deleting them would silently rewrite history.

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
2. `claimHabit(habitId, date?)` — computes the claim value + reward tier, writes habit +
   habitLog + user (XP/coins/level) + pet (evolution sync) in one transaction.
3. `unclaimHabit(habitId, date?)` — exact reversal using the stored `lastAwardedXp/Coins`,
   same atomic scope as above.
4. `setHabitCompleted(habitId, completed, date?)` — binary quick-toggle; thin wrapper over
   claim/unclaim.
5. `purchaseCareItem(itemId, quantity)` — validates cost ≤ coins, decrements coins, increments
   `careItemCounts`.
6. `purchaseAccessory(accessoryId)` — validates cost ≤ coins, decrements coins, adds to
   `ownedAccessoryIds`. Rejects an accessory the user already owns.
7. `completeBucketListItem(itemId)` — awards the item's XP/coins and **stores what it paid into
   `awardedXp`/`awardedCoins`** on the item.
8. `uncompleteBucketListItem(itemId)` — reverses using those stored values, never the item's
   current `xpReward`/`coinReward`.

That's the whole server-side surface for this phase — eight functions, all callable except #1.
Functions 1, 5, 6, 7, 8 are Jimena's; 2, 3, 4 are Valeria's.

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

Use the **Firebase Local Emulator Suite** (Firestore + Auth + Functions emulators) for both of
you during development — never point local `flutter run` at the production `nori-pet` project.
Emulator config is GCP-sprint setup work; the seed-data script (replacing today's
`HabitHistoryStore.seedHistory` demo generator) is Data-sprint work; how the two of you
share/reset emulator state is worth agreeing on before either sprint starts coding.

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
2. **Cloud Functions.** `claimHabit` / `unclaimHabit` / `setHabitCompleted` (level-up math and
   evolution sync happen inside this same transaction, not a separate function);
   `purchaseCareItem` / `purchaseAccessory`.
3. **Client-side calling code.** The repository methods that are Cloud-Function-backed
   (`claimHabit`, etc.) call the callable instead of mutating local state — this is the
   glue between the Data-sprint repositories and the Backend-sprint functions.
4. **Bucket list.** `completeBucketListItem` / `uncompleteBucketListItem` — same currency-minting
   reasoning as habit claims, plus the reward cap (see "Bucket-list rewards" above). This is real
   Backend-sprint work, not an afterthought — it just wasn't in the original draft's task list.
5. **Achievements need no Backend-sprint work at all.** Unlock state is fully derived from the
   other repositories (habits, calendar, bucket list, pet, inventory) — there's no currency
   action and nothing to guard. Only its Data-sprint read-the-repositories code exists.

### GCP sprint
`Setup Firebase project` ✅ done. Left: add `cloud_firestore`/`firebase_auth`/`cloud_functions`
to `pubspec.yaml` + scaffold `functions/` (Node/TypeScript); Firebase Local Emulator Suite setup
(see below); CI/CD básico; later, deploying Cloud Functions + rules to the live project; cost
awareness (Cloud Functions require the Blaze plan, still free-tier-eligible at this scale).

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
  `unclaimHabit` / `setHabitCompleted` Cloud Functions (incl. XP/level-up math and the
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
1. `pet.stage`, when the user's level crosses `pet.evolutionLevelThreshold`.
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
- [ ] Add `cloud_firestore`, `firebase_auth`, `cloud_functions` to `pubspec.yaml`; scaffold
      `functions/` as a TypeScript Firebase Functions project.
      **Done when:** `flutter analyze` is clean and `npm run build` in `functions/` compiles.
- [ ] Firebase Local Emulator Suite running (Auth + Firestore + Functions), app pointed at it in
      debug. **Done when:** both of you can run the app against the emulator with no prod writes.
- [ ] `firestore.rules` with the field-level locks from "Security rules" above.
      **Done when:** a client write to `coins` is rejected, and a normal habit edit is allowed.
- [ ] `icon_registry.dart` + color-key registry (see Conventions).
      **Done when:** every icon/color currently used by seed habits and bucket-list items has a
      key, and a **release** build (`flutter build apk --release`) still renders them correctly.

### Jimena — Account & virtual pet
- [ ] `FirestoreUserRepository` — profile fields + `habitCategories` + vacation toggle only.
      Do **not** touch `level`/`totalXp`/`xpIntoLevel`/`coins` (Cloud Functions own those).
      **Done when:** editing name/username/email and adding a category survive an app restart.
- [ ] `FirestorePetRepository` — `getPet`, `feed`, `groom`, `play`, decay-on-read. Port the decay
      math from `MockPetRepository` unchanged (2 points/hour, clamped 0–100). Each care action is
      one Firestore transaction that applies decay and the restore together.
      **Done when:** stats decay across an app restart and never go below 0 or above 100.
- [ ] `FirestoreInventoryRepository` — `getInventory`, `consumeCareItem`, `addCareItem`,
      `addAccessory`, `setEquippedAccessory`. `consumeCareItem` must be a transaction and must
      return `false` (not throw, not go negative) when the count is 0.
      **Done when:** using the last item of a type leaves the count at exactly 0.
- [ ] `FirestoreBucketListRepository` — CRUD only (add/edit/delete/list). The payout on
      complete/un-complete goes through Cloud Functions 7 and 8, not this class.
- [ ] `completeBucketListItem` / `uncompleteBucketListItem` Cloud Functions — store
      `awardedXp`/`awardedCoins` on completion, reverse from those stored values.
      **Done when:** completing an item, editing its reward, then un-completing it leaves XP and
      coins exactly where they started.
- [ ] Achievements: point the real repository at the real repositories. **No Firestore
      collection** — it stays computed. **Done when:** achievements still unlock with real data.
- [ ] Firebase Auth: email sign-up/login, session persistence, password reset, account settings.
      **Done when:** closing and reopening the app keeps you logged in, and a wrong password
      shows an error rather than crashing.
- [ ] Google Sign-In, end to end — console configuration (provider, OAuth client, Android SHA-1)
      *and* the client flow, including the post-Google username picker.
      **Done when:** a Google sign-up reaches Home with a username the user chose.
- [ ] Account linking, both directions (password→Google and Google→password).
      **Done when:** using the same email through both methods lands in the **same** account
      with the same pet and history — never a second account, never a dead end.
- [ ] Email verification — send on sign-up, dismissible banner with resend, gates nothing.
      *Droppable if the sprint runs short.* **Done when:** a new user gets the email and the
      banner disappears once verified.
- [ ] Username uniqueness — the `/usernames` index, live availability check on the sign-up form,
      atomic claim after account creation, and the change-username transaction.
      **Done when:** two accounts cannot end up with the same username in any casing, and
      changing a username frees the old one for someone else to take.
- [ ] `onUserCreate` Cloud Function — use the exact values in "New-account provisioning" above;
      no accessory is granted here. **Done when:** a fresh sign-up lands on Home with a level-1
      user, a full-stat pet named Nori, the three starter care items, an empty accessory list,
      and no crash.
- [ ] Onboarding writes the chosen pet name to `pet/main` as a direct client write after
      sign-up — the auth trigger can't see it. **Done when:** naming the pet during onboarding
      persists, and skipping onboarding leaves it as "Nori".
- [ ] `purchaseCareItem` / `purchaseAccessory` Cloud Functions — validate cost ≤ coins server-
      side, one transaction. **Done when:** buying with insufficient coins fails cleanly and the
      client cannot grant itself items by writing Firestore directly.

### Valeria — Core habit loop
- [ ] `FirestoreHabitRepository` — create/update/delete/reorder, `logProgress`/`setProgress`, and
      the `*ForDate` variants; `habitLogs` writes for progress (the non-claim half).
- [ ] `FirestoreCalendarRepository` + streak derivation over `habitLogs` range queries; vacation
      ranges read from the user doc.
- [ ] `claimHabit` / `unclaimHabit` / `setHabitCompleted` Cloud Functions — one transaction over
      habit + habitLog + user + pet. Port `Habit.computeReward()` and `MockUserRepository.addXp`'s
      level loop verbatim into TypeScript; the claim-value snap rule lives in
      `MockHabitRepository._claimValue`. **Done when:** claim → unclaim → claim leaves XP, coins,
      level and pet stage exactly where they started.
- [ ] Rewrite the call sites in `habits_list_screen.dart`, `home_screen.dart`,
      `calendar_screen.dart`, `bucket_list_screen.dart` to call the one callable instead of the
      three-step repo sequence (see gap #1 below).
- [ ] Seed script — real Firestore documents replacing `HabitHistoryStore.seedHistory`.

## Explicit non-goals this phase

Matches FEATURES.md's MVP boundary — don't build backend for: friends/social, activity feed,
leaderboards, competitions, proof uploads (all vision-only, no UI wired beyond the static
`SocialScreen` preview). Also not this phase: push notifications/FCM (OPEN_DECISIONS.md still
has "whether any exist at all" as unresolved — the backlog lists FCM under a later QA & Release
epic, don't build it now), Apple Health/Fitbit/Duolingo integrations, analytics, store listing.

## Gaps/risks found while planning this

1. **The current claim flow isn't atomic.** `habits_list_screen.dart` sequences three separate
   repo calls — `AppData.habits.claimHabitForDate(...)` → `AppData.user.addXp/addCoins(...)` →
   `AppData.pet.syncEvolution(...)` — with no transaction tying them together. Moving to
   `claimHabit` as one Cloud Function means **screen code changes too**, not just the repo's
   internals: budget time for rewriting those call sites, it isn't a drop-in swap.
2. **Notifications/FCM**: OPEN_DECISIONS.md says whether notifications exist at all is
   undecided. Treated as out-of-scope here (see non-goals) — resolve the product question
   before building any FCM wiring, whichever sprint it'd land in.
