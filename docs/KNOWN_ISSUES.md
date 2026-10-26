# Nori — Known Issues

This file contains only currently open bugs and gaps, not a task queue tied to any
particular session — log something here the moment you notice it even if you don't plan
to fix it right away. When a fix lands, write a terse 2–4 sentence entry directly in
`docs/RESOLVED_LOG.md` using `### YYYY-MM-DD — <short title>`: state what changed and
why, not a narrative. Then remove or trim the item from wherever it was listed as open
here — don't leave a closed item worded as if it's still a problem.

**Priority flags** — how urgent, not how easy:
- 🔴 **Critical** — active bug, data loss, or a core feature that's visibly broken
- 🟠 **Important** — real risk, accessibility failure, missing core feedback, or notable
  debt that will bite soon
- 🟡 **Minor** — polish, cosmetic, backlog debt, or a deliberate/known stand-in

Findings below marked "(2026-09-10 audit)" are from a full UX/UI + code-quality audit run
against commit `fa96657` plus the uncommitted working tree at the time (habit
history/calendar rework, `SocialScreen`/`BucketListScreen` added, `LeaderboardScreen`
removed, Achievements moved under Profile). Verified by two independent passes (source
review + a rendered-screenshot pass on a Pixel 412×915 viewport, since there's no Android
emulator available in this environment) plus a separate code-only pass, then spot-checked
by hand against the live files. File:line references were correct as of that commit;
expect drift as work continues — treat the mechanism described as the durable part, the
line number as a pointer that may need a `grep` to relocate. Not included: the full
component-duplication tables, persona walkthroughs, and pixel-level screenshot
measurements — those lived in the chat report for that session and are reproducible by
re-running the audit.

---

## 🔴 Critical

(None open right now — see docs/RESOLVED_LOG.md for the midnight-rollover fix, 2026-09-24.)

---

## 🟠 Important

### Vacation mode has never been exercised live (2026-10-05, replaces a 2026-09-23 entry)

The 2026-09-23 blocker is gone: `onUserCreate` now creates `/users/{uid}` with
`vacationModeEnabled: false` and `vacationRanges: []`, `firestore.rules` lets the owner update both
fields, and `AppData.vacationLog` is the real `FirestoreVacationLog`. But no account on `nori-pet`
has ever saved a vacation range (checked 2026-10-05), so starting/ending a freeze, and the calendar
and streak treating frozen days as safe, are untested end to end. One manual pass on
`demo@test.com` closes this.

### Live Cloud Functions are ahead of the committed code (2026-10-05, updated 2026-10-26)

**Also not deployed yet (2026-10-26):** the pay-once change (`claimHabit`, `unclaimHabit`,
`deleteHabit`, the bucket-list functions) and its `firestore.rules` bucket-delete tightening.
Live still runs the earlier "reject the unclaim if the coins were spent" version, so the app's
reward pill and the server disagree until `firebase deploy --only functions,firestore:rules`.

Every deploy since 2026-10-04 (latest 2026-10-26: adaptive XP, the coin-reversal rule,
`deleteAccount`, plus `petCareCheck` and the notification writes) went out from
`valevasqc-dev`'s uncommitted working tree — `deleteAccount.ts`, `bucketList.ts`, `shop.ts`,
`onUserCreate.ts`, `petCareCheck.ts` and `adaptiveXp.ts` aren't in git at all. A
`firebase deploy --only functions` from any checkout without those files would delete those
functions from the live project (Firebase treats
local source as the full desired state; this already happened once, see RESOLVED_LOG.md
2026-09-28). Resolved by committing and merging into the branch both people deploy from.

### No reward feedback on claim itself (2026-09-10 audit; level-up half fixed 2026-09-15)

`HomeScreen._applyReward` (`lib/screens/home/home_screen.dart:92`) adds XP and coins with
no animation, toast, or any visible event — claiming a habit is still silent in the
moment, discoverable only by noticing the XP pill's number changed. The full-screen
level-up/evolution half of this finding is now fixed (see docs/RESOLVED_LOG.md). Still open:
a reward burst anchored to the card on claim itself (`+20 XP · +10 coins`), for the many
claims that *don't* cross a level boundary.

### Cognitive load & interaction gaps (2026-09-10 audit)

