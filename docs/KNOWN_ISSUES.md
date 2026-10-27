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

### Sign-up can still fail if onUserCreate cold-starts very slowly (2026-09-30; mostly fixed 2026-10-26)

`sign_up_screen.dart` writes the profile right after the account is created, but `/users/{uid}`
comes from the asynchronous `onUserCreate` trigger. The write now retries for about 4s (8 × 600ms,
was 2s), and if it still fails the screen remembers the new account and tells the person to tap
Create Account again, which resumes at the failed step instead of hitting "email already in use"
(see RESOLVED_LOG.md). Never reproduced; a first sign-up after the function has sat idle is the
case to try in QA.

### UX/UI audit 2026-10-26: what the easy-win pass did not fix

Whole-app audit (code + a rendered pass on a 412×915 viewport, signed in as `demo@test.com`; the
easy wins are in RESOLVED_LOG.md). Labels: **CONFIRMED** = seen in the render or in code,
**INFERRED** = likely but not reproduced, **UNRESOLVED** = needs a decision.

- **Tap targets under 48dp are systemic (CONFIRMED, 🟠).** Header `CircularIconButton`s are 36dp,
  the email banner's dismiss and every "More" menu are 40dp, Calendar day cells 41dp, and Social's
  Nudge/Details/See all/reaction/Mark Achieved buttons are ~32dp tall. Growing the header buttons to
  48 doesn't fit the Habits header (3 icon buttons + streak chip + XP pill in 372px), so it needs a
  decision first: move Archived Habits under Profile/Settings, or collapse header actions into one
  overflow. Calendar cells can't reach 48 in a 7-column grid; 41dp with the gaps kept is the practical floor.
- **Add Habit validation is a snackbar about a field you can't see (CONFIRMED, 🟠).** Tapping Save with
  Ideal Target empty shows "Enter an Ideal Target greater than 0." while that field is scrolled out
  of view and nothing is highlighted. Needs inline field errors plus scroll-to-first-error. Pairs with
  the 13-decision-point finding above; a stepper would fix both.
  Not an MVP blocker (assessed 2026-10-26): no data is lost, the message names the field, and
  retrying works. The cheap partial fix is to keep the snackbar and scroll to the offending field
  when Save fails (~10 lines, no new styling); the full inline-error version touches the busiest
  form's layout and wants a visual check on the mobile viewport.
