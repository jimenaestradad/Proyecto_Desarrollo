# Nori — Resolved Log

Trimmed historical fix log for Nori, split out of `docs/KNOWN_ISSUES.md` on 2026-09-16 to keep the working file scannable. Full narrative detail from before the split was intentionally condensed; this log favors terse entries going forward.

### 2026-10-26 — slow screens: parallel reads, no wasted reads on bucket-list taps

- **Achievements, Profile and the notification sync fetch in parallel.** They awaited ~10 independent
  Firestore reads one after another (including the same 90-day habit range twice, now shared).
  `getAchievementsByCategory`, Profile's `_fetchData` and Achievements' user+achievements load use
  record `.wait`.
- **Notifications paints stored items first** (`getNotifications(sync: false)`), then syncs.
- **Ticking a bucket-list goal does less:** it no longer reads the user (and walks the streak) just
  to call the pet's `syncEvolution`, which is a no-op for the real pet. A progress bar shows while
  the Cloud Function runs. The function call itself (cold start) is the remaining wait.

### 2026-10-26 — evolved Nori art on the evolution screen

- **The evolution celebration shows the winged Nori** (`NoriEvolvedSprite`, 64 cut-out frames in
  `assets/images/nori_evolved/`, ~5.7MB) instead of the baby sprite. The source clip doesn't loop,
  so the frames are a trimmed stretch (source frames 51–177) whose wrap reads as a wing lift. The
  wings overflow the 160px badge circle sideways.
- **The home room stage shows it too** for any evolved pet (it was still the scaled-up baby with a
  mustard aura; the aura is removed). Equipped accessories are hidden on the evolved form until it
  has anchors — see KNOWN_ISSUES.

### 2026-10-26 — pre-ship cleanup: dead freeze toggle, hard-coded pet line, Delete Account dialog

- **"Allow Vacation Mode Freeze" is gone from Add Habit.** Nothing read it and per-habit pause is
  out of MVP scope (the global Vacation Mode in Settings is unaffected). `Habit.allowVacationFreeze`
  stays in the model and an existing habit's stored value is carried through edits.
- **Habits no longer claims "Your pet is happy"** regardless of the pet's vitals; today's line is
  just "Keep up the good work!".
- **Delete Account's dialog is its own widget** (`DeleteAccountDialog`) that owns its two text
  controllers, instead of the caller disposing them while the close animation ran. Cancel also
  used to show "The username didn't match", and now closes quietly. Four widget tests cover it.

### 2026-10-26 — pre-ship quick fixes: bucket-list caps, duplicate achievements, playwright output

- **Bucket-list rewards can't promise more than they pay.** The XP and coin fields take digits only,
  show "Up to 500" / "Up to 250", and clamp on save; goals already saved with a bigger number show
  the capped amount (`BucketListItem.maxXpReward` / `maxCoinReward`, matching the server's caps).
  The mock's debug-only `dev-level-up` item (3000 XP) is untouched on purpose.
- **Duplicate achievements removed.** Steady Progress (best single habit: 10 / 25 / 50) counted
  nearly the same thing as the Milestones series (all habits combined), so Steady Progress I-III
  and Dedicated III (500, unreachable in the 90-day window) are gone and the series is now Getting
  Started 10, Dedicated I 25, Dedicated II 50. 27 achievements became 23.
- **`.playwright-mcp/` is git-ignored and gone from history.** Its 19 files were only in the tip
  commit of `valevasqc-dev`, which was amended (now `a445a89`); a local backup branch
  `backup/before-playwright-removal` still holds the old commit. The remote still has the old
  commit until `valevasqc-dev` is force-pushed.

### 2026-10-26 — onboarding recovery, time-zone-proof log queries, delete-account re-login

Four items from the code audit.
- **Sign-up resumes instead of dead-ending.** The screen now remembers the created account, the
  email it used and the claimed username as each step succeeds, so after any later failure
  ("Create Account" again) it continues from the failed step instead of calling `signUp` again
  ("email already in use"). `UsernameRepository.claim` is a no-op when the same user already holds
  the name, `updateDisplayName` during sign-up is best-effort, and the "doc not provisioned yet"
  retry now waits about 4s instead of 2s.
- **Interrupted sign-up is picked up at startup.** A signed-in account with no claimed username
  opens `FinishSignUpScreen` (choose username, save profile, name pet) instead of Home. If the
  check can't be made, it opens Home as before. It costs one small read at launch.
- **Logs can't vanish after a time-zone change.** `logsInRange` (and the seed script's existing-log
  query) filter on the `dayKey` string instead of the device-local-midnight `date` Timestamp.
- **Deleting the account needs a recent login.** The `deleteAccount` function rejects a session
  that signed in more than 5 minutes ago (`requireRecentLogin`, tested), and the app re-authenticates
  first: Settings' dialog asks for the password, or opens Google again for a Google-only account.
  **The server check only applies once `functions` is redeployed; the app works either way.**

