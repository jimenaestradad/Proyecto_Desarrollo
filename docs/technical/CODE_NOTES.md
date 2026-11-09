# Code notes

Code-level gotchas with no better home: non-obvious constraints, ordering and threading traps,
and why a workaround exists. Product rules and backend rationale belong in FEATURES.md,
BACKEND.md and OPEN_DECISIONS.md; open bugs in KNOWN_ISSUES.md; history in git and RESOLVED_LOG.md.

## Habit actions and screen state

- `HabitDayActions.runClaim`, `HomeScreen._celebrateChanges`: a celebration awaits a dialog the
  user closes whenever they like. Keep that wait outside `guardedLoad`/`guardedAction`, or
  `remoteTimeout` fires while it is open.
- `HomeScreen._runClaim`: celebrate from a before/after diff of the reloaded user and pet, not
  the claim's reward flags, so level-ups caused on another tab also celebrate. Previous values
  are null on first load, which is what suppresses celebrations on app open.
- `Reloadable`, `HomeScreen.active`: tabs live in an `IndexedStack`, so `initState` runs once.
  Anything another tab can change (XP, streak, habits) must reload when its tab becomes active.

## Habit data (repositories)

- `getTodayHabits` returns every active habit, not only those scheduled today; use
  `getHabitsForDate` for the due list. `Habit.isActiveOn` ignores the repeat schedule on purpose.
- `FirestoreHabitRepository.updateHabit` uses `.update()` with only `_definitionFields`. `order`,
  `archived`, `createdAt` and `adaptiveMultiplier` have their own write paths; never send them
  from an editor.
- `FirestoreHabitRepository._writeProgress`: re-sending `habitId`/`dayKey`/`date` passes
  `firestore.rules`' `hasOnly(['value'])` because `diff()` lists only changed keys. A claimed
  day's progress is fixed by `claimValue`; unclaim before editing it.
- `logsInRange`, `fetchAllDefinitions`, `hydrateScheduled`: calendar and streak walks (up to ~400
  days) read one range and derive in memory; per-day reads are N+1. Pass `fetchAllDefinitions`
  (archived and ended habits included) or past days lose habits inactive today.
- `FirestoreVacationLog` hits the same N+1 trap, so it caches ranges once. `_loadedUid` is
  compared on every call so an account switch refetches instead of overwriting another account.

## Auth and sign-up

- `AppData.bindToUser`: `achievements` captures bucket list, pet and inventory at construction,
  so it must be rebuilt on a user change or it keeps the previous repositories.
- `FirebaseAuthRepository.logIn`: Auth stores `displayName`, not the claimed username, so read
  `/usernames`. Never copy Auth's `displayName` into `/users/{uid}` on login; it reset username
  and name edits.
- `FirebaseAuthRepository._signInWithGoogle`: web uses the popup with `prompt: select_account`,
  native calls `GoogleSignIn.signOut()` first; otherwise the last account is silently reused.
  `logOut` must not call google_sign_in on web: the unconfigured plugin throws and breaks logout.
- `_SignUpScreenState._submit` / `_createdUid`: once the Firebase account exists, resume at the
  first unfinished step (username claim, then profile write); re-running `signUp` hits
  email-already-in-use.