- **Snackbars are the only feedback channel, and none has an action (CONFIRMED, 🟡).** All 16 use the
  default duration with no Undo. The ones that most want it: archiving a habit ("restore it from
  Archived habits"), deleting an unfinished bucket-list item (deletes instantly, no dialog, no undo),
  and shop purchases (one tap spends coins; fine at current prices, revisit if prices grow).
- **Title Case vs sentence case (CONFIRMED, UNRESOLVED).** DESIGN.md §10 says sentence case, but ~53
  of ~60 button/dialog labels are Title Case ("Get Started", "Create Account", "Add New Habit",
  "Mark Achieved"); only a few follow the doc ("Post proof", "Try again"). Either update DESIGN.md to
  match the code or sweep the labels. Left alone: it's a copy/brand call, and it touches most screens.
- **Calendar status leans on color (INFERRED, 🟡).** Perfect/Done/Missed differ by fill only (Perfect
  also gets a star). Add a second cue for Done/Missed (icon or glyph) for color-blind users.
- **No help or guidance anywhere (CONFIRMED, 🟡).** Nielsen #10 is the weakest heuristic: no FAQ,
  tips, or first-run tour. Overlaps "Onboarding tips needed" below. Jargon a first-timer will hit
  unexplained: "Minimum Threshold: Streak protection", "Adaptive XP", "Mark Day Safe", "Vacation Mode Freeze".
- **Settings is sparse and ordered oddly (CONFIRMED, 🟡).** Delete Account sits above Plan; missing
  change password, notification preferences, about/support. See also the Settings item under "Remaining layout defects".
- **No dark theme and no Dynamic Color (CONFIRMED, UNRESOLVED).** Android's Material guidance treats
  dark as a first-class scheme. A product call given the hand-drawn linen look; log it so it's a choice.
- **Text scaling at 1.3x was never rendered (UNRESOLVED).** Code looks safe (the bottom nav was already
  fixed for it and only one fixed-height text wrapper was found), but there's no emulator here to
  confirm. Worth one check on a real phone with Settings > Font size set to Large.
- **`moss` is still 2.4:1 as a text/icon-on-light color in a few spots (INFERRED, 🟡).** Mostly fixed;
  the `mossDark` token itself is only 4.1:1 on `linen`, so small `mossDark` text on the page background
  is borderline. Darkening the token is a palette change, so left for a decision.

**Found while building the intro/hints (2026-10-26)**
- **New accounts start with no habit categories (CONFIRMED, 🟡).** Adding one from Add Habit now works
  (see RESOLVED_LOG.md), but `onUserCreate` still seeds `habitCategories: []`. Seeding a few defaults
  (e.g. Health, Study, Finance, like the demo account) would mean a first habit needs no extra step;
  it's a Cloud Functions change plus a deploy, so left for you to decide.
- **Four more dialogs dispose their text controllers too early (CONFIRMED, 🟡).** Set a Password
  (`settings_screen.dart`), the change-email password prompt (`edit_profile_screen.dart`), and the
  Google account-link and Forgot Password prompts (`login_screen.dart`) call `dispose()` on their
  controllers right after `showDialog` returns, while the close animation is still drawing the
  field. It's the pattern fixed in `showNoriTextPrompt` and, for Delete Account (2026-10-26), in
  `DeleteAccountDialog`; it only asserts in debug builds. Fix by moving each dialog into a small
  StatefulWidget that owns its controllers.

**System status and feedback**
- **Nori's sprite and the Home vital rings don't show distress (CONFIRMED, 🟡).** At 0% on all three
  vitals the pet looks exactly as content as at 100%, and the rings are unlabeled icon circles (the
  percentage only reaches screen readers). The pet should read as hungry/dirty/sad before you tap.
  Sprite variants are an art problem (new frames per mood, for both forms); a visible number or
  low-vital tint on the ring is not.
- **Two separate notification inboxes (CONFIRMED, 🟡).** The bell on Habits opens
  `NotificationsScreen` (app/pet events); the bell on Social opens `SocialNotificationsScreen`
  (showed "5 unread" at the same moment Habits showed a dot). Users won't know which bell holds
  what. Decide whether to merge them or label them differently.

**Accessibility (screen reader)**
- **Unlabeled controls still left (CONFIRMED, 🟠).** From the rendered semantics tree: Home's pet
  stage (a 231×246 button with no label), Customization's accessory tiles (only "No accessory" has
  a label), the Shop category chips (exposed as unlabeled checkboxes), Habits' "Completed to bottom"
  switch (its text is a separate widget, not its label), and Calendar day cells (announce only "3",
  not "October 3, done").
- **Profile's Habit Breakdown icons and bars are nearly invisible (CONFIRMED, 🟡).** `_HabitStatRow`
  draws the icon in the habit's pastel color on a 16% tint of the same color, and the bar fills
  with that pastel on a `linen` track (linenAlt/sky habits basically disappear). Use the habit
  color as the badge fill with an ink icon, like `NoriIconBadge` everywhere else, and a readable bar fill.

**Consistency**
- **Naming drifts (CONFIRMED, 🟡).** "Log In" (Sign up, Welcome) vs "Sign In" (Login screen); the
  Shop button opens "Pet Boutique"; Customization's title is "Style Pet"; XP is a star in `XpPill`
  but a diamond on Profile's chip, and Profile shows the XP total twice (header pill + chip).
- **Three back-button styles (CONFIRMED, 🟡).** Plain arrow (Settings, Bucket List, Shop), circled
  arrow (Customization), circled X (Add Habit). Customization also centers its title where every
  other sub-screen left-aligns it.
- **Login and Sign up don't match (CONFIRMED, 🟡).** Login has Google sign-in, a password visibility
  toggle and placeholder-only fields; Sign up has labeled fields, no Google option and no visibility
  toggle. Sign up's hints ("Alex Human", "••••••••") read as already-filled values, especially the
  dots in the password fields.
- **Soft blur and gradients on Welcome (CONFIRMED, 🟡).** Two blurred color blobs behind the page and
  a blurred shadow under the mascot card go against DESIGN.md §5 ("no soft shadows, no gradients").
  Either intentional for the first impression (then note it in DESIGN.md) or remove.