- **Add Habit puts 13 decision points on one uninterrupted scroll**: name, icon (6
  options), category (4), tracking type (6), target, unit, min-threshold toggle+value,
  difficulty (3), repeat (4), custom days (7), end-date toggle+range, vacation toggle —
  none of it chunked into steps, so the page reflows under the user's thumb as conditional
  sections appear mid-scroll. By a fair distance the most demanding screen in the app.

(Debunked 2026-09-15: "Logging a quantity/duration habit from the Home panel dead-ends"
is no longer true — `HomeScreen` already wires a real `onQuickLog: _quickLog` straight
into `HabitTile`'s `_QuickLogChip`, which calls `logProgress` and reloads inline; the old
dead-end SnackBar text doesn't exist anywhere in `lib/` any more. Must have been fixed in
a prior rework and never marked in `docs/RESOLVED_LOG.md` — removing rather than re-fixing.

The original audit also flagged "tapping the pet opens Customization instead of care" as
a gap here — confirmed 2026-09-15 by valevasqc that this is intended: care actions
are toggled per-stat, not via tapping the pet itself. Not a bug.)

---

### Email sign-in fails in the release web build under Playwright (2026-10-26, unconfirmed cause)

Found while testing notifications. A `flutter build web --release` served locally (from both
`localhost` and `127.0.0.1`) shows "Unable to sign in. Please try again." for `demo@test.com`, and
no request ever reaches `identitytoolkit.googleapis.com`. The same credentials work against the Auth
REST API. Only `firebase-app.js` was fetched from gstatic, and the page has `window.firebase_core`
but no `firebase_auth`. So the Auth JS SDK apparently never loaded, and `login_screen.dart`'s
`catch (_)` hides the real error. **Does not reproduce in `flutter run -d chrome`**: valevasqc signs
in fine there (confirmed 2026-10-26). So it is limited to the release build and/or headless
Playwright. Low priority unless the release web build matters. If it does, check first that
FlutterFire's web plugin registration includes auth. (The `google_sign_in_web` "ClientID not set"
assertion in the debug console was a separate, harmless problem, fixed the same day; see
RESOLVED_LOG.md.)

### Sign-up can fail if onUserCreate cold-starts slowly (2026-09-30, found reviewing Jimena's flow)

`sign_up_screen.dart` writes the profile (`updateProfile`) right after the account is created, but `/users/{uid}` comes from the asynchronous `onUserCreate` trigger. `_updateWithRetry` (and `renamePet`) retry 5 × 400ms, about 2s total, while a cold-started v1 function can take longer. If it does, the user sees "Unable to create your account" even though the account and username claim already exist, and retrying fails with email-already-in-use. Not reproduced yet, so worth a deliberate check in QA (first sign-up after the function has been idle). A longer or backoff retry would cover it.

## 🟡 Minor / polish / backlog

### No "change password" while logged in (2026-10-06, split out 2026-10-26)

Password accounts can only reset through the login screen's emailed link; Settings only offers
"Set a Password" to Google-only accounts. Probably fine for MVP, but it's what users will look
for in Settings.

### Profile email is only synced to a confirmed email change on the next Edit Profile save (2026-10-26)

Edit Profile shows the login email (`AppData.auth.currentEmail`) and writes it to the
`/users/{uid}` doc on save, so after the confirmation link is clicked the Firestore `email`
field stays stale until the user next saves that screen. Nothing else displays it today. Also
note Firebase signs the user out once the change is confirmed, so they log back in with the new
address — worth confirming in QA on a real inbox.

### Bucket-list card shows a reward the server won't pay (2026-09-30)

The add/edit sheet's XP and coin fields accept any number, and the card's `RewardPill` shows it
as typed, but `completeBucketListItem` silently pays at most 500 XP / 250 coins. Type 3000 XP and
the card promises 3000 but pays 500. BACKEND.md deliberately left the fields free-text when the
cap was set. The fix is either clamping the fields in the sheet or showing the capped amount on
the card. 🟡 cosmetic, but it's a visible broken promise.

### claimHabit still trusts two client-written habit fields (2026-09-24, found while implementing it)

`claimHabit` no longer trusts the habit doc's `xpReward`/`coinReward`/`adaptiveMultiplier`
(it derives base rewards from `difficulty` and clamps the multiplier — see docs/BACKEND.md's
Cloud Functions list). Two smaller cheats are still possible, because `firestore.rules`' habit
`allow create` accepts any payload: (1) a client can create a habit with a backdated
`createdAt`, then claim it on every past day back to that date; (2) a client can create any
number of habits and claim each one daily. Each claim is capped at 45 XP (hard × 1.5), so
this stays the bounded "moderate" trust level docs/BACKEND.md chose, not an open mint. The fix,
if it's ever worth doing: require `createdAt == request.time` in the create rule (the client
would send `FieldValue.serverTimestamp()`, and `FirestoreHabitRepository.addHabit` would need
to switch to that).

