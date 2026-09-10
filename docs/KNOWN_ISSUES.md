# Nori — Known Issues

This file is a running log of bugs/gaps as they're found, not a task queue tied to any
particular session — log something here the moment you notice it even if you don't plan
to fix it right away. When a fix lands, move the entry into `## Resolved` (pattern:
`### YYYY-MM-DD — <short title>` + a couple sentences on what changed) and remove/trim it
from wherever it was listed as open — don't leave a closed item worded as if it's still a
problem.

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

### Editing a habit from a past day silently destroys today's progress (2026-09-10 audit)

**The most serious finding of the audit — an active bug, not a caveat.**

`MockHabitRepository.getHabitsForDate` (`lib/data/habit_repository.dart:321`) returns
habits hydrated with *that day's* logged state via `_hydrate`
(`lib/data/habit_repository.dart:313`), which overwrites `currentValue`,
`isCompletedToday`, `lastAwardedXp`, and `lastAwardedCoins`. Two screens push one of
these hydrated objects straight into the editor: `CalendarScreen._editHabitDefinition`
(`lib/screens/calendar/calendar_screen.dart:567`, always a past day) and
`HabitsListScreen._openEditHabit` (`lib/screens/habits/habits_list_screen.dart:156`,
whenever the selected date isn't today).

`AddHabitScreen._saveHabit` then carries those same fields forward from `widget.habit`
(`lib/screens/habits/add_habit_screen.dart:235,238,242` —
`currentValue`/`lastAwardedXp`/`lastAwardedCoins`/`isCompletedToday`), and
`MockHabitRepository.updateHabit` (`lib/data/habit_repository.dart:259`) replaces the
habit in `_habits` — the *today* list — wholesale.

**Concrete failure:** log 750/1000 ml on today's water habit and claim it (+10 XP). Open
Calendar, tap a day last week where 200 ml was logged and never claimed, edit that
habit's name. On save, today's habit becomes `currentValue: 200`,
`isCompletedToday: false`, `lastAwardedXp: 0` — today's progress and claim are gone, and
the 10 XP is now **permanently unreversible** (`unclaimHabit` no-ops when
`isCompletedToday` is already false). No error, no undo, no signal to the user.

The interface doc (`lib/data/habit_repository.dart:38`) tells callers to carry those
fields forward themselves — the contract is fine, it's just impossible to honor
correctly from a past-day context, since the caller only has the past day's values to
carry. Safer shape: have `updateHabit` merge only the *habit definition* fields
(name/icon/type/target/schedule/etc.) and leave `currentValue`/`isCompletedToday`/
`lastAwarded*` untouched — that makes the failure structurally impossible rather than
dependent on every future caller getting the carry-forward right.

Also check the **habit complete button's underlying logic** while in this area — dictated
2026-09-10, not yet root-caused. Unclear whether what was noticed is this same bug, a
different one, or a false alarm that just needs a re-read to confirm it's fine.

### Evolution screen doesn't appear despite leveling up (dictated 2026-09-10, not yet investigated)

Demo user went from level 5 to level 7 and the evolution moment never showed. Relates to
the existing art-placeholder limitation below and to
`PetRepository.syncEvolution`/`evolutionLevelThreshold` (see `docs/OPEN_DECISIONS.md` —
Pet mechanics), but the reported symptom here is the *screen never triggering at all*,
not the missing art — so check `EvolutionScreen`'s trigger/navigation path specifically
before assuming this is the same issue as the art gap. This also overlaps the "No reward
feedback" finding below (level-up/evolution has no visible event) — worth fixing both
together since they're likely the same code path.

### Payment method screen renders blank (2026-09-10 audit)

Rendered as a blank white screen with no AppBar/body across 4 repeated attempts in the
headless-Chrome pass, no console exception. It's the only screen combining `appBar:` and
`bottomNavigationBar:` — unconfirmed whether this is a real bug or a harness artifact;
worth two minutes on a real device to rule in or out.

---

## 🟠 Important

### Scroll doesn't work under Chrome DevTools device toolbar (Pixel/iPhone preset) (dictated 2026-09-10, not yet investigated)

Reported as still broken. `AppScrollBehavior` (`lib/theme/app_theme.dart:84`) already
adds `PointerDeviceKind.mouse` to `dragDevices` specifically for this DevTools quirk (see
the doc comment there), and that change is sitting uncommitted in the working tree — but
the user is now seeing the scroll problem again, so either that fix doesn't fully cover
it, or something else regressed/reintroduced it since. Needs a fresh repro in DevTools
(which preset, which screen, wheel vs. drag) before touching the code again — don't
assume the existing fix is insufficient without confirming it's actually wired up and
still failing.

### No error handling outside the two auth screens (2026-09-10 audit)

`LoginScreen` and `SignUpScreen` are the only places in `lib/` with a `try`/`catch`
around a repository call. Every other await — roughly 90 of them — is unguarded. This
costs nothing today because every `Mock*` repository is in-memory and can't throw, but
`docs/` and `lib/data/app_data.dart`'s own doc comment frame swapping in a real backend
as a one-file change — and that promise only holds if the screens can survive a repository
throwing.

More broadly, every data-bearing screen has exactly three states — `null` (loading),
data, and nothing else. A failed load leaves the `CircularProgressIndicator` on screen
forever with no message and no retry. A fourth (`error`) state is the single
highest-value UI addition before a real backend lands.

(Guard discipline is otherwise strong — ~30 correct guards found elsewhere. The specific
`mounted`-guard misses and one undisposed controller this section used to name are fixed
— see Resolved.)

### Secondary text (`AppColors.inkFaint`) fails contrast (2026-09-10 audit)

`AppColors.inkFaint` (#9A8B6E), the app's default secondary-text color, fails everywhere
it's used: 2.84:1 on `linen`, 2.96:1 on `linenAlt`, 3.34:1 on white (WCAG AA needs
4.5:1) — used at 11px for habit subtitles, unselected nav labels, all form hint text, and
every empty-state message. (The primary-button white-on-moss contrast failure that used
to sit alongside this is fixed — see Resolved. This is the other half of that finding.)

### No reward feedback — the core loop has no UI event (2026-09-10 audit)

`HomeScreen._applyReward` (`lib/screens/home/home_screen.dart:92`) adds XP and coins with
no animation, toast, or any visible event. `MockUserRepository.addXp` levels up in a
silent loop, and `PetRepository.syncEvolution` promotes the pet's stage with no
notification — discoverable only by tapping the level row's disclosure. `docs/OVERVIEW.md`
states the core loop as *complete habits → earn XP → pet grows*; two of those three
arrows are currently invisible to the user. Fix shape: a reward burst anchored to the
card on claim (`+20 XP · +10 coins`), and a full-screen moment on level-up/evolution. Very
likely the same root cause as "Evolution screen doesn't appear" above.

### Touch targets — nothing measured reaches Android's 48dp minimum (2026-09-10 audit)

From a rendered Pixel 412×915 pass: the per-habit "Complete"/quick-log buttons measured
~32dp, the Settings "Enable" button ~32dp, the "Completed to bottom" toggle ~26dp, and
the notifications "Do it now" pill ~19dp. Every one of these is a hand-rolled `InkWell`
or an explicitly shrunk `Size.zero`/`shrinkWrap` button rather than a default Material
button, i.e. the framework's automatic padding was opted out of. Bottom nav and
accessory tiles measured fine (~90dp) — this is specific to hand-rolled buttons/chips,
not systemic.

### Screen-reader semantics exist in exactly one widget (2026-09-10 audit)

`PetVitalRing` (`lib/widgets/pet_vital_ring.dart`) has a correct
`Semantics(label:, value:, button:)`. It's the only widget in `lib/` that does, which
means this is an application gap rather than a knowledge gap. Consequences: the bottom
nav (`lib/widgets/nori_bottom_nav.dart`) is a hand-rolled `Row` of `InkWell`s, not a
`NavigationBar`, so TalkBack announces "Habits, button" with no selected state and no
"tab N of 5"; the habit checkbox (`lib/widgets/habit_tile.dart`) carries its
completed/not-completed state only via strikethrough, with no `Semantics(checked:)`; and
no `ProgressBarPill` usage exposes a semantic value anywhere. Also: bottom-nav labels use
`SizedBox(height: 14)` + `FittedBox(scaleDown)`, so at larger system font sizes the
labels shrink instead of growing — the one place an accessibility setting makes the app
actively worse. One more instance of the same pattern: the unread indicator on
`NotificationsScreen` (a bare 10×10 `Container(color: notification.color)`, no text, no
icon, no `Semantics`) conveys read/unread by color alone, with nothing for a screen reader
to announce.

### Cognitive load & interaction gaps (2026-09-10 audit)

- **Add Habit puts 13 decision points on one uninterrupted scroll**: name, icon (6
  options), category (4), tracking type (6), target, unit, min-threshold toggle+value,
  difficulty (3), repeat (4), custom days (7), end-date toggle+range, vacation toggle —
  none of it chunked into steps, so the page reflows under the user's thumb as conditional
  sections appear mid-scroll. By a fair distance the most demanding screen in the app.
- **Logging a quantity/duration habit from the Home panel dead-ends**: tapping the
  checkbox before any progress has been logged shows a SnackBar — "Log some progress on
  the Habits tab first." (`lib/screens/home/home_screen.dart:127`) — and sends the user
  away instead of offering an inline way to log. This fires at the exact moment the user
  was trying to finish something.
- **Tapping the pet opens Customization, not care.** `NoriRoomStage.onTapNori` is wired to
  `_openCustomization` (`lib/screens/home/home_screen.dart:250`), so the single most
  inviting tap target on the Home screen leads to the cosmetics screen, not a
  feed/groom/play interaction.

### Habit statistics progress bars overflow their own outline (dictated 2026-09-10, not yet investigated)

Rendering/clipping bug, not just a style nit — the fill visibly extends past the bar's
own border. Separate from the "more in-depth stats" item below.

### Home screen habits panel: habit entries getting visually cut off (dictated 2026-09-10, not yet investigated)

Layout/overflow bug on the Home screen's habits panel specifically — needs a look at
whatever `ListView`/`Column` sizing is constraining it.

### Profile isn't editable (dictated 2026-09-10, not yet investigated)

Add edit capability — currently display-only.

### Other correctness gaps that cost nothing today but will once a real backend lands (2026-09-10 audit)

- `MockCalendarRepository.getMonth` (`lib/data/calendar_repository.dart:45`) awaits
  `HabitRepository.getHabitsForDate` once per day in the visible month, and
  `_currentStreak` (`:118`) walks backward awaiting it again per day — up to ~430
  sequential round-trips for one Calendar screen load. Free against an in-memory mock;
  worth batching before this points at Firestore.
- `InventoryRepository.setEquippedAccessory` (`lib/data/inventory_repository.dart`) writes
  whatever id it's given without checking it's in `ownedAccessoryIds`. Unreachable today —
  `CustomizationScreen` only offers owned items — but it's a missing invariant in the data
  layer itself, not just in the one caller that happens to behave.
- Both `AddHabitScreen._saveHabit` (`lib/screens/habits/add_habit_screen.dart:221`) and
  `BucketListScreen`'s add flow (`lib/screens/bucket_list/bucket_list_screen.dart:329`)
  generate ids via `DateTime.now().millisecondsSinceEpoch.toString()`. Two items created
  in the same millisecond would collide and one would silently overwrite the other via
  `indexWhere`-based updates. Not reachable by tapping a UI, but worth knowing before this
  logic ever moves off-device.
- `HabitsListScreen._onReorder` (`lib/screens/habits/habits_list_screen.dart:164`) applies
  the new order to `setState` before awaiting `AppData.habits.reorderHabits(...)`. On
  failure the displayed order and the repository's stored order silently diverge — the
  same class of gap as "no error handling outside auth screens" above, called out
  separately because the failure mode here (silent data/UI mismatch, not just a stuck
  spinner) is worth naming on its own.

---

## 🟡 Minor / polish / backlog

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

### Accessories use one fixed position across the whole breathing loop (needs anchor points)

`accessory_art.dart`'s `_kPlacements` gives each accessory a single `topFraction`/`scale`
pair, applied uniformly to every frame of `NoriBreathingSprite`'s 67-frame loop. That loop
is real photographed footage of a physical prop (see the issue above), not a vector rig,
so the head genuinely shifts a few pixels frame to frame as it "breathes" — a fixed offset
is only ever exactly right at the one frame it was eyeballed against, so equipped
accessories (confirmed with Smart Glasses) visibly drift off-position for the rest of the
loop. The placement math itself is already fraction-based (`referenceSize * topFraction`),
so this isn't a display-size bug — it reads as one because the drift becomes more
noticeable at some viewport sizes/DPRs than others.

Fix shape: replace the single fixed placement with real anchor points (head-top for hats,
eye-midpoint for glasses, etc.) mapped per frame of the breathing loop — likely only needs
hand-marking a handful of representative frames (breathing is smooth/periodic) and
interpolating the rest, not all 67. One anchor map then serves every accessory, current
and future, instead of a fresh eyeballed constant per item. Don't solve this by filming a
separate animation per accessory — that means reshooting/hand-compositing 67 frames per
item, which doesn't scale past the 5 accessories that already exist.

### Remaining layout defects (2026-09-10 audit — verify against current build before fixing, this snapshot is one commit stale on a few screens)

- **Achievements**: every trophy card has roughly 120dp of dead vertical space between
  the subtitle and the progress row — content pinned top and bottom with nothing between,
  caused by a fixed grid `childAspectRatio` fighting variable content. (Pair with the
  "make achievements prettier" item below — same screen, do both in one pass.)
- **Shop**: category filter chips truncate their own labels ("Hats" → "Hat…", "Food &
  Care" → "Food & Car…"), and a fourth chip is cut by the viewport edge — did not resolve
  with the extra width between a 390 and 412 viewport.
- **Add Habit**: the floating "Save Habit" bar has no opaque backing and slices content
  behind it; four of six tracking-type card descriptions ellipsize.
- **Habits list**: "Min. Reached (75% XP)" wraps to two lines inside its own pill; several
  habit subtitle lines wrap unexpectedly.
- **Settings**: roughly 74% empty screen (one ~86dp card on a 915dp viewport).
- **Customization header title may render off-center**: the back button is a real
  `IconButton` (`lib/screens/customization/customization_screen.dart:151`) balanced on the
  other side by a literal `const SizedBox(width: 48)` spacer (`:164`) standing in for the
  button's actual rendered width, rather than a shared/measured value — worth a visual
  check, not just a code read.
- **Welcome and Sign-up screens don't share a left edge across their stacked elements**
  (pet card / body text / CTA on Welcome; field label / field border / field text on
  Sign-up) in the rendered pass — each element picked its own padding rather than reading
  off one alignment constant. Re-verify visually before fixing; this is from the
  screenshot pass and may have shifted.

### Architecture: component duplication instead of reuse (2026-09-10 audit)

`lib/widgets/` has 12 components and all of them are healthy — none are unused, none are
single-call-site abstractions that didn't pay off (verified by call-site census). The
actual problem is upstream: `lib/screens/` has 74 private widget classes, and several
concepts are re-implemented per-screen instead of promoted to `lib/widgets/`. The two
newest screens (`SocialScreen`, `BucketListScreen`) each independently re-implemented
concepts that already existed elsewhere, which is the signal this is actively
regenerating, not just historical debt.

Concepts implemented 5+ times with no shared widget:

| Concept | Count | Example divergence |
|---|---|---|
| Screen header (avatar/back + title + trailing) | 8 | 3 are byte-identical apart from the title string; only one handles narrow-width reflow |
| Scaffolding preamble (`SafeArea → LayoutBuilder → SingleChildScrollView → ConstrainedBox → Column`) | 16 screens, ~320 lines | the only variable is a desktop `maxWidth` taking 9 distinct values, none reachable on a phone (see Dead code below) |
| Ink-outlined card shell | 59 raw containers, 3 competing private shells | same card is `EdgeInsets.all(12)`/`AppBorder.standard` in one screen, `all(8)`/`thin` in another — visibly, this also produces card-inside-card double borders on Habits, Profile, Shop, and Social |
| Icon badge (colored rounded square + icon) | 9 | 5 different sizes, 4 different radii for the same concept |
| Section header (title + trailing action) | 6 | only one (`SocialScreen._SectionHeader`) is actually extracted |
| Styled `FilledButton` (moss/ink CTA) | 7 | 5 different `styleFrom` bodies for the same visual treatment |

Two byte-identical duplicates worth calling out directly: `_RewardPill`
(`lib/widgets/habit_progress_card.dart`) has an inline twin in `BucketListScreen`, and
`_LoadingOverlay` is defined twice, byte-for-byte, once in `LoginScreen` and once in
`SignUpScreen`.

Suggested extraction, roughly in priority order: `NoriScrollScaffold` (collapses the
16-screen preamble and deletes the dead desktop branching in the same pass),
`NoriScreenHeader`, `NoriCard`, `NoriIconBadge`, promote `_SectionHeader`/`RewardPill`,
and move the repeated `FilledButton`/dialog/chip styling into `AppTheme.light` (which
today only themes `appBarTheme`).

### Duplicated logic (2026-09-10 audit)

- Thousands-separator formatting is implemented identically three times:
  `lib/widgets/xp_pill.dart:13`, `lib/screens/home/home_screen.dart:293`,
  `lib/screens/shop/shop_screen.dart:359`.
- `_formatNum` is defined identically twice: `lib/screens/habits/add_habit_screen.dart:18`
  and `lib/widgets/habit_progress_card.dart:68`.
- Five separate weekday/month name tables exist across `calendar_screen.dart`,
  `habits_list_screen.dart`, `calendar_repository.dart`, and `add_habit_screen.dart`.
- The coin-reward formula (`baseXp ~/ 2`) is written twice in
  `lib/screens/habits/add_habit_screen.dart` (once where it's actually saved, once in the
  preview ~700 lines away) — the analogous XP drift bug was already fixed once per the
  comment at `add_habit_screen.dart:913`; the coin line is the same class of bug, still
  live.
- Claim/unclaim/quick-log orchestration (~60 lines each) is triplicated across
  `HomeScreen`, `HabitsListScreen`, and `CalendarScreen`'s day-detail sheet — same six
  methods against the same repository, differing only in which date they use. A single
  `HabitDayController` would remove ~120 lines and, importantly, make the past-day
  corruption bug above fixable in one place instead of three.
- Two disagreeing streak sources: `NoriUser.currentStreak` is a static literal that's
  never recomputed (`lib/data/user_repository.dart:12`), while
  `MockCalendarRepository._currentStreak` walks real history and computes a different
  number. These can show different streak values on the same day depending on which
  screen you're looking at.

### Dead code (2026-09-10 audit)

Roughly 95 lines of desktop-only branching (`isWide`/`constraints.maxWidth >= 700|800`,
`AppSpacing.containerPaddingDesktop`) across 7+ files, plus the ~320-line scaffolding
preamble it's embedded in — dead because desktop is explicitly not a target for this
Android-only APK. **Not** included in that: `CustomizationScreen`'s grid breakpoints at
440/620 and `NotificationsScreen`'s `< 360` check are real in-phone breakpoints and
should stay. Also unused: `accessoryById` (`lib/data/accessory_catalog.dart:50`, zero
references, throws uncaught `StateError` on an unknown id — harmless while unused, worth
an `orElse` before it's wired up).

### Minor / cohesion (2026-09-10 audit)

- The user's avatar (`NoriAvatar`) renders next to the heading "Nori" on several screens,
  while "Nori" is the pet's name and the user is a separate person — a naming collision
  worth resolving before it's load-bearing UX copy.
- `CustomizationScreen`'s "Save Look" persists an equipped-accessory value and reports
  "Look saved!", but the equipped accessory isn't rendered anywhere (not on
  `NoriRoomStage`, not on the pet preview) — it reports success while visibly doing
  nothing, which reads worse than an obviously-missing feature.
- `NoriShell` uses `IndexedStack` (`lib/navigation/nori_shell.dart:35`) to keep every tab
  mounted, so `NoriBreathingSprite`'s `..repeat()` animation (`nori_breathing_sprite.dart`)
  keeps repainting its 67-frame loop the whole time the user is on Habits/Calendar/
  Social/Profile, not just Home. `IndexedStack` is the right call for preserving scroll
  and panel state (see the doc comment at `home_screen.dart:27-32`) — this isn't an
  argument against it, just a note that the sprite itself should pause when off-screen.
- `pubspec.yaml:2` still reads `description: "A new Flutter project."` — the scaffold
  default, never updated.

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

### Bucket list items aren't editable (dictated 2026-09-10, not yet investigated)

Add edit capability (`lib/screens/bucket_list/`).

### "Add bucket list item" button doesn't stand out enough (dictated 2026-09-10, not yet investigated)

Needs a visual pass so it reads as the primary CTA on that screen.

### Profile screen: trim what's reachable from it (dictated 2026-09-10, not yet investigated)

Remove "Explore" entry; relocate Nori+ somewhere still reachable (just not from Profile);
Shop no longer needs to be reachable from Profile; Character Customization no longer
needs to be reachable from Profile. Net effect: Profile's nav list shrinks — figure out
where Nori+ moves to instead of just deleting it.

### Achievements could look better (dictated 2026-09-10, not yet investigated)

Current icon-badge treatment reads flat — either source/commission custom art or find a
way to make the existing Material-icon badges look more polished. Pairs with the dead
vertical space finding above in Layout defects — fix both in one pass.

### Habit statistics could go more in-depth (dictated 2026-09-10, not yet investigated)

Currently thin — worth scoping what "more in-depth" means against `docs/FEATURES.md`
before building. (Separate from the progress-bar overflow bug logged under 🟠 above.)

### Social screen should read more like a dashboard (dictated 2026-09-10, not yet investigated)

Currently a plain list. Needs a layout pass (cards/summary stats up top, etc.) — Social is
vision-only per `docs/OPEN_DECISIONS.md`, so keep additions light and scope before
building.

### Onboarding tips needed, without cluttering the Habits screen (dictated 2026-09-10, not yet investigated)

Users need a way to discover: partial completion is editable, tasks can be set back to
zero, and long-press reorders the list — but not via permanent hint UI cluttering the
Habits screen itself. Needs a mechanism (first-run tooltip? dismissible one-time coach
mark? info icon with a sheet?) — not decided yet.

### App logo not wired up (dictated 2026-09-10, not yet investigated)

Asset image already exists in `assets/`, just needs wiring up (likely launcher icon
and/or an in-app header/splash spot — confirm which).

### Mock profile picture needed (dictated 2026-09-10, not yet investigated)

Create one for the demo user (`kDemoUser`, `lib/data/user_repository.dart`) since Profile
is about to become more prominent.

### Shop's Food & Care category is thin — needs more items (dictated 2026-09-10, not yet investigated)

`ShopScreen` (`lib/screens/shop/shop_screen.dart`) hardcodes exactly three `_CareItem`s —
one snack, one soap, one toy (`_CareEffect.snacks`/`soap`/`toys`, around line 72) — one
per care effect, under the "Food & Care" category chip. Add more food/hygiene/care items
so that category doesn't read as empty; check `docs/OPEN_DECISIONS.md` (Economy section —
shop item prices, consumable vs. permanent) before inventing prices/effects for new ones.

### General visual boredom (dictated 2026-09-10, not yet investigated)

Several screens beyond the ones named above read as flat/generic and need a design pass
— no specific screens named yet, triage this first before guessing which ones.

---

## Resolved

### 2026-09-10 — primary-button contrast (white-on-moss)

Every place white text/icons sat on an `AppColors.moss` fill (2.84:1, failing WCAG AA) now
uses `AppColors.ink` (4.65:1) instead: the habit claim button, shop Buy button and category
chips, Add Habit's icon/type/day pickers, the habit checkbox, today's calendar day cell,
three dialog Save buttons that were silently inheriting the theme's default white
foreground, and the small checkmark badges on Profile/Nori+/Customization. A fourth
instance was missed in the original pass and caught later during a log-accuracy check: the
notification CTA button (`lib/screens/notifications/notifications_screen.dart`) sets its
foreground from a hardcoded `AppColors.white`, but its background is `notification.color`
— data-driven, and one of the four mock notifications uses `AppColors.moss`
(`lib/data/notification_repository.dart:39`), so this button silently had the same failure
without ever containing the literal text `AppColors.moss` that the original grep-based pass
searched for. Now fixed the same way (`AppColors.ink`). `AppColors.inkFaint`'s separate
contrast failure (still open above) is **not** part of this fix.

### 2026-09-10 — three `mounted` guard misses

`HomeScreen._careAction`, `ShopScreen._buyCareItem`, and `ShopScreen._buyAccessory` now
guard their post-await `ScaffoldMessenger.of(context)` calls with `if (!mounted) return;`.

### 2026-09-10 — undisposed controller in `SettingsScreen._promptForText`

The dialog's `TextEditingController` is now disposed after the dialog closes.

### 2026-09-10 — three stuck-button paths

`AddHabitScreen._saveHabit`, `CustomizationScreen._saveLook`, and
`NotificationsScreen._markAllRead` now clear their `_isSaving`/`_isMarkingRead` flag from a
`finally` block, so a thrown error can no longer leave the button reading "Saving…" forever.
The broader gap these sat inside — no error state or retry UI anywhere in the app — is
still open (see 🟠 above); only these three specific stuck-button symptoms were fixed.

### 2026-09-10 — "Pip" vs "Nori" naming bug

`MockNotificationRepository`'s hungry-pet notification now says "Nori", matching every
other screen.

### 2026-09-10 — inconsistent XP formatting on Profile

The XP stat pill on `ProfileScreen` now uses the same thousands-separator formatting as
`XpPill` instead of rendering the raw integer.

### 2026-09-10 — dead `kScreenHorizontalPadding`

Removed (zero references). `accessoryById`'s missing `orElse` (still open under Dead code
above) is a separate, still-open item.