**Flows**
- **"Go to Shop" from a pet vital opens the Hats tab (CONFIRMED, 🟡).** The care sheet says "Out of
  stock, visit the Shop", but the Shop opens on Hats, so you have to find Food & Care yourself.
  `ShopScreen` needs an initial-category parameter.
- **Owned shop items look disabled (CONFIRMED, 🟡).** "Sunglasses / Owned / Equip" renders faded
  with a washed-out Equip button, but Equip is active. Owned should look different from unavailable.
- **Customization is a dead end (CONFIRMED, 🟡).** It only lists owned accessories (just one for
  demo), with no link to the Shop, and leaving without "Save Look" silently drops the change.
- **Whole habit row toggles the claim (CONFIRMED, 🟡).** On Home/Habits a binary habit's entire tile
  is the claim target, so a tap meant to scroll or open the menu can claim it. Unclaim undoes it, so
  low risk, but there's no claim feedback to notice the mistake (see "No reward feedback on claim").
- **Social odds and ends (CONFIRMED, 🟡; Social is frontend-only).** "Nudge" on Friends is plain
  text with no button look; Add Friend's Search button sits disabled with no hint why; Post Proof
  promises "+50 XP", which nothing pays yet (INFERRED from "Social tab is frontend-only").
- **Calendar "Missed Days" uses a frowning face (CONFIRMED, 🟡).** Small, but it's the one guilt cue
  in an app built on encouragement. A neutral icon fits the voice in DESIGN.md §10 better.

### Code audit 2026-10-26: what the quick-win pass did not fix

Whole-codebase code-quality and security pass (backend: `functions/`, `firestore.rules`, the Dart
data layer; frontend: every screen and shared widget, code only, not UI/UX). Checked against the
OWASP Secure Coding checklist and Google Cloud's Architecture Framework. The fixes that were quick
and safe are in RESOLVED_LOG.md (same date); everything below is still open. Line numbers are as of
this pass.

**Security and backend**

- **Usernames are only kept consistent by the client (CONFIRMED, 🟠).** `firestore.rules` lets
  `users/{uid}.username` be set to any string, so it isn't tied to `/usernames` (a modified client
  could show someone else's handle once Social is real). `/usernames` doesn't check the doc id's
  length or characters, one uid can hold any number of names, and `usernameForUid` uses
  `.limit(1)`, so which name comes back is arbitrary if there are several. The app now writes the
  index and the profile in one transaction, but the rules don't require it. Fix shape: in the rules,
  require `exists(/databases/$(database)/documents/usernames/$(request.resource.data.username.lower()))`
  owned by the caller, plus a size/regex check on the doc id. Rules are hand-synced with the
  console, so this needs a deploy.
- **No App Check, budget alert, or API-key restriction (CONFIRMED, 🟠).** Any client holding the
  (public, committed) Firebase config can call every callable. `maxInstances: 10` now caps scale
  (see RESOLVED_LOG.md); App Check (`enforceAppCheck` on the callables), a billing budget alert, and
  restricting the API key to the Android app in the GCP console are the rest.
- **`careItemCountsOnlyDecreased` hard-codes the six item ids (CONFIRMED, 🟡).**
  `firestore.rules:16`. An inventory missing one key makes the rule error, which denies *every*
  inventory write including equipping; a seventh item would have no guard at all; counts have no
  `>= 0` floor. Worth reworking before the catalog grows.
- **`petCareCheck` won't scale and never stops (CONFIRMED, 🟡).** `functions/src/petCareCheck.ts`
  reads every pet and runs one transaction per user, one after another, and notifies abandoned
  accounts every day forever. Notifications can't be deleted, so that collection only grows. Fine
  at today's scale; batch the checks and skip accounts inactive for N days when it matters.
- **Client writes have no type or length validation in the rules (CONFIRMED, 🟡).** Name,
  `habitCategories`, notification `message`, habit/bucket text fields. Only affects the user's own
  data today; matters once other users can read it.
- **A sign-up killed between claiming the username and saving the profile (🟡, rare).** Startup
  now sends an account with *no* claimed username to finish sign-up, but one that claimed it and
  was then closed before the profile write leaves the profile's `username` empty until the next
  Edit Profile save.

**Need a decision (game design, not fixed on purpose)**

