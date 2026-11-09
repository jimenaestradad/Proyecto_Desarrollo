# Nori — Resolved Log

Trimmed historical fix log for Nori, split out of `docs/quality/KNOWN_ISSUES.md` on 2026-09-16 to keep the working file scannable. Full narrative detail from before the split was intentionally condensed; this log favors terse entries going forward.

### 2026-11-08 — Undo takes back XP and coins (Redo pays again)

- **Why:** Undo cleared "completed" but kept the payout, so the XP pill and coins looked free, a stray
  tap at a progress target couldn't be taken back, and claim → undo kept adaptive XP at its maximum.
  Decided with valevasqc: exact clawback, Redo pays again.
- **Change:** `unclaimHabit` and `uncompleteBucketListItem` reverse the stored `awardedXp`/`awardedCoins`
  (level and pet stage follow) and zero them, so a re-claim pays in full; bucket Uncomplete also clears
  `paidAt` so it leaves the weekly limit. If the coins were already spent the Undo is refused ("can't be
  undone", `coinsAfterReversal`), the `deleteHabit` rule, so claim → spend → undo can't mint. The Dart
  mock, `unclaimedLocally` and the bucket screen clear the payout too. Logs un-claimed before today keep
  their old pay-once behaviour until re-claimed. Needs a deploy of `unclaimHabit` and
  `uncompleteBucketListItem`. 67 function tests, 124 Dart tests and `flutter analyze` pass; the
  transactions themselves are untested (no emulator), so try Complete → Undo, and Complete → buy → Undo,
  on the demo account after deploying.

### 2026-11-08 — Shop accessory previews follow the pet's stage

- **Why:** every Shop accessory card drew the item on the baby even after Nori evolved (seen on a
  moto g 20), so shoppers saw a different pet from the one on Home.
- **Change:** the Shop now reads the pet's stage (a failed read keeps the baby art rather than
  failing the Shop). `NoriAccessoryPreview` has an `evolved` mode that draws a still evolved frame
  (frame 50: wings folded, eyes open) cropped to the body, with the item placed by the same
  `evolvedPositionedAccessoryArt` and per-frame anchors as Home. Tail Charm Clasp shows a bare
  evolved pet, as it has no evolved placement. `flutter analyze` clean; rendered all six items in
  card-sized previews in Chrome. The Shop screen itself was not run live (needs a signed-in session).

### 2026-11-08 — Nori Plus and payment screens show the real plans

- **Nori Plus screen:** the $4.99/$39.99 Monthly/Yearly cards are now a Monthly | Yearly switch over a
  Plus card ($3.99 / $29.99) and a Duo card ($5.99 / $44.99), "Save 37%" on yearly. The Free vs. Plus & Duo
  table matches COTIZACION.md Part 2 (5 habits and 3 bucket-list goals on Free, no ads, daily coin bonus,
  monthly accessory, advanced stats, themes, early pet access); "Exclusive pets" and "Custom widgets" are gone,
  and a line says Social is free on every plan.
- **Payment preview:** it was hardcoded to "Nori Plus yearly $39.99" whatever you picked; it now takes the
  chosen plan (`PlanChoice` in `lib/screens/premium/nori_plans.dart`, the one place the prices live).
- **Still mock:** no Free limits, billing or ads (KNOWN_ISSUES.md). `flutter analyze` and all 124 tests pass.

### 2026-11-08 — `petCareCheck` every 6 hours; early-warning budget

- **Why:** it reads every pet document (dormant accounts included) on each run, so its cost grows with
  registered users, not active ones, and the notification is an in-app inbox entry that nobody sees before
  opening the app. A vital takes ~70 hours to fall from 100 to 30, so hourly bought nothing.
- **Change:** schedule `every 60 minutes` → `every 6 hours` (24 → 4 reads per account per day). Lint and
  all 66 function tests pass. **Not deployed:** production keeps running hourly until
  `firebase deploy --only functions:petCareCheck`.
- **Billing (live):** added an alert-only `nori-pet early warning (1 USD)` budget (50% spent, and forecast
  over $1). Existing live state, checked the same day: $5 alert budget plus Console service spend caps
  (Cloud Run Functions $5, Cloud Run / Gemini API / Vertex AI $1), none enforced. Firestore and Auth can't
  be capped, which stays open in KNOWN_ISSUES.md.

### 2026-11-08 — Phone pass follow-ups: nav hit area, Shop badge, Clothes banner, habit card layout

- **Bottom nav:** the 12dp of vertical padding now sits inside each item's `InkWell`, so the tappable
  area is the full bar height (~63dp) instead of the 39dp pill. The visible pill is unchanged.
- **Shop "Owned" / "Wearing":** the pill moved off the item art into the (otherwise empty) price row
  of the card (`_StatusPill`).
- **Shop Clothes:** the placeholder Dino Onesie is gone, so the tab shows the same "coming soon" banner
  as Furniture. Premium still shows the Royal Crown preview.
- **Habit cards (Quantity/Duration/Cumulative/Multiple/Limit):** title with the category directly under
  it (no chip in the title line any more); reward pill top right beside the ⋮ menu; under the progress
  bar, the status chip on the left and the tappable value on the right. Limit habits still show no
  reward pill.
- **Scroll edge fade:** new `ScrollEdgeFade` (`lib/widgets/scroll_edge_fade.dart`) fades a horizontal
  scroller's left/right edge, only on a side that has more to scroll. Applied to the Social highlight
  cards, streak strip, circle strip and quick-action chips, the Activity and Leaderboard filter chips,
  the Shop category chips and the Add Habit icon row. Use it for any new horizontal scroller.
- Verified on the moto g 20 (2026-11-08): nav tap above the pill switches tab, Habits header and card
  layout, Shop chip order / default tab / Owned pill / Clothes banner, edge fades on Social and Shop
  (both edges while scrolled). Not looked at on device: Add Habit icon row, Activity and Leaderboard chips.
- Dropped as agreed: the "+ button covers a card" item and "rows with no category" (intentional, the
  category is optional).

### 2026-11-08 — Cover thumbnails on circle and competition list rows

The Circles list, the Social hub (circle strip and competition cards) and the competition rows inside
a circle showed only a colored icon; the cover photo appeared only on the detail screen. A new
`CoverBadge` in `social_widgets.dart` shows the cover as a small ink-bordered square and falls back to
the old icon badge when a circle or competition has no cover. The Competitions tab cards had no icon at
all, so they now get a 56 px thumbnail beside the title, only when a cover exists. Checked on screen for
the Circles and Competitions lists; the hub and circle-detail rows use the same widget but were not
seen (the preview harness kept rendering blank).