### Pet vitals are a direct client write, so buying care items is optional (2026-09-28 audit)

`firestore.rules` lets a client set `hunger`/`hygiene`/`happiness` on `pet/main` to any value,
so a modified client can keep the pet at 100 without spending coins on food/care items. This is
the trust level chosen for cosmetic stats (docs/BACKEND.md); logged only because the shop economy
depends on it. Fix if it ever matters: allow only decreases from the client (like
`careItemCounts`) and move restoring into a `consumeCareItem` Cloud Function.

### Achievements: 3 of 27 are "coming soon" placeholders, and none checked on real data (2026-10-06, updated 2026-10-26)

`achievement_repository.dart` defines 27 achievements. 24 compute real progress: 19 from the live
repositories (`AppData.bindToUser` points them at Firestore) and the 5 Social ones from mock social
data (see "Social tab is frontend-only"). 3 are `_soon` placeholders that never progress: Balanced
Life, Pet's Best Friend, Growing Family. Growing Family depends on multi-pet support, which is
vision-only, so it can stay a placeholder; Balanced Life and Pet's Best Friend look buildable from
existing data if wanted. No achievement has been checked against real Firestore data yet;
`demo@test.com` (30 seeded days) is a good account to do it on.

### Two parallel icon/color registries (2026-09-28 merge, logged 2026-10-05)

Habits store icons/colors through `IconRegistry` (`icon_registry.dart`) and `ColorRegistry`
(`color_registry.dart`); bucket-list items use the separate top-level `kIconRegistry`/
`kColorRegistry` maps in the same `icon_registry.dart`, from Jimena's branch. Both work and the
keys don't conflict, but adding an icon or color means knowing which one a screen uses.
BACKEND.md's shared-setup checklist already said this was logged here; it wasn't until now.
Merge into one registry when either side next touches icons.

### A release APK has never been built (2026-10-05)

The registries exist because `--tree-shake-icons` blanks `IconData` codePoints it can't prove are
used, which only shows up in release builds. Nobody has run `flutter build apk --release` yet, so
that protection is unverified, as is anything else release-only (minification, Google Sign-In's
release SHA-1). Run one before Demo Day, not on it.

### Dart mock still has a 75% "min" reward tier (2026-09-28 audit)

The server has no partial tier anymore (the minimum threshold keeps streaks but pays nothing —
FEATURES.md §3), but `HabitRewardTier.min` (0.75×) and `Habit.rewardTier` in
`lib/models/habit.dart` still exist and drive `MockHabitRepository`'s rewards. Since claims snap to
the target it's rarely reached, but it's a second copy of the reward rule that now disagrees with
`functions/src/rewards.ts`. Remove it once nothing in the UI reads the tier.

### First-habit sunglasses gift has no in-app moment (2026-09-28 audit)

`claimHabit` returns `giftedAccessoryId` when it grants the sunglasses, but
`FirestoreHabitRepository._callRewardFunction` drops it — the accessory just appears (and is
auto-equipped) in the inventory with no celebration or explanation.

### functions/ has 8 moderate transitive npm audit findings (2026-09-24, scaffold)

`npm install` in the newly-scaffolded `functions/` pulls in a vulnerable `uuid` (<11.1.1,
missing buffer bounds check when a `buf` argument is supplied — GHSA-w5hq-g745-h8pq) several
layers deep inside `firebase-admin`'s own Google Cloud dependencies (`google-gax` →
`gaxios`/`teeny-request` → `uuid`). Cloud Functions code never calls `uuid` directly or passes
it a `buf`, so this isn't attacker-reachable through anything Nori's functions do — flagging
for hygiene, not urgency. `npm audit fix --force` would resolve it by bumping
`firebase-admin` to a breaking major version (14.x); worth doing as a deliberate upgrade once
there's real function code to regression-test against, not blind right after scaffolding.

### FirestoreCalendarRepository re-runs its 400-day streak query on every getMonth call (2026-09-23 audit)