- `retryWhileProvisioning`: while `onUserCreate` runs, a missing doc surfaces as `not-found` or
  `permission-denied` (the rules' `resource.data.diff(...)` needs an existing resource). Both
  retry; anything else rethrows.
- `changeUsername`: a case-only change leaves the lowercase `/usernames` entry alone.
  `FirestoreUsernameRepository` reads first because an exception thrown inside the transaction
  handler arrives wrapped and shows "Unable to save changes" instead of `UsernameTakenException`.

## Accessories rendering (`lib/widgets/accessory_art.dart`)

- `AccessoryItem.wornImage` overrides `image` on Nori only (tail-charm-clasp: the shop cutout
  shows the whole clasp, the worn art a ring and leaf). `_kImageAspectRatios` is keyed by id but
  describes `wornImage ?? image`.
- `_AccessoryPlacement`: static fractions measure against the rendered Nori height in
  Customization and the sprite width in `NoriRoomStage`; `topFraction` is from the art's
  bounding-box top. `positionedAccessoryArt` is the shared wrapper, so one fix moves every preview.
- `_kFaceCenterOffsetFraction`: the alpha bounding-box center sits left of the face (the tail
  pulls it); the eye midpoint is ~54.8% across `nori_front.png`. `dxFraction` is face-relative,
  and 742/800 converts a width offset into referenceSize's height units.
- horn-bow: static `topFraction` is negative (bow between the horn tips) while animated `dyFrac`
  anchors to `headTopY`, which already sits lower; the two are not interchangeable. Keep
  `dxFraction` 0 like crown/goggles/glasses; off-center read as crooked.
- `_smoothedTailY`: raw `tail.dy` jumps 10-14 canvas px for a few frames (extraction mis-tracking)
  and the charm flickered, so it is circular-averaged and X is pinned at `_kTailXMean`.
- `animatedPositionedAccessoryArt`: a missing `_kAnimatedPlacements` entry returns null and the
  caller falls back to `positionedAccessoryArt`, so an item is never hidden.
- `_EvolvedPlacement`: the evolved head is rigid, so one eye-midpoint anchor serves every head
  accessory. `scale` is art width / sprite width; `dyFrac` runs from the midpoint to the art top.
- `NoriAccessoryPreview.build`: `Image.asset(fit: contain)` shrinks Nori to the cell width but
  leaves a full-height box. Use the actually rendered height or placement floats above his head.

## Nori sprites

- `NoriBreathingSprite`: pass an explicit image width. Without it the image never grows past its
  native 223px while the overlay math assumes the larger `spriteWidth`.

## Flutter layout traps

- `Scaffold.bottomNavigationBar` gets loose height constraints: a plain `Center` expands to
  nearly the whole screen. Use `Align(heightFactor: 1)` (`PaymentMethodScreen`).
- `HomeScreen` room: `Center` + `ConstrainedBox` gives loose constraints, so the `Stack` shrinks
  to its one non-positioned child and the bottom-pinned panel loses its space. Use `Align` +
  `SizedBox`.
- `_HabitPanel`: the inner `BoxDecoration` needs its own matching `borderRadius`, or its sharp
  border is clipped by the outer `ClipRRect`.
- `ProgressBarPill`: `BoxDecoration.padding` already accounts for border width (do not inset
  twice). `Container.clipBehavior` clips to the outer edge, so clip the fill with its own inner
  `ClipRRect`. `FractionallySizedBox` forces a tight width and turns the threshold tick into a
  block; position the tick instead.
- `AppScrollBehavior` adds `PointerDeviceKind.mouse` to the drag devices: Chrome DevTools'
  device presets can report touch as mouse while suppressing wheel events.
- `generateId`: keep `Random.nextInt` bounds as decimal literals. On Flutter Web `1 << 32` is not
  2^32 and threw `RangeError`, silently breaking every Add action.

## Errors, timeouts and logging

- `remoteTimeout` (20s) is deliberately longer than `callCloudFunction`'s 15s so an action that
  calls a function and then reloads can finish. Writes wait for server acknowledgement even
  offline, which is why the guard exists.

## Cloud Functions (`functions/src/`)

- `index.ts`: Firebase deploys only what this file exports. `setGlobalOptions({maxInstances})`
  must run before the function exports are evaluated.
- `onUserCreate.ts` is deliberately a v1 `auth.user().onCreate` trigger: v2 only has blocking
  identity triggers (`beforeUserCreated`), meant for validation inside sign-up. Mixing v1 and v2
  is supported. `careItemCounts` starts with all six ids so purchase/consume never special-case
  a missing key.
- `shop.ts` `catalogEntry`: look ids up with `hasOwnProperty`. A plain `catalog[id]` matches
  `constructor`/`__proto__`, whose price is undefined; the coin check then compares against NaN,
  passes, and saves `coins: NaN`.
- Hand-synced constants: `shop.ts` prices/grants mirror the Dart catalogs and
  `MAX_DELETABLE_ACTIVE_DAYS` mirrors `kMaxDeletableActiveDays`. Nothing enforces either; change
  both sides together.
- Bucket-list callables and `claimHabit`/`unclaimHabit` are idempotent (already completed or
  claimed is a no-op), so retries and double taps are harmless.
- `localDayKeyOf`: `startDate`/`endDate` are the picker's local midnight. Shift by the caller's
  offset and round to the nearest UTC midnight so a DST hour cannot land in the next day.

## Firestore rules

- `/users/{uid}/habits/{habitId}`: `order`, `archived` and `archivedRanges` have direct reorder/archive/restore write paths; `FirestoreHabitRepository.updateHabit` excludes them from definition edits, and `createdAt` is fixed at creation.
- `/users/{uid}/notifications/{notificationId}`: client-generated achievement/streak notifications do not affect currency, so spoofing one only misleads the owner's feed.
- `/usernames/{usernameLower}`: public availability reads expose a `uid` considered non-sensitive on its own; writing an existing entry is evaluated as an update and denied, preserving atomic uniqueness.