Social findings were not touched: the Social tab is a showcase on mock data with no backend in this
MVP (FEATURES.md §10).

### 2026-10-26 — remaining duplication merged (screens, data layer, functions)

Second half of the duplication clean-up from the code audit.
- **Screens:**
  - The claim / un-claim / log / edit-progress handlers copied between the Habits list and the
    Calendar day sheet are the `HabitDayActions` mixin.
  - Level Up and Evolution share `CelebrationScreen` (the two screens render pixel-for-pixel as
    before, checked against the originals).
  - Sign Up and Choose Username share `UsernameAvailability`.
  - Twelve hand-built bordered boxes use `NoriCard`: the Nori+ comparison, Settings' vacation card,
    Home's care sheet and coin pill, Customization's inventory panel, four onboarding form cards,
    and the reward/streak/Soon pills.
  - Customization's pet preview is the shared `NoriAccessoryPreview` (layout checked identical for
    all six accessories).
  - Social's unread dot is `CircularIconButton.showDot`. This one is a deliberate small visual
    change: the dot is now `terracotta` like the Habits bell, since DESIGN.md reserves the
    `Dark` variants for text and icons.
- **Data layer:**
  - Both calendar repositories' day-status rule, streak rule, month assembly and per-habit stats
    are shared functions (`calendarDayStatus`, `streakStep`, `buildMonthStats`,
    `buildHabitStats`), so the mock and Firestore calendars can't disagree.
  - The two icon/color registries are one (`IconRegistry`/`ColorRegistry`, with `tryKeyFor` and
    shared defaults).
  - Pet decay is `applyPetDecay`, shared by both pet repositories.
  - The signed-in-uid lookup is `requireSignedInUid`.
- **Functions:** one `docRefs.ts` builds the per-user paths and the `{dayKey}_{habitId}` log id
  that used to be spelled out in nine places.

Not behavior changes, apart from the dot color. New tests: 12 for the calendar rules, 4 for the
registries, 3 for pet decay, 6 for the preview layout, 2 for the function paths.

### 2026-10-26 — Firestore-side duplication merged (follow-up to the code audit)