- **Unclaiming can keep adaptive XP at its maximum (CONFIRMED).** A day keeps its payout when
  un-claimed, but `claimHabit` counts only days that are *currently* claimed when computing the
  completion rate (`functions/src/claimHabit.ts:119`). Claiming and then un-claiming every day keeps
  the multiplier at the "struggling" max: about +38% XP per claim on a hard habit (36 vs 26), at the
  cost of the visible streak. Option: count days that paid (`rewardPaid`) instead.
- **Tomorrow can be claimed a day early (CONFIRMED).** `parseDayArgs` accepts any UTC offset up to
  +14h, so tomorrow's dayKey passes the "not in the future" check if the client claims a +14h
  offset. Each day still pays once; only the timing is off.
- **Achievements read only the last 90 days (CONFIRMED).** Every count-based achievement is
  capped by that window, so a long streak or a high total can't keep growing past it. The
  completion-count ones now top out at 50, well inside it (Steady Progress was removed and
  Dedicated trimmed to 10 / 25 / 50 on 2026-10-26), so nothing is unreachable today; a future
  bigger tier would need a Firestore `count()` query instead. Also: "On Track" checks every active
  habit rather than today's scheduled ones, and "Habit Architect" counts habits active today, not
  habits created.

**Data correctness**

- **Home never rolls over at midnight (CONFIRMED, 🟡).** With Home open past midnight it keeps
  showing yesterday's habits while new actions write to today. A resume/midnight reload fixes it.
- **Overlapping loads can show older data (CONFIRMED, 🟡).** Home (`_loadData` vs. action reloads),
  Profile, and the Social screens commit whichever load finishes last; Habits list's `_onReorder`
  commits its pre-request snapshot after the write. The Habits list date switch got a
  request-date check in this pass; the same pattern would cover the rest.
- **Some screens don't refresh what an action changed (CONFIRMED, 🟡).** Habits list refreshes the
  streak only after a paying claim (not after logging to a minimum or an unclaim), and returning
  from a habit delete doesn't reload XP/coins.
- **Mock repositories have drifted from the Firestore ones (CONFIRMED, 🟡).** The mocks only run
  signed out and in tests, but: mock binary claims compute the reward before marking complete
  (returns 0 XP), mock "today" ignores the schedule, mock habits have no `createdAt`, mock state
  doesn't roll over at midnight, mock bucket-list un-complete still takes the reward back, and mock
  pet decay truncates to whole minutes and resets its clock on every read.
- **Other small ones (CONFIRMED, 🟡).** Deleting a category's "keep at least one" check isn't
  transactional (two devices can delete down to zero). Customization lets you change the selection
  while a save is in flight, so "Look saved!" can describe the wrong accessory. The email
  verification banner only checks at startup. Nori+ ignores the selected plan (checkout always
  shows yearly; premium is mock). Bucket-list items get a fresh id per save attempt, so a save that
  times out but still commits, then is retried, creates a duplicate (Add Habit had the same issue,
  fixed).

**Efficiency (Firestore reads)**

- **Opening Notifications still recomputes everything (CONFIRMED, 🟡).** Mostly fixed 2026-10-26:
  the screen now paints the stored list straight away and the sync runs after, and the sync's reads
  run in parallel. What's left: `_sync` still reads the user and every achievement on each open.
  Options: only sync when something changed since the last sync.
- **Archived Habits runs one log query per archived habit (CONFIRMED, 🟡),** just to decide whether
  Delete is offered (`archived_habits_screen.dart:45`).
- **Every social write reloads every mounted social screen,** including covered routes and the
  hub, and each reload re-reads the user from Firestore. Accepted: Social is a showcase (see the
  scope note under "Social tab is frontend-only").

**Modularity and duplication: what's left after the 2026-10-26 clean-up (CONFIRMED, 🟡)**

Most of the duplication from this audit was merged (see RESOLVED_LOG.md). What remains is
deliberate or needs a decision:

- **Rules that live in more than one language.** Care-item and accessory prices
  (`firestore.rules`, `functions/src/shop.ts`, the Dart catalogs), `MAX_DELETABLE_ACTIVE_DAYS` (TS
  and Dart), and the pet decay rate (`kPetDecayPerHour` in Dart, `PET_DECAY_PER_HOUR` in
  `notifications.ts`) are each hand-synced, with a comment at every copy. One shared `catalog.json`
  isn't a quick win: `functions/` deploys on its own, so it can't import a file from the repo root,
  and the app would need it bundled as an asset too. Worth it only if the catalog grows.