`FirestoreCalendarRepository.getMonth()` (`lib/data/calendar_repository.dart`) calls
`_currentStreak()`, which performs a fresh 400-day `logsInRange` query every time — even
when browsing a past month where the current streak is irrelevant to the display. The
three `getMonth` fetches (habit definitions, the month's log range, and the streak's
400-day range) also run sequentially instead of concurrently with `Future.wait`, though
none depends on the others.

### FirestoreCalendarRepository duplicates MockCalendarRepository's status/streak logic (2026-09-23 audit)

`FirestoreCalendarRepository._statusFor` and `_currentStreak` are copied nearly
line-for-line from `MockCalendarRepository` rather than sharing one implementation. A
future status or streak rule change — for example, respecting a per-habit
`allowVacationFreeze` flag — must be made twice; missing one would make the mock and
Firestore calendars silently disagree, undercutting the mock's doc-comment promise
that a day's colour and habit list can never disagree.

### Streak/stats day-walk skips a day across DST (2026-09-23 audit)

`FirestoreCalendarRepository._currentStreak` and `MockCalendarRepository._currentStreak`,
along with `getHabitStats` in both, walk backward by subtracting a fixed
`Duration(days: 1)`/24 hours from a `DateTime` instead of constructing
`DateTime(year, month, day - 1)`. On a daylight-saving spring-forward transition,
local midnight minus 24 hours lands at 23:00 two calendar days back, silently skipping
a day. This predates the Firestore work in the mock; it was found during this audit,
not introduced by it.

### Evolution stage 2 has no real art yet (deliberate placeholder, not a bug)

`Pet.stage` already has two values (`baby`, `evolution1` — see `lib/models/pet.dart`
and FEATURES.md §6), and `PetRepository.syncEvolution` correctly promotes a pet once the
user's level crosses `evolutionLevelThreshold`. But there is no actual second-stage
character art: `nori_front/side/back.png` and the `nori_breathing/frame_*.png` sequence
are all extracted from real photography/video of a physical prop (see
`nori_breathing_sprite.dart`), not vector illustration — a true "evolved" look needs new
footage of that same prop, not something that can be drawn or generated in code.

Until that footage exists, `evolution1` reuses the exact same sprite, scaled up slightly
and given a warm mustard glow + a few sparkle accents (`NoriRoomStage`'s `_EvolvedAura`,
and the matching glow in `EvolutionScreen`), so evolving reads as "something changed"
instead of silently doing nothing. This is a deliberate stand-in, not a design decision —
when real stage-2 art lands, swap it in at both call sites (`NoriRoomStage.stage` and
`EvolutionScreen`) and drop the aura treatment.

### Neck/hand accessory anchors not implemented (necktie, bow, hand-held items)

Per-frame anchor points now exist for eye-midpoint and head-top (see docs/RESOLVED_LOG.md,
2026-09-13), covering glasses and every current hat/headphones item. Neckties/bows and
hand-held accessories are explicitly **not** covered yet:

- **Neck/chest**: Nori's silhouette is one rounded body with no distinct head/neck/torso
  break, so there's no clean anatomical landmark to detect automatically the way eye and
  head-top blobs were. The best available proxy (his mouth, as a dark blob) only detects
  reliably on ~56 of the 67 frames — good enough to *derive* an anchor from with
  interpolation across the gaps, but nobody's calibrated it yet, and no necktie/bow item
  exists in `accessory_catalog.dart` to tune it against.
- **Hands**: his arms are tucked into the body outline in most frames — there's no
  separate hand/paw shape to anchor to at all in the neutral breathing pose (only a couple
  of the blink/laugh-expression frames show a raised paw). Not solvable with the current
  art; would need new footage/art that actually draws a hand before this is anchorable.

A tail anchor *is* already tracked (`NoriFrameAnchors.tail` in
`lib/widgets/nori_frame_anchors.dart`) and validated against sample frames, ready for a
future tail-bow item — it's just unused today since no such item exists in the catalog.