### 2026-11-08 — Friend pets show the real Nori; 22 new achievement badges in one style

**Pets:** Visit pet and the pet card on a friend's profile showed a paw icon. Visit pet now renders
the same room scene as Home (`NoriRoomStage`, 400 px tall in an ink-bordered frame; shorter than that
crops the winged form) with the friend's stage: baby for stage 0, the winged form for 1 and 2. The
profile card shows a still of the same two forms (`FriendPetPicture`, `nori_front.png` or
`nori_evolved/frame_00.png`, not the 64-frame animation). Every friend's pet looks the same apart from
its name, because art exists for two forms only. **Badges:** Consistency II and III, Rising Again,
Getting Started, Dedicated I and II, Goal Getter, First Step (redone), Not All-or-Nothing, Balanced
Life, Pet's Best Friend, First Evolution, Growing Family, Shopaholic, Better Together and Helping Hand,
all in the Consistency I look (green shield, olive laurel, gold star, cream ribbon, tan sticker
outline). The last six (Proof Pal, Circle Starter, Accountability Duo new; Habit Architect, On Track,
Perfect Week redone) came after the Gemini limit reset, so all 23 now match. They are consistent because each Gemini prompt attached Consistency I as a master template
and said "identical except the emblem and the ribbon text"; ribbon spellings were checked on every
one. Transparent cutouts, 480 px tall, in `assets/images/achievements/`; the three coming-soon
achievements (Balanced Life, Pet's Best Friend, Growing Family) now show their art too
(`_soon` takes an `imageAsset`). The old First Step is kept in
`assets/source/achievements/bundled-before-2026-11-08/`. Dev harness: `tool/social_preview.dart` takes
`?uid=<friend id>`. `flutter analyze` is clean; the pet screens were checked at 390x844 (Jimena stage
2, Tomas stage 0); the achievements screen was not looked at (it needs a signed-in account).

### 2026-11-08 — Real photos on Social, shop previews and one achievement badge

The demo read as a mock because every friend was an initials circle and every proof post a flat
panel. Added 23 bundled images under `assets/images/social/` (1.7 MB total, JPEG): 11 profile
pictures (`avatar_<id>.jpg`, 512 px), 6 proof photos (`proof_*.jpg`) and 6 covers (`cover_*.jpg`).
They were generated with Gemini as realistic phone-style photos for Guatemala City: only men and
women, mostly white and mestizo Latinos with a few exceptions (Chinese, redhead, Black), and varied
shots (laughing off camera, a dog, sunglasses on a colonial street, a volcano landscape) instead of
everyone staring into the camera. New optional fields: `SocialUser.avatarAsset`,
`SocialCircle.coverAsset`, `Competition.coverAsset`, `SocialPost.photoAsset`; `NoriAvatar` takes
`imageAsset`, `ProofPhoto` takes `asset` (a photo picked this session still wins), and a new
`CoverPhoto` banner sits on the circle and competition detail screens. Initials and the placeholder
panel remain the fallback. The seeded feed changed: Sarah's reading post now carries a photo (it was
the one post without proof) and there is a new post from Tomas for the no-social challenge. The Shop's
Dino Onesie and Royal Crown previews and the Consistency I achievement now use hand-style art with
transparent backgrounds (`accessories/dino-onesie.png`, `accessories/royal-crown.png`,
`achievements/consistency_i.png`). Raw 1024 px originals are in the gitignored
`assets/source/gemini-social/`. Also fixed `tool/social_preview.dart` (it no longer compiled after
`UserRepository.lastKnownUser` was added). `flutter analyze` is clean; checked the feed, a
competition detail and a friend profile at 390x844 through that preview harness. Not done: the other
18 achievement badges, pet art on Visit pet, and covers on the list rows (see KNOWN_ISSUES).

### 2026-11-08 — Fonts bundled; XP pill no longer flashes a stale value; small Android-pass fixes