- **Home keeps its own claim handler.** `HomeScreen._runClaim` is today-only, uses the plain
  `claimHabit` methods, and detects level-ups by diffing before/after state so a claim made on
  another tab still celebrates on switching back. `HabitDayActions` (Habits list, Calendar day
  sheet) celebrates from the claim result's flags instead. Merging them would change when Home
  celebrates, so it needs a decision first.
- **Spacing/size literals instead of `lib/theme/` tokens** in many shared widgets
  (`tactile_button`, `nori_choice_chip`, `nori_segmented_control`, `nori_bottom_nav`,
  `nori_bottom_sheet`, `section_header`, `habit_tile`, `habit_progress_card`, `pet_vital_ring`) and
  several screens. Not a mechanical swap: the literals (6, 10, 14, 18...) aren't token values, so
  each one changes the layout slightly. Do it with a visual check, per component.
- **Tap-ripple and selected-state cards** (`_TypeCard`, `NoriListRow`, `_PaymentOptionCard`, the
  Customization slots) still build their own shell on purpose: `NoriCard` doesn't fit a card that
  needs ink-splash feedback or a color/border animation.
- **Untestable function bodies.** `shop.ts` and `bucketList.ts` keep their logic inside `onCall`,
  so unlike the `runX` functions they can't be unit-tested (and have no tests).
  `habitTransaction.ts` has also become a general helper file. Not duplication, but it's why those
  two are untested.
- **Wiring.** `AppData` falls back to Mock repositories after sign-out, so a screen still open
  can quietly show seed data; `MockAchievementRepository` is the production achievements code
  despite its name.
- **Unused interface method.** `FirestoreInventoryRepository.consumeCareItem` is never called (the
  pet repository spends care items inside its own transaction); it stays only because the
  interface requires it. `_getDataWithRetry` in `FirestoreUserRepository` is a different loop from
  the shared write retry (it polls for a null doc).

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

### Achievements: 3 of 23 are "coming soon" placeholders, and none checked on real data (2026-10-06, updated 2026-10-26)

`achievement_repository.dart` defines 23 achievements. 20 compute real progress: 15 from the live
repositories (`AppData.bindToUser` points them at Firestore) and the 5 Social ones from mock social
data (see "Social tab is frontend-only"). 3 are `_soon` placeholders that never progress: Balanced
Life, Pet's Best Friend, Growing Family. Growing Family depends on multi-pet support, which is
vision-only, so it can stay a placeholder; Balanced Life and Pet's Best Friend look buildable from
existing data if wanted. No achievement has been checked against real Firestore data yet;
`demo@test.com` (30 seeded days) is a good account to do it on.

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
auto-equipped) in the inventory with no celebration or explanation. (Since 2026-10-26 Home at
least reloads the inventory after a paying claim, so the sunglasses show up on Nori right away.)

### functions/ has 10 transitive npm audit findings (2026-09-24, scaffold; recounted 2026-10-26)

`npm audit --omit=dev` now reports 10 (9 moderate, 1 high), all inside `firebase-admin`'s own
Google Cloud dependencies (`google-gax` → `gaxios`/`teeny-request` → `uuid`, `retry-request`).
Nori's functions never call those packages directly, so this is hygiene, not urgency. Fixing it
means the major upgrades `firebase-admin@14` and `firebase-functions@7`; now that the functions
have tests (`npm test`), that upgrade can be regression-checked instead of done blind.

### Accessories don't show on the evolved Nori (2026-10-26, deliberately left uncalibrated)

The evolved (winged) form now has real art — `nori_evolved/`, `NoriEvolvedSprite`, used by both
`EvolutionScreen` and `NoriRoomStage` (see docs/RESOLVED_LOG.md, 2026-10-26). Equipped accessories
are **not drawn on it**: `NoriRoomStage` only passes the accessory overlay to the baby's
`NoriBreathingSprite`, so once a pet evolves, an equipped hat or pair of glasses silently vanishes
from the home screen (it stays equipped and reappears if the stage ever goes back to baby). Every
accessory's position is calibrated per frame against the baby's eye-midpoint/head-top anchors
(`kNoriFrameAnchors`), and the evolved form has none, so showing them with the baby's numbers would
float them in the wrong place.