Fix shape when a necktie/bow item is actually added: extend the mouth-blob detection
script (referenced in `nori_frame_anchors.dart`'s doc comment) to interpolate the ~11
missing frames, add an `AccessoryAnchor.chest` case parallel to `eyeMid`/`headTop` in
`lib/widgets/accessory_art.dart`, and calibrate one `_AnimatedAccessoryPlacement` entry by
eye the same way the existing five were.

### Remaining layout defects (2026-09-10 audit; re-verified against current code 2026-09-15 — several items had drifted, see below)

Re-verification found roughly half of the original list is stale. **Debunked, no longer
open** (source-read only, not a rendered pass — worth a glance if either regresses, but
not worth re-auditing blind):
- **Shop category chips**: now a horizontally-scrolling `ListView.separated`
  (`shop_screen.dart:171-207`), not a fixed row — no label truncation, no chip cut off
  by the viewport edge. The original finding no longer applies.
- **Welcome/Sign-up left-edge alignment**: both screens' stacked elements already read
  off one shared constant (`AppSpacing.containerPaddingMobile` on Welcome,
  `AppSpacing.gutter` on Sign-up's label and field padding alike) — not misaligned.
- **Habits list "Min. Reached" pill wrap**: that label no longer exists — renamed to
  "Target Reached!" (`habit_progress_card.dart:329`) and lives in an unconstrained
  `Wrap`, not a tight pill; can't two-line-wrap the way described.
- **Bucket list "Add" CTA doesn't stand out** (was listed separately under Minor below,
  debunked by the same pass): uses `TactileButton` with no color override — the exact
  same terracotta-fill primary-CTA styling as "Get Started," "Save Habit," "Save Look,"
  etc. elsewhere in the app. Not visually secondary; removed from the Minor list.

**Fixed 2026-09-15** — see docs/RESOLVED_LOG.md. The floating Save Habit bar half of the original
Add Habit finding was debunked on re-check (a real `bottomNavigationBar` with reserved
space, not overlapping content); only the description-clipping half was real and got fixed.

**Still real, not quick** (needs a product/content decision, not a styling tweak):
- **Settings genuinely sparse**: `build()` renders exactly two small cards (Vacation Mode,
  Habit Categories) on the whole screen — confirmed still true, but fixing it means
  deciding what else belongs on Settings, not a numeric tweak.

**Not re-verified this pass** (kept as originally audited, no update):
- **Customization header title centering**: the `const SizedBox(width: 48)` spacer
  (`customization_screen.dart:151`) is still a hardcoded guess rather than a shared/
  measured value, but it happens to equal the default `IconButton` tap-target width it's
  balancing, so there's likely no visible misalignment today — a code-quality nit, not a
  confirmed visible bug. Downgraded from "worth a visual check" to "leave alone until it
  actually misaligns."

### Architecture: component duplication instead of reuse (2026-09-10 audit; widget/header/badge extraction done 2026-09-13, scaffold extraction done 2026-09-14, card-shell extraction done 2026-09-14, see docs/RESOLVED_LOG.md)

Re-verified 2026-09-13 before fixing (counts had drifted from the original audit — see
the `docs/RESOLVED_LOG.md` entry for the corrected numbers). Fixed: screen header, icon badge, section
header, `RewardPill`/`LoadingOverlay` byte-identical duplicates, and the styled
`FilledButton` moss/ink default are now shared (`lib/widgets/nori_screen_header.dart`,
`nori_icon_badge.dart`, `section_header.dart`, `reward_pill.dart`, `loading_overlay.dart`,
and `AppTheme.light.filledButtonThemeData`). The scaffolding preamble was fixed
2026-09-14 (`NoriScrollScaffold`). The plain ink-outlined card shell was also fixed
2026-09-14 (`NoriCard`) — see docs/RESOLVED_LOG.md for both.

Still open — deliberately deferred, these couple decoration to something else
(tap-ripple, animation, or an already-compound local layout) so a plain shell swap
would either add risk or not actually reduce duplication:

| Concept | Status |
|---|---|
| Tap-ripple cards (`Material`/`InkWell`/`AnimatedContainer` wrapping their own decoration) | Not migrated to `NoriCard` — `habit_tile.dart`'s `InkWell(child: Container(...))`, `nori_list_row.dart`'s `NoriListRow` (`Material` shape + `InkWell`, extracted 2026-09-15 from `profile_screen.dart`'s old `_AccountRow` and now shared with Settings), and `payment_method_screen.dart`'s `_PaymentOptionCard` (`AnimatedContainer` color transition) each need the border radius to stay in sync with a ripple/animation, not just a static decoration — left bespoke rather than force-coupling two widgets' radius values. |
| Compound local shells (`_CardShell` in habit_progress_card.dart's *content*, `_ItemCardShell`'s inner tile in shop_screen.dart) | Each file already deduped its own 2-3 variants into one local widget before this pass — `NoriCard` now backs each shell's outer `Container`, but the compound layout inside (claim/unclaim buttons, badge overlay) stays local since it's not decoration, it's behavior/layout specific to that screen. |
| Remaining un-migrated card classes (`add_habit_screen.dart`'s `_TypeCard`, `nori_plus_screen.dart`'s `_FeatureComparisonCard`/`_PlanCard`, `login_screen.dart`/`sign_up_screen.dart`, `customization_screen.dart`, `home_screen.dart`) | Not reviewed this pass — the 2026-09-14 sweep covered the screens already migrated to `NoriScrollScaffold` plus `habit_progress_card.dart`; these are a plausible next slice if this keeps going, just not verified yet. |

### Duplicated logic (2026-09-10 audit; formatting/date/coin-formula dedup done 2026-09-13, see docs/RESOLVED_LOG.md)

Fixed: thousands-separator formatting (now 1 helper, was actually 4 copies — a 4th,
undocumented one was found in `ProfileScreen` during re-verification), `_formatNum`,
the weekday/month name tables (was actually 7 tables across 4 files, not 5), the
duplicated coin-reward formula, and a newly-spotted duplicate id-generation expression
in `AddHabitScreen`/`BucketListScreen` — see docs/RESOLVED_LOG.md for details, including a real
`RangeError` bug the id-generation dedup surfaced and fixed.

Still open — deliberately deferred, this one's behavior code, not presentation:

- Claim/unclaim/quick-log orchestration is duplicated across `HomeScreen`,
  `HabitsListScreen`, and `CalendarScreen`'s day-detail sheet — re-verified 2026-09-13:
  `HabitsListScreen` and `CalendarScreen` are genuinely near-identical (six methods each,
  differing only in date source), but `HomeScreen`'s version is meaningfully different
  (no evolution-celebration sync, different today-only repository methods) — it's closer
  to "2.5x" than a clean triplication. A `HabitDayController` would remove the
  `HabitsListScreen`/`CalendarScreen` half of this and, importantly, make the past-day
  corruption bug (see docs/RESOLVED_LOG.md) fixable in one place instead of two-to-three. Not
  attempted: this is behavior code that's already had subtle per-screen bugs fixed
  individually, and there's no test suite yet to catch a regression from merging it.
- Related, found during the 2026-09-13 pass but out of scope for it: the "sync pet
  evolution → refetch → compare stage → show celebration" sequence is copy-pasted 4
  times (`HomeScreen._loadData`, `HomeScreen._reloadUserAndPet`,
  `CalendarScreen._applyReward`, `HabitsListScreen._claimHabit`), each with its own
  slightly-different guarding comment. Same risk profile as the item above — worth
  tackling together once there's test coverage for the evolution-celebration flow.

### Dead code (2026-09-10 audit; desktop-branching removal done 2026-09-14, see docs/RESOLVED_LOG.md)

Fixed 2026-09-14 for the 10 screens that only used the branch for padding/grid-density
decisions — see docs/RESOLVED_LOG.md. **Still deliberately left in place**, both documented as
structural deviations rather than plain copies of the dead pattern:
`HomeScreen` (its own `Align`+`SizedBox` layout, not `Center`+`ConstrainedBox`, with a
code comment explaining why) and `CustomizationScreen` (700 vs. 800 threshold, and
per-child padding instead of one outer padding — doesn't share the other 10 screens'
structure closely enough to retrofit safely in the same pass). **Not** part of any of
this: `CustomizationScreen`'s grid breakpoints at 440/620, `NotificationsScreen`'s
`< 360` check, and `PaymentMethodScreen`'s form-layout breakpoint at 440 are real
in-phone breakpoints and should stay. (`accessoryById`'s missing `orElse` — no longer
unused, now fixed, see docs/RESOLVED_LOG.md.)

### Minor / cohesion (2026-09-10 audit)

- **"Nori" naming collision, partially fixed 2026-09-15**: the user's avatar (`NoriAvatar`)
  rendered next to a heading literally reading "Nori" in two places. `CalendarScreen`'s
  header used `title: 'Nori'` while every other screen's `NoriScreenHeader` uses its own
  screen name ("Settings", "Profile", "Bucket List", etc.) — a clear copy-paste outlier,
  now fixed to `title: 'Calendar'`. Still open: `HomeScreen`'s `_RoomHud` card also pairs
  `user.avatarUrl` with the pet's name and `LEVEL ${user.level}` — left alone, since that
  one's genuinely ambiguous rather than a mistake (FEATURES.md §7 explicitly leaves "does
  XP belong to the user or the pet" undecided, so it may be a deliberate "trainer + pet"
  framing rather than a bug) and changing it is a naming/branding call, not a code fix.
- `NoriShell` uses `IndexedStack` (`lib/navigation/nori_shell.dart:35`) to keep every tab
  mounted, so `NoriBreathingSprite`'s `..repeat()` animation (`nori_breathing_sprite.dart`)
  keeps repainting its 67-frame loop the whole time the user is on Habits/Calendar/
  Social/Profile, not just Home. `IndexedStack` is the right call for preserving scroll
  and panel state (see the doc comment at `home_screen.dart:27-32`) — this isn't an
  argument against it, just a note that the sprite itself should pause when off-screen.

### Testing backlog (2026-09-10 audit)

No `test/` directory exists yet. Highest-value first tests, in order: (1)
`Habit.computeReward()`/`rewardTier` (`lib/models/habit.dart`) — the economy math, five
consumers, zero coverage, test the `limit` type first since its pass/fail logic is
inverted from the other five types; (2) the claim → unclaim round-trip on
`MockHabitRepository` — assert the XP/coin delta nets to zero, since a drift here is
invisible in the UI and would go unnoticed for weeks; (3) a regression test for the
past-day edit corruption bug above — it fails today, and writing it forces the decision
about where the fix belongs; (4) `Habit.isScheduledOn` — decides which habits appear on
every day, calendar cell, and the streak walk, so an off-by-one silently rewrites history
with no crash; (5) `MockUserRepository.addXp`'s level-boundary math (crossing up,
crossing down on an unclaim, floor at level 1).