The "definitions + logs → hydrated habits" loop was written four times (`getTodayHabits`,
`getHabitsForDate`, `getHabitsForRange`, and the calendar repository's `_scheduledFor`); it is now
`hydrateDay`/`hydrateScheduled` in `habit_repository.dart`, and `_scheduledFor` is gone.
`logProgressForDate` and `setProgressForDate` shared everything but how the new value is computed;
both now go through one `_writeProgress` with the clamp in `clampProgress`. The 5 × 400ms
"doc not provisioned yet" retry, copied in `updateProfile` and `renamePet`, is
`retryWhileProvisioning` (`lib/utils/provisioning_retry.dart`). One small behavior change:
logging progress on a habit with no target now floors at 0, like setting it always did. New tests
cover the three helpers (`test/data/habit_hydration_test.dart`,
`test/utils/provisioning_retry_test.dart`); the transaction itself is still untested because there
is no fake Firestore in the project.

### 2026-10-26 — full code audit (backend + frontend): quick wins

Code-quality/security pass over the whole codebase; what's still open is in KNOWN_ISSUES.md under
"Code audit 2026-10-26". **Firestore reads:** the streak walk fetched 400 days of logs on every
call and now fetches 45-day chunks only as far back as the streak reaches. A new
`CalendarRepository.getCurrentStreak()` stops `getCurrentUser()`, achievements and Profile from
building a whole month grid just for the streak. Mark-all-read no longer re-runs the notification
sync, and pet reads no longer write. **Bugs:**
- Logging in overwrote the Firestore name with the Auth display name, reverting every Edit
  Profile name change.
- The vacation toggle didn't await its write.
- A pet read could overwrite a concurrent care action.
- Changing days quickly on Habits could show (and act on) the wrong day.
- Deleting an un-completed bucket item that had paid out took the reward back without the
  confirmation.
- Day loops skipped or repeated a date across DST (new `addDays`).
- Add Habit crashed on empty categories and on out-of-range picker dates, and accepted NaN, a
  minimum ≥ target, or a custom schedule with no days.
- The progress dialog saved unparseable text as 0.
- An exceeded limit habit could be claimed from a Home row.
- The client offered Delete on habits the server would refuse.
- Renaming a category onto an existing name created a duplicate that crashed Add Habit.
- Archived Habits' back arrow dropped its "changed" result.
- An unknown icon/color key failed the whole habit list.
- The onboarding `minHeight` could go negative.
- The Add Password dialog's keyboard submit skipped the match check.
- Home didn't show the first-completion sunglasses until a full reload.
- Duration cards showed `:00` seconds.
- A retried Add Habit save could duplicate the habit.
- A stale social profile load could land on the next account.

**Security:** login and password-reset messages no longer reveal whether an email has an account.
A username change writes `/usernames` and the profile in one transaction. An expired session gets
its own message instead of "couldn't reach the server". **Functions:** `maxInstances: 10` global
cap; Node 20 (end of life upstream) → 22; `FIRST_COMPLETION_GIFT` shared from `rewards.ts`.
**Dedup:** `ordinal()`, `relativeTimeLabel()` and the server-unreachable message each have one
copy now. The functions changes take effect on the next `firebase deploy --only functions`; nothing
was deployed.

### 2026-10-26 — first-run help: intro cards and one-time hints

New accounts see a three-card intro (`IntroScreen`) after naming their pet, and Habits and Calendar
each show one dismissible hint card the first time (`OneTimeHint`). Both are remembered per account
on the device (`TipsStore`, new `shared_preferences` dependency) and replayable from Settings > Help.
Add Habit's private `_InfoBanner` became the shared `NoriInfoBanner`; no permanent helper text was
added. Covers the old "Onboarding tips needed" backlog item. Tests: `tips_store_test`,
`one_time_hint_test`, `intro_screen_test`.

### 2026-10-26 — new accounts had no way to create a habit category

`onUserCreate` seeds `habitCategories: []`, so a new user's Category dropdown on Add Habit was empty
(blank field, habit saved with no category). The dropdown now says "Choose or add a category" and ends
with an "Add Category" entry that opens the same prompt as Settings, saves it and selects it. The
prompt (`showNoriTextPrompt`) is shared with Settings and owns its text controller, which fixes
the old Settings version disposing it while the dialog was still animating closed. Covered by
`add_habit_categories_test`.

### 2026-10-26 — full-app UX/UI audit: contrast, labels, calendar, welcome (easy wins)

Whole-app audit (Nielsen's 10 + WCAG/Material checks) at 412×915; the complex findings are in
KNOWN_ISSUES.md under "UX/UI audit 2026-10-26". Fixed: (1) the theme had no `textButtonTheme`, so
every TextButton ("Forgot Password?", "See all", "Resend", "Mark all as read"...) fell back to
`moss` at 2.4–2.8:1; it's now `mossDark` as DESIGN.md §7 already said. (2) Profile stat values and
Easiest/Most Missed tags, and notification category labels, use darker text variants instead of fill
colors; the notification CTA lightens its fill so ink text clears 4.5:1. (3) Unlabeled icon buttons
now have tooltips (shared back button, month/day arrows, Add Habit close, profile/photo edit), and
each habit/bucket "More" menu names its item. (4) Calendar: upcoming days no longer look identical to
missed days (transparent + faint outline) and the legend gains Today/Upcoming. (5) Add Habit's
tracking-type and custom-day pickers use the standard mossLight + thick-border selection, and type
descriptions no longer cut off at 2 lines. (6) Habit cards no longer render a dangling "Duration ·"
when a habit has no category. (7) Welcome has a "Log In" link (returning users had to go through the
sign-up form). (8) Nori's breathing loop holds on frame 0 when the OS "remove animations" setting is on.

### 2026-10-26 — live Cloud Functions no longer ahead of git

Every function file deployed since 2026-10-04 (`deleteAccount`, `bucketList`, `shop`,
`onUserCreate`, `petCareCheck`, `adaptiveXp`, notifications) is now committed on
`valevasqc-dev` and redeployed from it, so a deploy from a checkout of that branch no longer
deletes live functions. One `purchaseCareItem` rebuild expired in Cloud Build's queue (Google-side);
the previous revision kept serving.

### 2026-10-26 — account settings: delete account + real login-email change

Settings has a Delete Account row (type your username to confirm) that calls the new
`deleteAccount` Cloud Function: deletes `/usernames` entries, the `/users/{uid}` tree, then the
Auth user. Verified live on throwaway accounts. Edit Profile's email field now changes the login
email (`verifyBeforeUpdateEmail` after re-entering the password) instead of only the Firestore
copy, and is read-only for Google-only accounts.

### 2026-10-26 — claim → spend → unclaim → re-claim no longer mints coins

Each habit-day and bucket-list item now pays once. Unclaim/uncomplete keep the stored
`awardedXp`/`awardedCoins` and take nothing back, and a re-claim of something that already paid
pays nothing (`rewardPaid` in `functions/src/habitTransaction.ts`). Deletes still reverse every
stored payout and are rejected if the coins were spent, and `firestore.rules` no longer lets the
client directly delete a bucket item that ever paid. The habit card's reward pill shows the
day's paid amount once there is one. Mock repository follows the same rule. Unit-tested.

### 2026-10-26 — "ClientID not set" assertion on every web login

`FirebaseAuthRepository` always constructed `GoogleSignIn()`. On web that starts an init that needs a web client ID, so every first `AppData.auth` access (e.g. pressing Log In) logged a red `google_sign_in_web` assertion in debug. It was harmless, because the init isn't awaited and web Google sign-in uses Firebase's `signInWithPopup` anyway, but it looked like the cause of login failures. The plugin is now only constructed off web. `flutter analyze` clean.

### 2026-10-21 — Notifications screen shows real, per-account notifications

The screen used to show 4 hardcoded notifications for every account, and "Mark all as read" only lasted until a restart. It now reads `/users/{uid}/notifications`. `claimHabit` and `completeBucketListItem` write level-up, evolution and first-gift notifications inside their transactions. A new hourly scheduled function, `petCareCheck`, writes "pet needs you". The app adds streak-milestone and achievement notifications, since only it computes those (BACKEND.md, "In-app notifications"). Read state persists, and the bell on Habits shows a live unread dot. This also closes the 2026-09-15 "Do it now goes nowhere" issue: pet notifications have a "Take care" button that switches to the Home tab (the screen pops with a `NotificationAction`, and `NoriShell` passes `HabitsListScreen` an `onOpenHome`). Unit-tested (`functions/src/notifications.test.ts`) and `flutter analyze` clean. Needs a functions + rules deploy before it works live.

### 2026-10-21 — Social tab: placeholder mock replaced with a full frontend on mock data

The 2026-09-10 `SocialScreen` (static feed/leaderboard/competition/circle cards behind a "Preview only" banner, every button a "Coming soon" snackbar) is now a navigable ~25-screen frontend backed by an in-memory `SocialRepository` (`AppData.social`): hub, feed/post/proof composer, friends/add/invite/profile/pet visit, leaderboard, competitions (create wizard, detail, invite, results, proof), circles, friend streaks, notifications, badges, privacy/blocking. Layouts follow two Stitch exports but are rebuilt on our tokens and shared widgets (new: choice chip, segmented control, empty state, bottom sheet, post/reaction/proof widgets) and documented in the new `docs/DESIGN.md`. Frontend only: no new backend, rules shown are mock placeholders. Later the same day "you" was wired to the signed-in account (reads only, existing repositories): real name/username/level/XP/streak/pet, last-7-days XP on the leaderboard, and today's completed habits in the proof composer; friends and everything else stay seeded. Also closes the 2026-09-10 "Social should read like a dashboard" note. Verified with `flutter analyze` (clean for social) and a release web build rendered at 412×915; not run on a device.

### 2026-10-06 — adaptive XP built (the UI promised it, nothing adjusted it)

`adaptiveMultiplier` existed and was applied, but nothing ever changed it from 1.0, while the add-habit form promised it adapted. `claimHabit` now recomputes it on every claim from the habit's last 14 days (`functions/src/adaptiveXp.ts`): scheduled, non-vacation days completed at or below 40% pay the difficulty's max, at or above 90% its min, linear in between, 1.0× with fewer than 5 days of history. Per-difficulty caps (easy 0.85–1.3, medium 0.8–1.2, hard 0.87–1.2 → 9–13 / 16–24 / 26–36 XP) keep tiers from overlapping, per valevasqc's ask that hard habits not break the system and easy ones stay rewarding, and are narrow enough that more consistency always earns more XP per day (an earlier wider draft didn't; a test now enforces it). Coins are unaffected. Recomputed, not stepped, so unclaim/re-claim can't ratchet it; the app no longer writes the field. Needs a functions deploy to go live.

### 2026-10-06 — using a care item could spend it without helping the pet

Home spent the item in one transaction on `inventory/main`, then raised the stat in a second one on `pet/main`. If the second failed, or the user left Home in between (a `mounted` check sat between them), the item was gone and the pet got nothing. `PetRepository.useCareItem(item)` now does both in one Firestore transaction across the two docs and returns false, changing nothing, when out of stock. It replaces `feed`/`groom`/`play`, whose only caller was that flow. Tested on the mock (`test/data/pet_care_test.dart`); the Firestore path stays within the existing rules (counts only decrease, stat fields are client-writable) but hasn't been run live yet.

### 2026-10-05 — stale "calendar makes ~430 sequential reads" entry closed

The 2026-09-10 audit flagged `MockCalendarRepository` awaiting one habit read per day. The live app uses `FirestoreCalendarRepository`, which reads a whole range in one `logsInRange` query (and, since 2026-09-30, `getHabitsForRange` for Achievements/Profile), so the cost never reached Firestore. The mock still walks per day, which is harmless in memory. Removed from KNOWN_ISSUES.

### 2026-10-05 — add-habit form rejected valid input with the wrong message

Found by valevasqc creating "drink 1000 ml daily". The Ideal Target field's placeholder (`1000`) read as a pre-filled value, so the field was left empty. Typing 250 or 25% into Quick-Log then failed with "Enter a target greater than 0", which doesn't say which field it means. Separately, Quick-Log's own hint says "25% of target", but typing `25%` failed the number parse and was silently saved as blank (the default), as was any unparseable minimum threshold. Now the placeholders read `e.g. 1000`/`e.g. 750`, the error names the Ideal Target field, Quick-Log accepts `25%` (stored as the absolute amount), and an unparseable Quick-Log or minimum value shows an error instead of being dropped.

### 2026-09-30 — habits can be archived, restored, and (with almost no history) deleted

Habits had an unused `archived` flag that, once set, would have hidden the habit from *every* date, erasing its past days. Archiving now records `archivedRanges`, and `Habit.isActiveOn` skips only the days inside them. The habit leaves Home and the Habits list from today, keeps its history, can be restored from the new Archived Habits screen, and the archived stretch never counts as missed. `claimHabit` enforces the same rule. A habit with at most 2 active days can be deleted through the new `deleteHabit` Cloud Function, which takes back what its claims paid. Hard delete for habits with real history is deferred (OPEN_DECISIONS.md). Deployed 2026-10-04.

### 2026-09-30 — ended habits no longer vanish from past calendar days

`FirestoreCalendarRepository` took its habit list from `getTodayHabits()`, which leaves out any habit not active today. So once a habit's `endDate` passed, it disappeared from every past calendar day, streak and stat it had been part of. The calendar now uses every definition (`fetchAllDefinitions`) and lets `isActiveOn` decide per day. Today is hydrated from `habitLogs` like any other day.

### 2026-09-30 — Achievements and Profile no longer make ~200 sequential Firestore reads

`MockAchievementRepository` (which computes real achievements from the real repositories, despite the name) called `getHabitsForDate` once per day across a 90-day window, twice: about 200 sequential round trips per Achievements or Profile load, and enough to hit the new 20s screen timeout. The new `HabitRepository.getHabitsForRange` fetches a whole window in two queries. Achievements and Profile's weekly completion now use it.

### 2026-09-30 — unlimited bucket-list items accepted as honor system

The 2026-09-28 audit flagged that nothing limits how many maxed-out bucket-list items someone can create and complete. Decided by valevasqc: no item-count cap, it's a self-reward feature that relies on the user's honesty. The per-item 500 XP / 250 coin cap stays. Recorded in BACKEND.md next to that cap.

### 2026-09-30 — bucket-list rewards now evolve the pet; deleting a completed item takes its reward back

`completeBucketListItem`/`uncompleteBucketListItem` changed the level without touching `pet.stage`. The client can't write `stage`, and `FirestorePetRepository.syncEvolution` does nothing on purpose, so a bucket-list reward could cross level 7 without evolving the pet. Both now call the same `syncPetStage` helper as `claimHabit`. Deleting a completed item used to keep its reward. The new `deleteBucketListItem` reverses the stored payout and deletes in one transaction, `firestore.rules` now rejects a direct client delete of a completed item, and the app asks for confirmation first. Deployed 2026-10-04.

### 2026-09-30 — screens no longer hang or fail silently when Firestore/Cloud Functions fail

Every screen that awaits a repository now goes through one shared helper, `RemoteLoadState` (`lib/utils/remote_errors.dart`). It has `guardedLoad` for loads and `guardedAction` for user actions, both with a 20s timeout. If a screen's first load fails, it shows `LoadErrorView` (a message plus "Try again") instead of spinning forever. If a reload or action fails, the screen keeps its current data and shows a snackbar. Level-up/evolution celebrations now run after the guarded block, never inside it, because the dialog can stay open longer than the timeout. `main.dart` also finally turns off Firestore offline persistence, as BACKEND.md's "Online only" decision required: before, offline writes queued silently instead of failing.

### 2026-09-28 — shop items could be made free; bucket-list NaN; functions cleanup

`purchaseCareItem`/`purchaseAccessory` looked items up with a plain `catalog[id]`, so an id like `"constructor"` matched an inherited key, its price was undefined, the coin check passed against NaN, and `coins` was saved as NaN — making every later purchase free. They now require an own catalog key. `completeBucketListItem` read client-writable `xpReward`/`coinReward` with `Number()`, which turned a string into NaN past both caps; it now uses `asNumber` and rounds. Both bucket-list functions now use the shared `readLevelState`/`levelFields` helpers instead of hand-built copies, `onUserCreate` uses `create()` so a duplicate trigger can't reset an account, and the server's dead 75% `min` reward tier was removed.

### 2026-09-28 — minimum threshold now keeps streaks

Complete always snaps to the target, so the minimum threshold could never pay a partial reward and did nothing. It now keeps the streak instead (FEATURES.md §3): new `Habit.keptStreak` (claimed, or logged to the minimum) drives both calendar streak walks, the "missed" calendar status ("perfect" still needs every habit claimed), and Rising Again's missed-day check. The Not All or Nothing achievement was unreachable for the same reason and now checks unclaimed days too. Partial reward after the day ends logged as a future idea.

### 2026-09-28 — two separate functions/ folders were silently deleting each other's deploys

Valeria's and Jimena's branches each scaffolded their own `functions/` directory, both deploying to the same Cloud Functions codebase on `nori-pet`. A plain `firebase deploy --only functions` from either one deletes any live function not present in that folder's `index.ts`, since Firebase treats a codebase's local source as the full desired state. This happened for real: Jimena's `onUserCreate` was deleted by a deploy run from Valeria's folder (surfaced as an interactive CLI prompt — "found in your project but not in your local source, delete?" — accidentally confirmed). Redeployed from Jimena's branch via a temporary worktree checkout. Fixed properly by merging both branches so `functions/src/index.ts` exports all 7 functions from one shared codebase; a future deploy from that shared folder can no longer drop the other side's functions. Until Jimena's branch and Valeria's are both merged into whatever branch actually gets deployed from, this risk returns — deploy with `--only functions:<name>,...` naming specific functions if working from an unmerged branch.

### 2026-09-28 — claim Cloud Functions: impossible dayKeys, ended habits, duplicate endpoint

Audit of `functions/`. `parseDayArgs` accepted impossible dates (`2025-13-01`, `2026-02-31`) because `Date.UTC` rolls them over, so one real day could be claimed again under every alias by calling the callable directly; it now requires an exact round-trip. `claimHabit` now rejects days outside the habit's `startDate`/`endDate`, and a new `Habit.isActiveOn` hides ended habits from today's list (mock + Firestore) — the window acts as archival, `archived` isn't flipped. The `setHabitCompleted` callable was removed as a pure dispatcher over claim/unclaim; BACKEND.md's result shape corrected (`changed`, not `alreadyClaimed`).

### 2026-09-24 — Firestore habit state now rolls over correctly at midnight

`FirestoreHabitRepository` previously stored today's live state (`currentValue`/`isCompletedToday`/`lastAwardedXp`/`lastAwardedCoins`) directly on the habit doc, so it didn't reset at the calendar boundary — logged 2026-09-23 as a 🔴 critical bug. Habit docs are now pure definitions; every day's state, today included, lives in `habitLogs`, keyed by date. Also fixed in the same pass: `Habit.createdAt` gives `isScheduledOn` an implicit lower bound so a brand-new habit no longer counts as "missed" on days before it existed, and habit-definition queries now filter `archived == false` in memory. `firestore.rules` updated to match — the habit doc's `create` rule no longer guards Cloud-Function-only fields that don't live on that doc anymore.

### 2026-09-16 — pet evolution didn't revert when a claim was undone

`PetRepository.syncEvolution` only promoted at the evolution threshold, so undoing a claim could lower the level without demoting the pet. It now handles both directions; celebration checks at all call sites only fire for a forward stage change, so de-evolution remains silent.

### 2026-09-16 — 4th achievement crest, default avatar art, pet close-up on onboarding, Habits h1, mock user renamed

Added First Step crest art, a tightly cropped illustrated default avatar, pet close-up onboarding art, the Habits title, and the Hannah Walker demo identity; removed the redundant Habits-header Shop shortcut. Named social users now use deterministic initials/color avatars so the default signed-in avatar is not repeated, and that opaque child needs an explicit `ClipOval` on Flutter web because a parent circular decoration does not reliably clip it.

### 2026-09-16 — full-codebase `/code-review` pass (8 finder angles) + 3 fixes it surfaced

Profile achievement previews now handle `comingSoon`, bucket-list edits preserve existing rewards when fields are cleared, and progress-bar ticks use the same inset track width as fills. The review also reconfirmed that Complete intentionally jumps a habit to 100% without a minimum-progress gate; do not reintroduce that false-positive "fix."

### 2026-09-15/16 — pre-release audit continued: Vacation Mode, a11y, naming, progress-bar clip, dead code

Vacation Mode now records date ranges and makes frozen days neutral for streak calculations; it intentionally does not pause elapsed-time pet decay. Bottom navigation now grows with text scale, Calendar uses its own title, `ProgressBarPill` clips its fill within the border inset, and unused care-item/stat APIs were removed; Flutter container clipping is outer-edge clipping, so the fill requires its own inset `ClipRRect`.

### 2026-09-15 — pre-release audit: 6 quick-win fixes (sign-up identity, purchase race, validation, copy, off-by-one, emoji)

Sign-up updates the active demo identity, shop purchases have a shared in-flight guard, and habit targets must be greater than zero to avoid quick-log clamp failures. End-date copy now describes its real hide-only behavior, achievement history is truly 90 days, and the Social emoji literal was removed.

### 2026-09-15 — Achievement icons too small, Profile preview missing descriptions, paw-icon logo placeholder, calendar stat cards too airy

Achievement cards and Profile previews use larger badges, Profile cards show descriptions, and Calendar stat cards use a denser horizontal layout. Login and Sign Up replaced the generic paw placeholder with the app logo.

### 2026-09-15 — Nori Plus moved from Profile to Settings

Nori Plus moved from Profile’s Explore card to a Settings Plan section, while Profile no longer navigates there. The shared interactive row was extracted as `NoriListRow` to avoid retaining two copies.

### 2026-09-15 — Achievements got custom crest art for 3 of the 18 badges + a rename

Custom crest images were wired for Habit Architect, On Track, and Perfect Week through an optional `Achievement.imageAsset`, with the existing icon fallback retained. Dapper Debut was renamed Shopaholic; the unmatched Habit Hero source remains intentionally unwired.

### 2026-09-15 — Habit Statistics went deeper: per-habit "easiest / most missed" breakdown

Profile now shows per-habit completion rates over a rolling 30-day window, sorted easiest first with extreme tags when comparable. `CalendarRepository.getHabitStats` only includes habits scheduled in that window, avoiding misleading sparse calendar-month data.

### 2026-09-15 — Added a level-up celebration (the other half of "no reward feedback")

Added `LevelUpScreen`/`showLevelUpCelebration` and reused the extracted `ConfettiRing`; all reward paths compare levels before and after reload. Evolution takes priority if both thresholds are crossed so users do not receive stacked full-screen celebrations; short default widget-test viewports overflow like the pre-existing Evolution screen and are not representative of phone layout.

### 2026-09-15 — App logo wired up (Android launcher icon + web favicon/PWA icons)

Prepared `app_logo.png`, configured `flutter_launcher_icons`, and regenerated Android launcher plus web favicon/PWA icons and manifest colors. The source was cropped rather than color-threshold cleaned because thresholding removed antialiased artwork shadows.

### 2026-09-15 — Bucket list items weren't editable (add/delete only)

Bucket-list menus now open a prefilled edit dialog that updates with `copyWith`, preserving id and completion state rather than creating a new item. Existing values are initialized in `initState`, since accessing `widget` from State field initializers is unsafe.

### 2026-09-15 — Achievements wired to real (mock) data instead of hardcoded progress

`MockAchievementRepository` now computes progress/status from habit, calendar, bucket-list, pet, and inventory mock data; unsupported features use a distinct `comingSoon` state. Rising Again remains an approximation because no explicit per-habit streak-break event is stored.

### 2026-09-15 — Profile screen was display-only (no edit capability)

Added `EditProfileScreen` and `UserRepository.updateProfile` for name, username, and email, with `NoriUser.copyWith` supporting those fields. The reusable labeled sign-up field became `NoriTextField`; photo editing remains intentionally unimplemented.

### 2026-09-15 — Achievements list revamped: real content, "a few unlocked, a few locked"

Replaced the placeholder list with 24 categorized achievements and extended category styling. Habit Architect is one three-habit achievement rather than separate first/three-habit tiers; icon visual polish remained a separate open item.

### 2026-09-15 — scroll under Chrome DevTools device toolbar confirmed fixed

Confirmed the existing `AppScrollBehavior` wired into `MaterialApp` had already fixed device-toolbar scrolling. No further code change was needed.

### 2026-09-15 — achievements dead space, two overflow gaps, and Profile nav trim

Tightened achievement card spacing, ellipsized habit subtitles, allowed two-line tracking-type descriptions, and removed Profile Appearance and Shop navigation rows. The type-card row uses stretch layout, so allowing two lines does not create uneven card heights.

### 2026-09-15 — secondary-text contrast, touch targets, and screen-reader semantics gaps

Darkened `inkFaint`, raised undersized interactive controls to 48dp, and added semantics for navigation, checkboxes, progress, and unread state. `inkMuted` was not part of this change and should not be assumed fixed by the token update.

### 2026-09-15 — "tapping the pet opens Customization, not care" was never a bug

Confirmed tapping Nori intentionally opens Customization; care actions belong on the vital rings. Removed the false-positive open finding without changing code.

### 2026-09-14 — equipped accessory wasn't rendered anywhere (predated the accessory-art feature)

Accessory art now renders in `NoriRoomStage` and the Customization preview. Remaining placement calibration is tracked separately.

### 2026-09-14 — Shop's Food & Care category was thin (three items, one per stat)

Added a second care-item tier for each stat and let Home users choose an owned item rather than consuming a generic one. Pricing/tiering remains placeholder economy work.

### 2026-09-14 — Home's Shop shortcut used a different icon than every other Shop entry point

Home’s Shop shortcut now uses `Icons.shopping_bag`, matching the other Shop entry points. The prior `storefront` icon was an inconsistent duplicate.

### 2026-09-14 — scaffolding preamble duplicated across 10 screens, with dead desktop-only branching baked in

Extracted the shared mobile scroll shell as `NoriScrollScaffold` across ten screens and removed their unused wide-layout branches, keeping the narrow Android values. Home and Customization were intentionally excluded because their layouts are structurally different or need separate review.

### 2026-09-14 — plain ink-outlined card shell duplicated across ~20 screen-local classes

Extracted configurable `NoriCard` and migrated equivalent static card shells while preserving their existing dimensions and decoration values. Interactive/material and compound-layout cards were intentionally left local because they are not just a reusable decoration.

### 2026-09-13 — widget/logic duplication cleanup pass + accessoryById crash risk + id-generation RangeError

Extracted shared headers, badges, sections, formatting/date helpers, and `generateId`; `accessoryById` now returns nullable instead of throwing for unknown ids. Flutter web does not safely evaluate `1 << 32` as the expected random bound here, so the id suffix uses a decimal range literal instead.

### 2026-09-13 — accessories drifted off-position across the breathing loop (needed anchor points)

Added per-frame sprite anchors and an overlay builder so animated accessory placement follows Nori’s moving eyes/head; five accessories are calibrated and uncalibrated items retain static fallback placement. The sprite image now has explicit `width: spriteWidth`, because Flutter otherwise only shrinks an unconstrained image and overlay scale can diverge on wider screens; face-centered anchors also account for the tail shifting the canvas center.

### 2026-09-11 — editing a habit from a past day silently destroyed today's progress

`MockHabitRepository.updateHabit` now preserves the stored live progress/reward fields regardless of the caller’s Habit object. This prevents any past-day or future edit path from overwriting today’s state.

### 2026-09-11 — habit "Complete" button's underlying logic — investigated, not a bug

Complete intentionally snaps a habit to its target and grants the full reward regardless of current progress; Home’s contradictory minimum-progress snackbar was removed. Do not restore a repository or widget gate: the minimum language describes reward-tier math, not a prerequisite for the one-tap shortcut.

### 2026-09-11 — evolution celebration never shown outside Home-tab actions

All reward paths now compare pet stage before and after updates and show evolution celebration when it advances. The original demo level anecdote was below the threshold, but the missing trigger wiring was real.

### 2026-09-11 — payment method screen rendered blank

`_CheckoutBar` used `Center` in `bottomNavigationBar`, which expanded under Scaffold’s loose height constraint and starved the body. Replacing it with shrink-wrapping `Align(heightFactor: 1)` restores the body while retaining horizontal centering.

### 2026-09-11 — progress bar threshold tick rendered as a solid block

The threshold marker used `FractionallySizedBox`, which gave its child a tight fractional width and rendered a block instead of a line. It now uses `LayoutBuilder` and a fixed-width positioned marker.

### 2026-09-11 — Home habits panel: habit entries getting visually cut off

The height-capped scroll list could clip a partial final tile with no scroll cue. An overflow-only transparent `ShaderMask` fade now signals more content; transparency matters because the panel is frosted glass rather than a flat background.

### 2026-09-11 — `InventoryRepository.setEquippedAccessory` accepted any id

Setting an unowned accessory id now no-ops; unequipping remains allowed. This hardens the data layer even though the current UI only offers owned items.

### 2026-09-11 — habit / bucket-list item id collisions possible

Habit and bucket-list ids now combine microsecond time with a random suffix. Millisecond-only ids could collide for rapid creations and overwrite data.

### 2026-09-11 — `HabitsListScreen._onReorder` updated the UI before the repository call

Reordering now awaits repository persistence before calling `setState`. A future failed backend operation therefore cannot leave the displayed order diverged from storage.

### 2026-09-11 — two disagreeing streak sources

`MockUserRepository` now derives `currentStreak` from `CalendarRepository` instead of serving a stale literal, matching the calendar’s history walk. `NoriUser.copyWith` also supports the field, keeping Home and Profile consistent.

### 2026-09-10 — primary-button contrast (white-on-moss)

Moss-filled controls now use ink foregrounds to meet contrast requirements, including the data-driven notification CTA case missed by literal-color searching. `inkFaint` contrast was a separate issue fixed later.

### 2026-09-10 — three `mounted` guard misses

Post-await snackbar calls in Home care actions and Shop purchases now return when unmounted. This prevents use of invalid widget context after navigation.

### 2026-09-10 — undisposed controller in `SettingsScreen._promptForText`

The dialog’s `TextEditingController` is disposed after it closes. It previously leaked its controller lifecycle.

### 2026-09-10 — three stuck-button paths

Save/mark-all-read flags now clear in `finally`, so failures cannot leave buttons permanently loading. General error/retry UI remains an open concern.

### 2026-09-10 — "Pip" vs "Nori" naming bug

The hungry-pet notification now says Nori, matching the rest of the app.

### 2026-09-10 — inconsistent XP formatting on Profile

Profile’s XP pill now uses the shared thousands formatter instead of a raw integer.

### 2026-09-10 — dead `kScreenHorizontalPadding`

Removed `kScreenHorizontalPadding`, which had no references. The separate accessory lookup concern was not part of this removal.