Found on a moto g 20. **Fonts:** Fredoka and Karla were fetched from the network on first launch, so
offline or on a slow first paint the whole app rendered in Roboto (the welcome headline, all body
text). The eight static files `google_fonts` asks for (Regular/Medium/SemiBold/Bold) are now in
`assets/google_fonts/` (hashes checked against the package's table; README there) and `pubspec.yaml`
lists the folder, so the package finds them before the network. **XP pill:** each tab kept its own
`_user` from its last visit, so switching tabs after a claim showed the old XP for 1 to 2 seconds
until that tab's reload finished (Social showed 2,444 while Home had 2,474).
`UserRepository.lastKnownUser` now returns the newest user any screen fetched, and the five tabs show
it the moment they become active; their reload still has the last word. **Also:** Profile's
achievement preview tiles are white (like the full screen) and say "Completed" when earned, and their
icons are top-aligned so they line up; screen titles shrink to one line instead of breaking mid-word
("Calenda / r" at a 1.3x system font; `NoriScreenHeader`), and the Notifications header stacks "Mark all
as read" under the title at large text; Habits' header gap under the title drops from 48dp to 24dp;
"Reset demo account" now shows "Resetting demo account…" at once and ignores a second tap (the call
takes ~3s with no other sign). `flutter analyze` is clean; checked on the phone, no new tests.

Follow-up the same day, after valevasqc answered the phone-pass notes. **Delete confirms are red:**
`AppTheme.destructiveFilledButton` (the style the Delete account dialog already used) is now the one
red confirm button, and the Delete habit and Delete bucket-list goal dialogs use it too instead of a
soft green "Delete". **⋮ menu:** Quantity, Duration, Multiple and Limit cards now list "Edit today's
progress" under "Edit habit"; it opens the same dialog as tapping the number (`_editProgress`).
Binary habits have no number to edit, so their menu is unchanged. **Decided as intended, not bugs:**
New habit opens on "Quantity", and a binary habit's empty progress bar stays (visual cohesion).
Then more notes from valevasqc, same day: the **Adaptive XP note in Add Habit is dismissable** (a
`OneTimeHint` with a new `Tip.adaptiveXp`, once per account, back via Settings > Replay intro and
tips); the **value ("0 / 1000 ml") and category on habit cards are 14px** instead of 11px; the
**Habits header** is XP + streak left, flag + bell right with a 12dp gap, title below; in the Shop
**"Need N more" is faded** (the app theme painted every disabled FilledButton moss green, so the
disabled colors are now set explicitly) and the **chips read Food & care, Accessories, Clothes,
Furniture, Premium**, opening on Food & care (which also fixes "Go to Shop from a pet vital opens the
Hats tab"; the Wardrobe's shop link passes `startOnAccessories` so it still lands on Accessories).
`TipsStore.current()` now falls back to the shared bucket when Firebase isn't initialised, which keeps
the Add Habit widget tests running. None of this has been seen on the phone yet (it lost its USB
connection); `flutter analyze` is clean and the 124 tests pass.

### 2026-11-07 — Limit-habit hint, and a prompt before the Wardrobe drops a look

The limit habit's button was "Mark day safe", which a first-timer couldn't decode. It is now "I stayed
under" (chip "Stayed under" once done), with a new one-time hint (`Tip.limitHabits`, one sentence)
above the first limit card on Habits: "Stay under your limit all day, then tap I stayed under to count
the day." Leaving the Wardrobe with a look that differs from what is saved now asks "Discard
changes?" (Keep editing / Discard), from the back arrow, the Shop button and the system back
gesture; the saved look is tracked, so a successful "Save look" leaves without a prompt. Tests:
`wardrobe_discard_test.dart` (prompt with a change, none without). 124 Flutter tests pass; neither
change was looked at on a screen.

### 2026-11-07 — No-categories hint on Add Habit

Add Habit shows a sky `NoriInfoBanner` under the Category field while the account has no categories:
"No categories yet. Add one to group your habits." with an "Add one" button that opens the same
"New category" prompt the dropdown's "Add category" entry uses, so nobody leaves a half-filled form for
Settings. It is not a one-time tip: it disappears as soon as a category exists. `NoriInfoBanner` gained
optional `actionLabel`/`onAction`. New widget test; 122 Flutter tests pass. Seeding Health, Study and
Finance for new accounts (`onUserCreate`, needs a deploy) is still open above.

### 2026-11-07 — Sentence case, and the "Not due today" line

About 120 button, heading and label strings moved from Title Case to sentence case ("Create
account", "Mark day safe", "Habit statistics", "Limit / negative"), matching DESIGN.md §10. Left as
they were on purpose: product and pet names, content names (habits, competitions, achievements) and
the `Pet Care` category key. Four test lookups were updated. The grey explanation under "Not due
today" on Habits ("Scheduled for other days, so they don't count toward today.") is gone; the
heading and the rows say enough. Also fixed in the same pass: `RewardBurst` put a `Positioned` inside
an `IgnorePointer`, which throws in a real overlay; a new widget test (`reward_burst_test.dart`,
chip shows then clears, a paying claim shows it, an undo or a paid re-claim shows nothing) caught it.
118 -> 121 Flutter tests, all passing; the chip itself was not seen on a screen (screenshots land
after its 1.3 s fade).

### 2026-11-07 — Reward chip, Shop states, Wardrobe, one inbox

Completing a habit now shows `RewardBurst`: a chip ("+13 XP · 5") rises from the tap point and fades
in 1.3 s, with a light haptic, the checkbox pops, and `XpPill` counts up to its new total. It fires
at tap time from `claimedLocally()` and only when the claim actually pays (`rewardPaid` false), so an
undo, an edit, or a re-claim of a paid day shows nothing; both claim paths (`HabitDayActions.runClaim`,
Home's `_runClaim`) call it, and `main.dart` tracks the last pointer position. Shop cards no longer
fade: owned items get an "Owned" badge and a white Equip button, the worn item a green card and a
"Wearing" badge with "Take off", and items you can't afford show a red price and a disabled
"Need N more" button. "Pet Boutique" is now "Shop" and "Style Pet" is "Wardrobe" (the Shop's hanger
icon became a "Wardrobe" text button, the Wardrobe has a "Shop" button). One inbox: every bell is the
new `NotificationsBell` and opens `NotificationsScreen`, now with All / Pet / Social filters, social
cards via `SocialNotificationCard`; `SocialNotificationsScreen` is gone and `SocialScreen` takes
`onOpenHome` for the "Take care" button. Checked with `flutter analyze` and 118 Flutter tests.

### 2026-11-07 — One back-button style

Every pushed screen now leads with the plain arrow from `NoriScreenHeader.backButton` and a
left-aligned title. Shop moved from an `AppBar` into `NoriScreenHeader` (inside the scroll, like
Settings); Customization lost its circled arrow, centered title and 48px spacer; Add Habit lost the
circled X on the right; Nori Plus's X became an arrow; Payment Method's title is left-aligned.
`flutter analyze` is clean; Shop, Style Pet and New Habit were rendered at 412px.

### 2026-11-07 — UX/UI audit quick wins (post-bugfix pass)

Profile's "My Achievements" now leads with earned trophies, then in-progress, then locked (it used
to show the first four in catalog order, all locked on the demo account), and locked illustrations
are faded so they no longer read as earned. Profile lost its duplicate XP pill and the Current
Streak progress bar (a streak has no target to fill; the streak pill stays). Log Out moved from a
loud pink full-width button into the Account card as a plain row; Delete Account is a red-tinted
`NoriListRow(destructive: true)`. Habits' bottom "Add New Habit" button is now a terracotta
floating circular button (today only; the empty state says "Tap + to add one"). Home's three care
rings turn red-tinted with a red dot below 30 (`kLowVital`, same number as `LOW_VITAL` in
`functions/src/notifications.ts`); the care sheet says "Fullness", not "Hunger". Habit cards show
the category instead of "Quantity · Health" (type name only when there's no category) and "Not
started" instead of "In Progress" at 0 progress. Calendar's Missed Days uses a neutral icon, and
the Shop's first tab is "Accessories" (it holds hats, glasses and a tail charm). Checked with
`flutter analyze`, 117 Flutter tests and a 412px render of Home, Habits, Profile and Settings.

### 2026-11-07 — Code audit fix pass

Backend: `petCareCheck` only trusts a real `Timestamp` in `lastDecayAt` (a forged value used to throw
and end the run for every later user), isolates each pet in a `try/catch`, and re-reads the pet
inside its transaction so a pet fed since the scan gets no "hungry" notice. Not deployed yet.
`resetDemoAccount` reuses `levelFields`/`syncPetStage`; `uncompleteBucketListItem` no longer reads
the user and pet docs it never used; `seedPlan` reuses `isScheduledOnKey` and the shared
`numberOrNull`. Dart: a failed Vacation start/end no longer leaves the cache "frozen" (it changes
only after the write succeeds); `changeUsername` finishes the move when the new handle is already
yours, so retrying a failed profile save no longer says it's taken; Home loads the pet in parallel
and `syncEvolution` is gone; Home's "Try it on" opens Customize and Undo refreshes the streak;
"Jump to today" clears yesterday's cards; progress writes to an existing log touch only `value`
(a timezone change no longer breaks them); a huge `%` quick-log amount is rejected; fractional
progress shows ("0.4 / 1"); Sign Up disposes its controllers; the demo reset checks `mounted`.
Removed dead code (`_connectToEmulatorsInDebug`, `progressToNextEvolution`, `addXp`, `addCoins`,
`addCareItem`, `addAccessory`, `syncEvolution`), shared the auth-card layout (`AuthCardScreen`),
the quick-log default (`defaultQuickLogStep`) and weekday labels, and fixed three stale comments.
Checked with `flutter analyze`, 117 Flutter tests and 59 functions tests; not run on a device.

### 2026-11-07 — Text contrast and Profile's Habit Breakdown

Measured the app's text/background pairs and darkened four tokens in `app_colors.dart` so small text
reaches 4.5:1: `mustardDark` `#9A7C1F` -> `#735B10` (streak chip and Calendar "perfect" day were 3.1:1),
`terracottaDark` `#B5652F` -> `#944B1C` (Calendar "done" day 3.2:1, "x / y Completed" 3.7:1),
`mossDark` `#5B7A45` -> `#4A6A36` (4.1:1), `inkMuted` `#7A6B4F` -> `#6B5D43` (4.4:1). DESIGN.md's token
table has the new values. Icons and borders that use those tokens get slightly deeper too.
Profile's Habit Breakdown: the icon now sits on the habit's color with an ink icon (like every other
`NoriIconBadge`), and the bar uses the default moss fill instead of the habit's pastel.
Checked by ratio, `flutter analyze` and the tests; not yet looked at on a screen.

### 2026-11-07 — Screen-reader labels on five controls

From the 2026-10-26 semantics-tree audit. `NoriRoomStage`: the pet is now a button labeled "Style
your pet" (sprite art hidden from the reader). Customization: each accessory tile is named after
the accessory. Shop: category chips are one labeled, selectable button each (they read as unlabeled
checkboxes). Habits: the "Completed to bottom" switch and its text are one control
(`MergeSemantics`). Calendar: day cells read "October 3, done" / "perfect day" / "missed" /
"today" / "upcoming" instead of a bare number. Labels only, no visual or behavior change.
Checked with `flutter analyze` and the existing tests; not yet heard on TalkBack.

### 2026-11-07 — Habits header: 48dp buttons, two rows

The XP pill (left edge) and streak chip (right edge) now sit on their own row; the title and
its two buttons (Bucket List, Notifications) sit below. Both buttons use the new
`CircularIconButton(largeTapTarget: true)`: the same 36dp circle in a 48x48dp box. Archived Habits
moved to Settings > Habits, and the two snackbar/help texts that said "restore it from Archived
habits" now name Settings. The Habits tab reloads when you switch back to it, so a restore shows up.
Chosen from five options (see the layout comparison in the 2026-11-07 session). Not yet seen on a
screen, and Calendar's header still has the old one-row layout.

### 2026-11-07 — Home HUD "avatar + pet name" is intentional (not a bug)

The Home card pairing the user's profile picture with the pet's name and the user's level was
logged as a "Nori naming collision". valevasqc confirmed it is deliberate: there is one level (the
user's; the pet's stage derives from it), so the card reads as "you and your Nori". Removed from
KNOWN_ISSUES; no code change.

### 2026-11-07 — First-habit gift pop-up

`HabitRewardResult` now carries `giftedAccessoryId` from the `claimHabit` response, and a new
`GiftScreen` (shared `CelebrationScreen` shell, same entrance as evolution) shows the accessory
after any level-up/evolution pop-up, from both Home and `HabitDayActions` (Habits list, Calendar),
with a "Try it on" button that opens Customize ("Not now" dismisses).
The "gift" feed notification is unchanged. Covered by widget tests for the screen; the end-to-end
claim needs an account that has never completed a habit, so it has not been seen live.

### 2026-11-07 — Change password in Settings

Password accounts now get a "Change Password" row (Google-only accounts keep "Set a Password").
`AuthRepository.changePassword` re-checks the current password, then calls `updatePassword`, mapping
wrong password / weak password / rate limit / offline to plain messages. The dialog reuses
`_SetPasswordDialog` with a current-password field and rejects an unchanged password. Not yet
tried against live Firebase.

### 2026-11-07 — Bucket-list retry id, catalog drift test

Adding a bucket-list goal that timed out or failed remembers it (`_unconfirmedAdd`); adding the
identical goal again reuses its id, so a write that committed late is overwritten instead of
duplicated. It is forgotten once the list shows it or the add succeeds, so deliberately adding the
same goal later still makes a new one. `test/data/catalog_sync_test.dart` reads
`functions/src/shop.ts`, `firestore.rules`, `deleteHabit.ts` and `notifications.ts` as text and
fails if care-item prices/grants/ids, accessory prices, `MAX_DELETABLE_ACTIVE_DAYS` or the pet decay
rate differ from the Dart copies.

### 2026-11-07 — Inventory count floor + dormant pets stop getting reminders

`careItemCountsOnlyDecreased` now also requires each count `>= 0`; `<= old` alone let a client
write -5 over 3. `petCareCheck` skips pets last cared for more than 7 days ago
(`PET_CARE_DORMANT_AFTER_MS`, measured by `lastDecayAt`, which care actions reset), so abandoned
accounts get about a week of daily reminders instead of one forever. Needs
`firebase deploy --only firestore:rules,functions:petCareCheck` to go live.

### 2026-11-07 — Data-correctness pass (code audit leftovers)

- **Overlapping loads:** Home's `_loadData` drops its result if a newer load started or a habit
  claim/log/care item happened while it ran (those re-read what they changed). Profile drops an
  older `_fetchData`. Social screens (`SocialLoadState.reload`) now run loads one at a time and
  queue one follow-up, so a slow older read can't land last. Habits list `_onReorder` applies the
  saved order to the list as it is after the write instead of committing its pre-request copy.
- **Stale badge on Habits list:** the user badge (streak, XP, coins) refreshes after every claim
  *and* unclaim, after a progress edit that flips whether the day keeps the streak (reaching or
  dropping below the minimum), and after returning from add/edit/delete/archive (a delete reverses
  the XP and coins it paid).
- **Category delete** is a transaction, so two devices can't delete down to zero.
- **Customization:** the save captures the selection it started with; if the pick changed mid-save,
  the toast says the newer pick still needs saving.
- **Email verification banner** re-checks when the app returns to the foreground (only while it is
  showing).
- Not changed: mock-repository drift (only runs signed out and in tests, still in KNOWN_ISSUES) and
  the Nori+ plan (premium is mock, still in KNOWN_ISSUES). The bucket-list "fresh id per save
  attempt" item was dropped from KNOWN_ISSUES without a code change: a failed add re-reads the list,
  so a save that did commit shows up before anyone would retype it.

### 2026-11-07 — Notifications sync throttled

`FirestoreNotificationRepository.getNotifications` skips `_sync` (user doc + months of habit history
for achievements) if the last successful sync was under 5 minutes ago. Chosen over a dirty flag
because achievements depend on habits, calendar, bucket list, pet, inventory and social, so every
mutation path would need to bump it and a missed one drops a notification. Cost: a new
streak/achievement notification can appear up to 5 minutes late. The cooldown lives on the
repository instance, so it resets on sign-in/out.

### 2026-11-07 — Instant feedback everywhere; `linenAlt` retired

Everything that used to wait on the network now shows its result first and syncs behind it, using
the same pattern as habit actions (pending counter, edit stamp that drops a stale reload, re-read on
failure or when the last action lands):
- **Shop:** buying a care item or accessory drops the coins, adds the item and shows the
  confirmation at once (the "Buying…" label and disabled buttons are gone). Server calls go through
  `OrderedQueue` (`lib/utils/ordered_queue.dart`) so equipping something just bought waits for the
  purchase.
- **Home:** using a care item lowers the stock and raises the vital immediately
  (`applyCareRestore`); an "out of stock" answer from the server re-reads both.
- **Bucket list:** complete/uncomplete, add, edit and delete update the list first; the progress
  bar over the list is gone. Reward state (`rewardPaid`) is set locally on complete and corrected by
  the re-read.
- **Calendar:** month arrows change the title straight away, months already visited show from a
  cache and refresh behind it, and an unread month shows a spinner under the title instead of
  replacing the whole screen.
- **XP/coins/level badge:** the exact reward is only known to the Cloud Function (adaptive
  multiplier, pay-once), so the number is not guessed; the star/coin icon in the XP pill, Home's
  level row and Home's coin chip turns into a spinner while a claim or unclaim is in flight
  (`SyncingIcon`, `OptimisticHabits.rewardSyncing`).
- **First load:** Habits shows a pulsing skeleton (`HabitListSkeleton`) and Home says "Waking up
  your Nori…" next to its spinner.

**Failure rollback.** Each of these screens keeps a copy of what it showed before the first change
now in flight (one baseline per burst of actions, dropped when nothing is pending) and puts it
back the moment a call fails, then shows the error and re-reads from the server. So the undo no
longer depends on the network: with the server unreachable the re-read fails too, which used to
leave the phantom purchase/claim on screen. If an earlier action in the same burst had succeeded,
the baseline hides it until the re-read brings it back. The Habits list skips the restore if the
viewer has moved to another day. Calendar months that fail to read now show a retry instead of
spinning forever.

**Live check (Chrome, localhost against `nori-pet`, as `demo@test.com`), bucket list only.** Add, edit,
complete, undo and delete show at once and survive a reload; no console errors. With outgoing
requests blocked by a script, a goal added while the request hung vanished after the 20 s guard and
left nothing on the server, and "Mark Achieved" rolled back within a second with "Couldn't reach the
server — try again.". The test goal's reward was reversed by deleting it, so the demo account ended
unchanged. The Add path's snackbar text was not captured. The other screens were not run; what is
still unchecked is under "Instant-feedback pass" in KNOWN_ISSUES.md.
Bucket-list add and edit are now Firestore transactions with a read first (`FirestoreBucketListRepository`),
because a plain `set`/`update` is queued in memory by the SDK while offline and would land after
the error and rollback; a transaction needs the server and fails at once. (Persistence is already
off, so a queued write never survived an app restart; equip already reads before it writes.)

`linenAlt` is no longer a habit/bucket-list color: it was removed from `ColorRegistry`, so anything
saved with that key loads as `mossLight` (the default) and is written back that way on its next
save. The seeded mock "Social Media" habit uses `sky`. Firestore still holds the old key on
untouched documents; nothing rewrites them in bulk. `AppColors.linenAlt` itself stays as a surface
color.

### 2026-11-07 — Economy pass: slower decay, cheap care, pricier hats, sized bucket goals, evolution at level 5

Simulated four player types over 60 days (`tool/economy_sim.py`; method and tables in
OPEN_DECISIONS.md, "Economy"): care used to cost ~106 coins a day against 14-78 earned, so Nori sat
at 0 for most players and no accessory was affordable, while a self-made bucket goal paid 281 coins
a day. Changes, all approved by valevasqc:
- **Decay 2 → 1 point/hour** (`kPetDecayPerHour`, `PET_DECAY_PER_HOUR`; the notification test now
  uses 40 hours).
- **Care items:** basic (food, shampoo, plushie) 10 coins per pack of 3, restoring 25; better (cake,
  hair brush, blanket) 18, restoring 50 (`care_item_catalog.dart`, `shop.ts`).
- **Accessories:** Tail Charm Clasp 100, Horn Bow 180, Chef Hat 250, Steampunk Goggles 350, Flower
  Crown 500; Sunglasses stay the free first-completion gift (`accessory_catalog.dart`, `shop.ts`).
- **Bucket list:** pick Small / Medium / Big (75/25, 150/50, 300/100 XP/coins) instead of typing
  numbers; the server caps at 300 XP / 100 coins and pays only **2 goals per rolling week** (`paidAt`
  on each payout, `functions/src/bucketRewards.ts`, unit-tested). A third goal in the week is
  achieved but pays nothing, and the app says so. `resetDemoAccount` clears `paidAt`.
- **Evolution at level 5** instead of 7, as a single constant (`EVOLUTION_LEVEL` /
  `kEvolutionLevel`); the threshold stored on existing pet documents is ignored, so existing
  accounts follow it on their next XP change.
- **New accounts** start with food 3, shampoo 3, plushie 3 (still 0 coins).
**Needs a deploy to take effect:** `shop`, `completeBucketListItem` (and the other functions that
sync the pet stage), `onUserCreate`, `petCareCheck`/notifications, `resetDemoAccount`. The app
side ships with the next build; until the functions are deployed the shop charges the old prices
and the app shows the new ones. Not run on a device. Unchanged and still open: the Undo/redo rule
(KNOWN_ISSUES.md), seeding default categories, the midnight reload.

### 2026-11-07 — Live password checklist, inline Add Habit errors, demo baseline

- **Password rules show while typing.** Sign-up and Settings' "Set a Password" show a checklist
  (8+ characters, a letter, a number) that ticks off as you type (`PasswordRules`,
  `lib/widgets/password_rules.dart`). It is local, so there is no delay. `passwordChecks` in
  `validators.dart` feeds both it and `validateNewPassword`, so the two can't disagree; the
  submit-time snackbar stays as the backstop.
- **Add Habit marks the field.** A refused Save now also puts the message in red under the field
  and a red border on it (cleared when you edit it), on top of the snackbar, scroll and focus below.
  Custom days get the red line under the day circles.
- **Username availability check starts 250 ms after you stop typing** (was 400 ms). The rest is
  one Firestore document read, so what is left is network time.
- **Demo baseline.** Reset demo account (and the `seedHistory` script) now leave `demo@test.com`
  with every care item at 3 or more and at least 500 coins (`demoBaseline.ts`, unit-tested).
  **Takes effect after redeploying `resetDemoAccount`;** not deployed yet.

### 2026-11-07 — Add Habit scrolls to the field a failed Save names; username picker gets an exit

- **Add Habit:** when Save is refused (Ideal Target, Quick-Log, Minimum Threshold, custom days),
  the snackbar is unchanged but the form now scrolls to that field and, for text fields, focuses
  it (`_saveHabit`, `FocusNode`s / `_customDaysKey`). Inline red errors are still not built.
  Checked with `flutter analyze` only, not run in a browser.
- **Username picker:** "Not you? Use a different account" signs out and returns to Welcome
  (`ChooseUsernameScreen._useDifferentAccount`), so a wrong Google account is no longer a dead end
  that survives force-closing the app. The abandoned account stays in Firebase, harmless; a
  scheduled cleanup is noted in KNOWN_ISSUES.

### 2026-11-07 — Weak-password message states the app's rule

`FirebaseAuthRepository` told people to use "at least 6 characters" when Firebase rejected a
password (sign-up and Settings' "Set a Password"), contradicting the 8-plus-letter-and-number rule
the forms enforce. Only reachable by getting past the form's check, but it now says "at least 8
characters, including a letter and a number" (from `passwordMinLength`).

### 2026-11-07 — Live Firestore rules match the repo

Read the published ruleset of `nori-pet` through the Firebase Rules API (release
`cloud.firestore`, last updated 2026-11-05 23:29 UTC) and diffed it against `firestore.rules` in
the working tree: byte-identical. That closes the QA audit's "rules were never deployed" claim.
Note the working-tree file is uncommitted; `git` HEAD still holds the 2026-10-26 version.

### 2026-11-07 — QA audit F1/F4 follow-ups: lost sessions and half-finished sign-ups

- **A session that ends while the app is open sends the person to Login.** `NoriApp` (`lib/main.dart`)
  listens to `AuthRepository.sessionLost`, which fires when a signed-in Firebase session ends
  without Log out or Delete account (token expired or revoked, account disabled or deleted
  elsewhere). It unbinds the account, replaces the stack with `/login` and shows "You were signed
  out. Please log in again." `SessionWatch` (`lib/data/session_watch.dart`) tells the two apart:
  the repository announces its own sign-outs (`logOut`, `deleteAccount`), so those screens keep
  navigating on their own. Unit-tested; not exercised against a really revoked session.
- **Sign-up interrupted after the username claim is picked up too.** The claim and the profile
  save are separate writes, so closing the app between them left a claimed name on an empty profile
  and the old check (claim only) opened Home with a blank name. `isSignUpComplete`
  (`lib/utils/account_setup.dart`, replaces `hasClaimedUsername`) now also needs the profile's
  name and username (`UserRepository.hasProfile`). `FinishSignUpScreen` reuses a name the account
  already holds instead of asking again, which would have left two claims on one account. Unit-tested
  with fakes; the full path (sign up, close the app after the claim, reopen) was not run live.
- **Email login no longer says "Unable to sign in" for a person who is signed in.** The username
  lookup inside `logIn` is best-effort now; the login screen's own sign-up check follows right after.

### 2026-11-07 — `resetDemoAccount` deployed

The dev-only callable was exported in `index.ts` but missing from the live project (found 2026-11-05,
`firebase functions:list` showed only the other 11), so Settings > Developer > "Reset demo account"
would have failed. Deployed by the owner; `firebase functions:list` now lists it, and the post-deploy
preflight check (KNOWN_ISSUES.md, "QA pass 2026-11-03") returned 204 for all 11 callables including
`resetdemoaccount` (`petcarecheck` is scheduled, not public, and returns 403 as expected). Not yet
exercised by pressing the button as `demo@test.com`.

### 2026-11-05 — `/usernames` create rule deployed

`firestore.rules` now only accepts a `/usernames` entry whose id is 3-20 lowercase letters, digits
or underscores, whose `username` field equals that id lowercased, and whose keys are only `uid`,
`username` and `createdAt`. Written to match `lib/utils/validators.dart` and compiled with
`firebase deploy --dry-run`; deployed by the owner. Not yet exercised with a fresh sign-up and a rename.

### 2026-11-05 — Second batch: shop equip, photos, rematch, seed habit, QA-audit fixes

Shop cards now equip/unequip in place (button flips to Unequip, a Dressing room icon in the app bar
opens the full screen). Profile picture and social proof photos can be picked from the device and
kept in memory for the session (`SessionPhotos`, `image_picker`), standing in for Firebase
Storage. Competition standings put each progress bar inside the person's card; Rematch opens the
finished competition's format and people on the review step. Binary habits on the Habits tab show
the reward chip and a 0/1 progress bar like the others. Every login-only route is guarded and any
unknown address goes to Home or Login. From the external QA audit: Login now resumes a sign-up
that never claimed a username, and its button says "Log In". See KNOWN_ISSUES.md for the triage.
`functions/src` comments were condensed like `lib/` (the notes worth keeping are in `docs/technical/CODE_NOTES.md`).

### 2026-11-05 — Quick-fix batch: instant habit actions, autocomplete, Undo, sign-up checks

Habit quick-log, Complete, Undo and checkbox taps now render locally first and sync in the
background (`OptimisticHabits`); the last action in flight re-syncs, and a stale reload is dropped
via an edit counter. Reaching a progress habit's target now completes it automatically (not limit
habits), and Undo restores the pre-Complete value (1/3, Complete, Undo is 1/3; session-only, see
KNOWN_ISSUES). Also: Complete button is white on `mossDark`, the "Completed to bottom" switch sits
before its label and every Switch now has an ink thumb/outline (theme-level), the beige `linenAlt`
swatch left the habit color picker, Ideal Target takes digits only, Home's Today's Goal list fades
under the header when scrolled, Delete Account moved below Plan, `/home` while signed out redirects
to Login, and sign-up/choose-username/edit-profile validate name, username, email and password
(`lib/utils/validators.dart`, tested). Long code comments were condensed, with the removed rationale
moved to `docs/technical/CODE_NOTES.md`. Not browser-tested; `flutter analyze` clean, 88 tests pass.

### 2026-11-05 — Account & pet audit: Set a Password rule and pet-name limits

"Set a Password" in Settings accepted any password (even empty-looking or 6-character ones); it now
uses the same rule as sign-up (8+ with a letter and a number). The pet name had no length or
character check on the onboarding screen or in `renamePet`; it is now 1-20 characters with no `<`
or `>` (`petNameMaxLength`, `lib/utils/validators.dart`). The rules-side pet-name check was left out
on purpose, see KNOWN_ISSUES.

### 2026-11-04 — All Cloud Functions redeployed on Node 22, verified live

Node 20 passed its decommission date (2026-10-30), so `firebase deploy --only functions` moved all
ten callables/scheduled functions plus `onUserCreate` from nodejs20 to nodejs22 (`purchaseCareItem` was
already there), which also cleared its failed revision. Verified afterwards: every Cloud Run service
Ready, public (`allUsers` binding, or `invoker-iam-disabled` on `purchasecareitem`), CORS preflight 204
with `access-control-allow-origin` on both preflight and POST, no 5xx in the logs, and a throwaway
account run end to end (sign-up provisioning, claim/unclaim/re-claim pays once, care item and
accessory purchases incl. bogus/too-poor/duplicate refusals, bucket complete/uncomplete/delete
reversal, deleteHabit, no-token 401, deleteAccount leaving nothing behind): 25/25 passed. Not
re-clicked in the browser UI (the Playwright browser was held by another process), and the hourly
`petCareCheck` hadn't yet run on the new revision (last run 15:35Z was the old one, next 16:41Z):
check its log line "pets checked" after that.

### 2026-11-04 — Accessories now render on the evolved Nori

Equipped accessories used to vanish once a pet evolved (no anchors for the evolved frames).
Extracted a per-frame eye midpoint for all 64 evolved frames (`nori_evolved_frame_anchors.dart`);
the evolved head is rigid (constant 40px eye gap, X wobble under ~4px), so it only translates
vertically as he hops and one anchor tracks every head item. `NoriEvolvedSprite` gained the same
`overlayBuilder` hook as the baby sprite, `accessory_art.dart` has an evolved placement table
(baby scales converted by x0.311, then re-tuned on composited frames), and Style Pet now shows the evolved sprite for evolved
pets. Tail Charm Clasp is not drawn there (tail is hidden most of the loop) — see KNOWN_ISSUES.
Steampunk Goggles are now worn pulled up like a headband on **all three** renders (baby Home,
baby static preview, evolved), matching the reference sheet; they used to sit over the eyes on
the baby (a stretch hack, `widthStretch`, was removed with it). The Flower Crown got the same
treatment (full wreath across the head like the reference, sized/placed off the eye gap) on all three. Also fixed `chef-hat.png`, whose interior was transparent (hollow outline on every form): the
enclosed area is now filled white. Verified by rendering all six items on the evolved
`NoriRoomStage` in Chrome across the hop; the Customization panel itself was not run live.

### 2026-11-03 — BACKEND.md cleanup: stale statements fixed, history moved here

BACKEND.md is now a current-state reference; the dated narrative it used to carry is condensed here.

- **Stale statements fixed.** "Starting point" said there were no Firestore/Auth/Functions SDKs or
  `functions/` directory. Auth said "No account deletion in MVP" (`deleteAccount` exists). The
  security-rules sketch still named `isCompletedToday`/`lastAwardedXp`/`lastAwardedCoins` on habits
  (removed 2026-09-24). The Data-sprint seed step said "via the emulator". The schema block lacked
  `notifications` and `notificationState`, and the Auth section listed an `onboardingCompletedAt`
  field that was never built (nothing writes it, and the rules wouldn't allow it).
  The `unclaimHabit` entry no longer says it demotes the pet: since pay-once it doesn't touch user
  or pet.
- **Habit-doc history (2026-09-23/24).** The original plan stored `currentValue`, `isCompletedToday`,
  `lastAwardedXp` and `lastAwardedCoins` on the habit doc, which had no way to roll over at
  midnight. They moved into `habitLogs` for every day, today included; `Habit.createdAt` also gave
  `isScheduledOn` an implicit lower bound. Original bug: KNOWN_ISSUES 2026-09-23 entry.
- **Seed script run (2026-10-05)** on `demo@test.com`: 6 habits, 30 days → 117 logs, level 5,
  1,480 XP, 740 coins, sunglasses gifted, pet still baby (evolves at 7), 4 missed days, short
  current streak. Verified against Firestore. Written 2026-10-04.
- **`claimHabit` verification (2026-09-29):** 25 checks against live `nori-pet` with a disposable
  account: claim/unclaim round trip landed on identical XP/coins/level, sunglasses gifted once and
  never revoked, a direct client write to `coins` rejected by rules, an impossible `dayKey`
  rejected, claims outside `startDate`/`endDate` rejected. `onUserCreate` was verified the same day
  (fresh sign-up matched every provisioning value).
- **Deploy log.** All 7 original functions + rules deployed 2026-09-29 (Blaze plan active).
  2026-10-04: `deleteBucketListItem`, `deleteHabit` (9 live), the `pet.stage` sync in the other
  bucket-list functions, `claimHabit`'s archived-day check, and the matching rules. 2026-10-26:
  adaptive XP, the pay-once coin rule and `deleteAccount` (11 live). `deleteAccount` verified live
  2026-10-26 on throwaway accounts (Auth user and `pet/main` gone afterwards).
- **Dropped as redundant:** the sprint-mapping note about the ClickUp backlog draft, the superseded
  emulator-first "original plan" paragraph, the struck-through gaps #1 (non-atomic claim, fixed
  2026-09-28) and #3 (habit-doc schema, fixed 2026-09-24), and per-function "added/implemented
  <date>" tags.
- **Still to do elsewhere:** `firestore.rules` comments cite BACKEND.md by line number
  (`BACKEND.md:296-299`, `:129-134`, `:300-309`, `:310-328`) and KNOWN_ISSUES cites `BACKEND.md:427`;
  those numbers were already off and are more so now. They should cite section names instead.

### 2026-11-04 — Home shows today's habits, Habits shows all; pet name, release permission, profile fixes

- **Home lists only the habits due today; the Habits tab lists every active habit.** Home called
  `getTodayHabits` (every active habit, due or not), so it said 1/6 while Habits said 1/5. Home now uses
  `getHabitsForDate(today)`. Habits keeps the due list and adds a **"Not due today"** section below it
  (name, schedule such as "Mon · Wed · Fri", an edit button), kept out of the "x / y Completed" count.
  `getTodayHabits` is unchanged on purpose: achievements count habits with it ("Habit Architect").
  Verified on a throwaway account with a weekends-only habit on a Wednesday.
- **The Home HUD shows the pet's own name.** It was hard-coded to "Nori", so the name chosen in
  onboarding never appeared. Verified by renaming the demo pet to "Mochi" and back.
- **`INTERNET` is declared in the main Android manifest.** Flutter only adds it to debug/profile; the
  Firebase libraries may merge it into a release build, but a release APK shouldn't depend on that.
  Not built here (no Android SDK).
- **Edit Profile says "That username is already taken" for a taken name** instead of "Unable to save
  changes". `changeUsername` now checks the name before the transaction (an exception thrown inside a
  transaction handler came back wrapped, so the screen never recognised it).
- **Edit Profile shows the live "username available / already taken" hint** like Sign Up (same
  `UsernameAvailability` mixin); the account's own current name shows nothing, and Save is blocked while
  a taken name is typed. Verified on the demo account without saving.
- **Deleting an account confirms it** ("Your account has been deleted.") on the Welcome screen.
- **Home's empty state points at the Habits tab** for a brand-new account.

### 2026-11-03 — QA pass: vacation toggle verified live, two items checked and not bugs

Vacation Mode Enable/Disable in Settings works end to end on `demo@test.com`: both taps saved
without error and the badge flipped Inactive/Active. Also checked and left alone: undoing a claim
keeps the XP/coins (the pay-once rule, 2026-10-26), and the Edit Habit icon row has a sixth icon off-screen but scrolls.

### 2026-11-03 — `purchaseCareItem` blocked by a missing public Cloud Run binding

Buying a care item showed "Couldn't reach the server": the CORS preflight to `purchaseCareItem` got a
403 ("Empty Authorization header") because the service had lost its public invoker binding, unlike
`claimHabit` and `purchaseAccessory`. valevasqc fixed it live in the console (~13:43Z, sets
`invoker-iam-disabled=true`), after which all three callables answered the preflight with 204; the
failed revision that save left behind was cleared by the 2026-11-04 redeploy. The cause of the lost
binding is still unknown, so check the preflight after every deploy.

### 2026-11-03 — QA pass fixes: logout error, dialog crashes, invisible progress fill, shop feedback

- **Logging out no longer shows "Couldn't reach the server".** `unbindUser()` fires
  `social.accountChanged()` while the Social tab is still mounted; the reload ran against Firestore
  with nobody signed in. `SocialLoadState` now skips the reload when `AppData.auth.currentUserId` is
  null. Social also takes an `active` flag like the other tabs, so its header XP refreshes when you
  switch to it (not verified across an XP change, only on a fresh load).
- **Four dialogs own their text controllers** (Forgot Password and Google account-link in
  `login_screen.dart`, Set a Password in `settings_screen.dart`, change-email password in
  `edit_profile_screen.dart`). Disposing them right after `showDialog` returned left the closing
  dialog on a dead controller: in debug, Cancel on Forgot Password left a red error box and broke
  every tap until reload. Verified on Forgot Password → Cancel.
- **`ProgressBarPill` draws its fill on short bars.** The Container already pads by its border, and
  the fill was inset by the border again, leaving no height at 6px (Home XP pill) and 8px (Today's
  Goal). Covered by `test/widgets/progress_bar_pill_test.dart` (fails on the old code).
- **Shop purchases show "Buying…"** and disable the other Buy buttons while one is in flight, instead
  of dropping a second tap silently. `callCloudFunction` now `debugPrint`s the real exception before
  returning the generic message, so a blocked preflight or 403 is visible in the console.
- **Add Bucket List Goal with an empty title shows "Give your goal a title."**; achievement counts
  are capped at the goal ("1/1", not "6/1"; not checked on screen).
- **Independent reads now run together** in Home's load, `FirestoreUserRepository.getCurrentUser`,
  the calendar month load and the shop. Measured effect: none worth claiming, see KNOWN_ISSUES
  ("Load times").

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

The 2026-09-10 `SocialScreen` (static feed/leaderboard/competition/circle cards behind a "Preview only" banner, every button a "Coming soon" snackbar) is now a navigable ~25-screen frontend backed by an in-memory `SocialRepository` (`AppData.social`): hub, feed/post/proof composer, friends/add/invite/profile/pet visit, leaderboard, competitions (create wizard, detail, invite, results, proof), circles, friend streaks, notifications, badges, privacy/blocking. Layouts follow two Stitch exports but are rebuilt on our tokens and shared widgets (new: choice chip, segmented control, empty state, bottom sheet, post/reaction/proof widgets) and documented in the new `docs/product/DESIGN.md`. Frontend only: no new backend, rules shown are mock placeholders. Later the same day "you" was wired to the signed-in account (reads only, existing repositories): real name/username/level/XP/streak/pet, last-7-days XP on the leaderboard, and today's completed habits in the proof composer; friends and everything else stay seeded. Also closes the 2026-09-10 "Social should read like a dashboard" note. Verified with `flutter analyze` (clean for social) and a release web build rendered at 412×915; not run on a device.

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

### 2026-09-15 — Layout audit re-check: stale findings dropped

Source-read re-verification of the 2026-09-10 audit found these no longer true: Shop category chips
are a horizontally scrolling list (no truncation), Welcome and Sign-up align to one shared constant,
the Habits "Min. Reached" pill no longer exists (it is "Target Reached!" in an unconstrained `Wrap`),
the Bucket List "Add" button uses the standard primary `TactileButton`, the Add Habit "floating Save
bar" is a real `bottomNavigationBar` with reserved space, and quick-logging a quantity/duration habit
from Home already calls `logProgress` inline (no dead-end SnackBar). Only the Add Habit
description-clipping half was real, and it was fixed the same day.

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