### Achievements could look better (dictated 2026-09-10; content revamped 2026-09-15, custom art started 2026-09-15, 14/18 still flat icons)

Content half done 2026-09-15, and the "should I ask Gemini for custom art" question
answered by doing it — see docs/RESOLVED_LOG.md for both. 4 of 18 (`habit-architect`, `on-track`,
`perfect-week`, `first-step`) now have real crest art; the other 14 still use the flat
Material-icon badge treatment. Whoever's driving has more art to generate for the rest —
pick up by dropping new source images in `assets/source/achievements/` and following the
same wiring (`Achievement.imageAsset`, see `achievement_repository.dart`).

### Social tab is frontend-only; what a backend would still need (2026-10-21)

The whole tab runs on `MockSocialRepository` (`lib/data/mock_social_repository.dart`), behind the
`SocialRepository` interface on `AppData.social`. Nothing persists and nobody else's data is
real. When social gets a backend: implement that interface (don't touch the screens), add
cross-user Firestore rules (friend-scoped reads — BACKEND.md says none exist), and move score-like
fields (weekly XP, competition progress, proof counts) behind Cloud Functions rather than letting
clients write their own numbers. Proof photos have nowhere to live (no Storage in the stack), so
`ProofPhoto` is a placeholder panel. "You" is real (2026-10-21): `getMe()` reads the signed-in
account's name, username, level, XP, streak and pet, plus XP awarded over the last 7 days
(`lib/data/social_account.dart`, reads only; falls back to the seeded "Hannah Walker" if a read
fails), and the proof composer lists your habits completed today (sample list if none). Not yet
verified against live Firestore with a real account. Because weekly XP is real and the friends are
seeded at 400–1,450, a light week ranks you last. `proofCount` and your side of friend-streak
days are still seed data. Mock-only
leftovers to delete with the mock: `resetDemo` and the hub menu's "Preview: no friends yet" items,
and `tool/social_preview.dart` (renders any social screen without sign-in: `flutter run -d chrome
-t tool/social_preview.dart`, `?screen=<name>` / `?empty=1`).

Social achievements (2026-10-26): the separate "Social badges" section was removed (it duplicated
Achievements). The Social category in `achievement_repository.dart` now has five live achievements
— Better Together, Helping Hand, Proof Pal, Circle Starter, Accountability Duo — computed from
`SocialRepository.getSocialActivity()`, i.e. from the mock social data, so their progress is
placeholder until social has a backend (and resets on app restart).

### Onboarding tips needed, without cluttering the Habits screen (dictated 2026-09-10, not yet investigated)

Users need a way to discover: partial completion is editable, tasks can be set back to
zero, and long-press reorders the list — but not via permanent hint UI cluttering the
Habits screen itself. Needs a mechanism (first-run tooltip? dismissible one-time coach
mark? info icon with a sheet?) — not decided yet.

### Mock profile picture needed (dictated 2026-09-10, not yet investigated)

Create one for the demo user (`kDemoUser`, `lib/data/user_repository.dart`) since Profile
is about to become more prominent.

### Accessory placement needs another visual-adjustment pass (2026-09-14, paused mid-pass — see note)

Six accessories each render in up to three places — the Shop card / equip-grid icon
(`AccessoryItem.image`, fixed), the static Customization preview
(`_kPlacements` in `lib/widgets/accessory_art.dart`), and the animated Home sprite
(`_kAnimatedPlacements`, same file) — and getting the latter two right has taken repeated
rounds of "looks wrong → guess new numbers → still wrong," which is expensive in tokens
and has not converged for every item. Status as of 2026-09-14, from valevasqc's own
testing: **Sunglasses is confirmed correct on both screens.** The rest (Flower Crown,
Horn Bow, Steampunk Goggles, Chef Hat, Tail Charm Clasp) have not all been confirmed
correct after this session's changes — this session re-measured Horn Bow and Sunglasses'
static placement directly off the reference sheets (`assets/source/accessories/`) against
`nori_front.png`'s actual pixel bounds rather than guessing, and separately fixed a real
bug where `tail-charm-clasp`'s worn render was using the sheet's bold "display" cutout
instead of the small "actually worn" one (now `AccessoryItem.wornImage`) — but a full
confirm-on-device pass for every item on both screens was **not** completed, per an
explicit token-budget call from valevasqc mid-session ("nothing but the glasses works
perfectly... we are just burning tokens").

Fix shape when picked back up: don't re-derive scale/position from reference-sheet
geometry alone — render each item on both screens at a real mobile viewport (~412 wide)
and adjust from what's actually on screen, one item at a time, confirming with a
screenshot before moving to the next rather than batching guesses across several items.

### General visual boredom — triaged (2026-09-15, screens named, not yet implemented)

Triaged screen-by-screen against the existing "Flat Storybook" design system (ink-outlined
flat shapes, moss/terracotta/mustard/blush/sky palette — `lib/theme/`). Bucket List,
Social, Customization, Profile, and Calendar already read as distinct/on-brand (colored
goal badges, chunky `ProgressBarPill`s, the illustrated pet stage, achievement art, the
status-colored month grid) — not flat, leave alone. Genuinely flat/generic, in priority
order:

- **Notifications**: a conventional stack of white rows; the colored `NoriIconBadge`s
  help but there's no screen-level visual moment. Fix shape: give `_NotificationsHeader`
  (`notifications_screen.dart`) a 48px circular `NoriIconBadge` (bell icon,
  `AppColors.mustardLight`) next to the title, and tint each unread `_NotificationCard`'s
  `NoriCard` background with that notification's own `color` at low alpha (read cards stay
  white) — reuses the color/badge system that already exists instead of adding anything new.
- **Sign Up / Login**: both are well-branded but otherwise generic centered auth cards —
  logo, fields, CTA, nothing distinct once the logo's gone. Fix shape: wrap the existing
  `_SignUpHeader`/`_LoginHeader` (`sign_up_screen.dart`/`login_screen.dart`) in a shallow
  `AppColors.mossLight` panel inside the current card with a thin ink rule beneath it
  (same ink-outline language already used everywhere else), and on Login, swap the
  "Continue with Google" button's `AppColors.linenAlt` surface for `AppColors.sky` so the
  form has one intentional accent instead of every surface being the same neutral tone.
  No new fields, no new copy, no layout restructuring.
- **Settings**: visually fine (each card already uses `NoriCard`/icon badges consistently)
  — its flatness is a *content* gap (3 sparse cards), not a visual-treatment one; see
  "Settings genuinely sparse" above, that's a product/IA decision, not a styling fix.

Deliberately not attempted this pass: implementing these blind risks the same
"looks-wrong-in-code, still-wrong-on-screen" cycle the accessory-placement work hit (see
below) — any of the above should get a live render check (`flutter run -d chrome` at the
~412px mobile viewport) before being called done, not just a code read. Flagging with
concrete fix shapes rather than shipping unverified.

---


## Resolved

Full fix history: [`docs/RESOLVED_LOG.md`](RESOLVED_LOG.md).