Decided to leave it like this for now rather than calibrate. What fixing it would take, if it's
picked up later:
- Extract eye-midpoint and head-top anchors for the 64 evolved frames (same blob-detection approach
  as the baby's, see `nori_frame_anchors.dart`) — the wings spread far past the body and the head
  has leaf horns instead of the baby's horns, so the head-top detector needs adjusting.
- Decide where hats sit relative to the leaf horns, and re-check every item's scale (the evolved
  head is smaller on the canvas than the baby's).
- Check what Customization's pet preview shows for an evolved pet — not looked at yet.
- Players can still buy accessories they can't see on an evolved Nori; fine for now, but worth a
  line in any "what's missing" write-up.

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
| Remaining un-migrated card classes | Reviewed 2026-10-26 with a scan for containers that are exactly a solid color + radius + ink border: the Nori+ comparison card, Settings' vacation card, Home's care sheet and coin pill, Customization's inventory panel, the four onboarding form cards, and the reward/streak/Soon pills now use `NoriCard`. What's left (`_TypeCard`, `_PlanCard`, Customization's slots, the payment options) has tap-ripple, selected-state or animated styling, so it stays bespoke. |

### Duplicated logic (2026-09-10 audit; formatting/date/coin-formula dedup done 2026-09-13, see docs/RESOLVED_LOG.md)

Fixed: thousands-separator formatting (now 1 helper, was actually 4 copies — a 4th,
undocumented one was found in `ProfileScreen` during re-verification), `_formatNum`,
the weekday/month name tables (was actually 7 tables across 4 files, not 5), the
duplicated coin-reward formula, and a newly-spotted duplicate id-generation expression
in `AddHabitScreen`/`BucketListScreen` — see docs/RESOLVED_LOG.md for details, including a real
`RangeError` bug the id-generation dedup surfaced and fixed.

Update 2026-10-26: the Habits list / Calendar day sheet half of this is merged into one mixin
(`HabitDayActions`, `lib/screens/habits/habit_day_actions.dart`), and the past-day edit fix now
lives in one place. Still open: `HomeScreen` keeps its own claim handling and its own
"refetch → compare stage → celebrate" sequence (`_loadData`, `_reloadUserAndPet`,
`_celebrateChanges`) on purpose; see "Code audit 2026-10-26" for why merging it needs a decision.

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

Update 2026-10-26: tests exist now (`flutter test`: habit JSON/archive, pet care, social; `npm test`
in `functions/`: rewards, XP curve, adaptive XP, request parsing, notifications, seed plan, 42 in
all). Still untested: `shop.ts`, `bucketList.ts`, `deleteHabit`/`deleteAccount`, every transaction
path, and the Firestore repositories. The original list, some of it now covered: (1)
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

**Scope (2026-10-26): there is no social backend in this MVP.** The tab is a showcase of how
Social would look, running on `MockSocialRepository`, so the mock bugs listed below and in "Code
audit 2026-10-26" are accepted and will not be fixed. The notes are kept so that whoever builds
the real thing later doesn't copy them over.

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

Mock behavior bugs found in the 2026-10-26 code audit, worth knowing before the mock is copied
into a real implementation (all CONFIRMED in `mock_social_repository.dart`): signing out and into
another account in the same session keeps the first account's posts, circles, competitions and
privacy settings (`accountChanged` only clears the cached profile); a profile read that fails is
cached as if it succeeded, so screens show the seed identity instead of a retry; friend codes from
`getInviteInfo` can't be searched; a removed friend's posts stay in the feed; "Show me on
leaderboards" is ignored; competitions never move from Active once `endsAt` passes, proof can be
submitted before a competition starts, and `submittedToday` never resets; blocking someone leaves
their request notification (with a working Accept) and their circle memberships. Screens:
reporting a post from its detail screen leaves the deleted post on screen, and Create Competition
accepts a target that can't be reached in the chosen duration.

### First-run help: what's still missing after the intro cards and hints (2026-10-26)

The intro cards and one-time hints shipped (docs/RESOLVED_LOG.md). Left: the Add Habit terms that
still lack a plain-language explanation, "Mark Day Safe" on limit habits, and any hint for Home (kept
off on purpose, it's already dense). A hint is one `Tip` value plus one `OneTimeHint` if wanted later.

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
