# Nori — Resolved Log

Trimmed historical fix log for Nori, split out of `docs/KNOWN_ISSUES.md` on 2026-09-16 to keep the working file scannable. Full narrative detail from before the split was intentionally condensed; this log favors terse entries going forward.

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
