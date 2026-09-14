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

(None open right now — see Resolved below for the four fixed 2026-09-11.)

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

### Habit statistics progress bars overflow their own outline (2026-09-11, partially investigated)

Investigated and found (and fixed — see Resolved) one confirmed cause on the *threshold*
variant (`ProgressBarPill.thresholdFraction`, used on per-habit progress cards): the
threshold tick mark was rendering as a solid block from 0% to the threshold, not a thin
line — `FractionallySizedBox` gives its child a *tight* width constraint, silently
overriding the tick's own `width: AppBorder.standard`. Confirmed via pixel-sampling a
live render, and fixed.

That fix does **not** apply to `ProfileScreen`'s "Habit Statistics" card (`Weekly
Completion`, `Current Streak`) — those bars pass no `thresholdFraction` at all. Whoever's
driving separately confirmed (2026-09-11, from their own `flutter run -d chrome` +
DevTools device-toolbar session) that on those specific bars, the colored fill visibly
paints over the rounded border's corner instead of stopping inside it — most visible on
a fully/near-fully filled bar like `Current Streak`. Not yet reproduced in automated
(Playwright) testing at either normal or simulated high-DPI (2.625x) resolution — may be
specific to DevTools' device-toolbar rendering path. Needs either a repro from that exact
environment (device preset/zoom) or a real Android device to confirm before fixing
further.

### Profile isn't editable (dictated 2026-09-10, not yet investigated)

Add edit capability — currently display-only.

### Other correctness gaps that cost nothing today but will once a real backend lands (2026-09-10 audit)

- `MockCalendarRepository.getMonth` (`lib/data/calendar_repository.dart:45`) awaits
  `HabitRepository.getHabitsForDate` once per day in the visible month, and
  `_currentStreak` (`:118`) walks backward awaiting it again per day — up to ~430
  sequential round-trips for one Calendar screen load. Free against an in-memory mock;
  worth batching before this points at Firestore. (Now called even more often — see the
  Resolved streak-unification entry below — so this is worth prioritizing sooner rather
  than later.)

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

### Neck/hand accessory anchors not implemented (necktie, bow, hand-held items)

Per-frame anchor points now exist for eye-midpoint and head-top (see Resolved below,
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

### Architecture: component duplication instead of reuse (2026-09-10 audit; widget/header/badge extraction done 2026-09-13, see Resolved)

Re-verified 2026-09-13 before fixing (counts had drifted from the original audit — see
the Resolved entry for the corrected numbers). Fixed: screen header, icon badge, section
header, `RewardPill`/`LoadingOverlay` byte-identical duplicates, and the styled
`FilledButton` moss/ink default are now shared (`lib/widgets/nori_screen_header.dart`,
`nori_icon_badge.dart`, `section_header.dart`, `reward_pill.dart`, `loading_overlay.dart`,
and `AppTheme.light.filledButtonThemeData`).

Still open — deliberately deferred as higher-risk/higher-effort than the rest of this
pass:

| Concept | Status |
|---|---|
| Scaffolding preamble (`SafeArea → LayoutBuilder → SingleChildScrollView → ConstrainedBox → Column`) | Still duplicated across 12 screens (not 16 — re-verified), each with its own dead desktop `maxWidth` branch (see Dead code below). A `NoriScrollScaffold` would collapse this and delete the dead branching in the same pass — not attempted yet, touches every screen's top-level layout. |
| Ink-outlined card shell | Still duplicated — 75 raw bordered containers (grew from 59), 3 competing private shells (`_CardShell`, `_ItemCardShell`, `_ProfileCard`) plus 20+ screen-local card classes each picking their own padding/border-width. A `NoriCard` extraction needs a visual pass per screen to catch the suspected double-border spots (Profile, Shop) — not attempted yet. |

### Duplicated logic (2026-09-10 audit; formatting/date/coin-formula dedup done 2026-09-13, see Resolved)

Fixed: thousands-separator formatting (now 1 helper, was actually 4 copies — a 4th,
undocumented one was found in `ProfileScreen` during re-verification), `_formatNum`,
the weekday/month name tables (was actually 7 tables across 4 files, not 5), the
duplicated coin-reward formula, and a newly-spotted duplicate id-generation expression
in `AddHabitScreen`/`BucketListScreen` — see Resolved for details, including a real
`RangeError` bug the id-generation dedup surfaced and fixed.

Still open — deliberately deferred, this one's behavior code, not presentation:

- Claim/unclaim/quick-log orchestration is duplicated across `HomeScreen`,
  `HabitsListScreen`, and `CalendarScreen`'s day-detail sheet — re-verified 2026-09-13:
  `HabitsListScreen` and `CalendarScreen` are genuinely near-identical (six methods each,
  differing only in date source), but `HomeScreen`'s version is meaningfully different
  (no evolution-celebration sync, different today-only repository methods) — it's closer
  to "2.5x" than a clean triplication. A `HabitDayController` would remove the
  `HabitsListScreen`/`CalendarScreen` half of this and, importantly, make the past-day
  corruption bug (see Resolved) fixable in one place instead of two-to-three. Not
  attempted: this is behavior code that's already had subtle per-screen bugs fixed
  individually, and there's no test suite yet to catch a regression from merging it.
- Related, found during the 2026-09-13 pass but out of scope for it: the "sync pet
  evolution → refetch → compare stage → show celebration" sequence is copy-pasted 4
  times (`HomeScreen._loadData`, `HomeScreen._reloadUserAndPet`,
  `CalendarScreen._applyReward`, `HabitsListScreen._claimHabit`), each with its own
  slightly-different guarding comment. Same risk profile as the item above — worth
  tackling together once there's test coverage for the evolution-celebration flow.

### Dead code (2026-09-10 audit)

Roughly 95+ lines of desktop-only branching (`isWide`/`constraints.maxWidth >= 700|760|
800`, `AppSpacing.containerPaddingDesktop`) across 12 files (re-verified 2026-09-13; the
audit said "7+"), plus the scaffolding preamble it's embedded in — dead because desktop
is explicitly not a target for this Android-only APK. **Not** included in that:
`CustomizationScreen`'s grid breakpoints at 440/620, `NotificationsScreen`'s `< 360`
check, and `PaymentMethodScreen`'s form-layout breakpoint at 440 are real in-phone
breakpoints and should stay. (`accessoryById`'s missing `orElse` — no longer unused, now
fixed, see Resolved.)

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

### 2026-09-13 — widget/logic duplication cleanup pass + accessoryById crash risk + id-generation RangeError

Addressed the "Safe + widgets" tier of the 2026-09-10 audit's component-duplication and
duplicated-logic findings (full re-verification first, since counts had drifted — see
the trimmed "Architecture"/"Duplicated logic" sections above for what's still open).

**New shared widgets** (`lib/widgets/`): `NoriScreenHeader` (leading/title/trailing
slots — migrated the 7 screens whose header genuinely fit the shape: Bucket List,
Settings, Profile, Social, Achievements, Calendar, Customization; left Notifications,
Home, and Habits List bespoke since forcing their shape in would've grown the API for
no reduction in duplication), `NoriIconBadge` (9 fixed-size instances, 2 more found
during review and folded in: Shop's coin badge, Add Habit's reward-preview badge),
`SectionHeader` (promoted from `SocialScreen._SectionHeader`, 5 call sites),
`RewardPill` and `LoadingOverlay` (promoted from byte-identical private duplicates).
`AppTheme.light` gained a `filledButtonThemeData` (moss/ink default), letting 3 of 7
`FilledButton` call sites drop their now-redundant `styleFrom`.

**New shared logic** (`lib/utils/`, didn't exist before this pass): `formatting.dart`
(`formatThousands` — 4 copies found, not the audited 3; `formatTrimmedNumber` — 2
copies), `date_labels.dart` (consolidates 7 weekday/month tables across 4 files down to
one canonical source with format-specific accessors, since the tables weren't
interchangeable — full name vs. abbreviated vs. single-letter), `id_generator.dart`
(`generateId()` — found via the reuse-angle review pass, not the original plan: the
`'$microseconds-$random'` id expression was hand-copied into both `AddHabitScreen` and
`BucketListScreen`, this pass's exact target). `Habit.baseCoins` (next to the existing
`baseXp`) replaces two copies of `baseXp ~/ 2` in `AddHabitScreen`.

**Correctness fixes, not just dedup:**
- `accessoryById` (`lib/data/accessory_catalog.dart`) now returns `AccessoryItem?`
  instead of throwing `StateError` on an unknown id. Reclassified from "harmless while
  unused" (its 2026-09-10 audit status) to a live crash risk: two call sites were added
  after that audit (`HomeScreen`, `CustomizationScreen`) without anyone revisiting this.
- **`generateId()`'s `Random().nextInt(1 << 32)` threw `RangeError` on Flutter Web**,
  silently breaking every "Add Habit" and "Add Bucket List Item" tap on web — caught live
  via a Playwright smoke pass (console showed `EXCEPTION CAUGHT BY GESTURE`, the tap's
  `onPressed` aborted before `Navigator.pop`, so the dialog just silently stayed open with
  no error shown, consistent with the "No error handling" gap above). Root cause: under
  Flutter Web's compiler, `1 << 32` doesn't evaluate to 2^32 the way it does on the VM.
  This was pre-existing behavior in both call sites this pass consolidated — moving the
  expression into one shared helper is what surfaced it. Fixed by using a plain decimal
  literal (`2000000000`) instead of a bit-shift for the random suffix's range.

Verified via `flutter analyze` (clean throughout) plus a `flutter run -d chrome`
Playwright pass at a Pixel-equivalent viewport (412×915) across Home, Habits, Calendar,
Social, Profile, Achievements, Bucket List (including adding a new item), Settings
(including its Add Category dialog), Add Habit (including saving a new habit) — every
touched screen rendered identically to before, and both `generateId()` call sites were
exercised end-to-end post-fix.

Review process: `/code-review` and 4 parallel `/simplify` angle-reviews (reuse,
simplification, efficiency, altitude) were run scoped to just the files this pass
touched (the repo has an unrelated in-progress pet-accessory feature in the working tree
that needed to stay out of scope). Findings applied: hoisted `formatThousands`'s regex
to a `static final`, precomputed abbreviated/initial weekday-month tables instead of
slicing on every call, collapsed `NoriScreenHeader`'s `leadingGap`+list-`trailing` into
plain `leading`/`trailing` widget slots (callers compose their own `Row` for multi-part
cases), defaulted `NoriIconBadge.iconColor` and `SectionHeader.titleStyle` to their
majority-case values. Skipped (out of scope for this pass, noted above instead): the
claim/unclaim/quick-log and evolution-celebration duplication (behavior code, no tests
yet), the card-shell/`NoriScrollScaffold` extractions (bigger, visually riskier), and one
review finding about a pre-existing `MockUserRepository.getCurrentUser` performance
issue that's already covered by the "Other correctness gaps" entry above.

### 2026-09-13 — accessories drifted off-position across the breathing loop (needed anchor points)

Root cause confirmed: `nori_breathing/frame_NN.png` is real footage of Nori breathing, so
his eyes/head genuinely move up to ~19px (of a 238px-tall frame) as he inhales/exhales —
verified by extracting, for every one of the 67 frames, the two dark filled blobs inside a
face-sized region of each frame's alpha cutout (his eyes; distinguished from the tail and
horn-shading marks, which are dark too but sit outside that region) and the largest dark
blob left of/below his face (his tail). Eye-midpoint x stayed effectively constant
(118.1–118.7px) but y ranged 81.0–100.2px across the loop — confirmed by compositing
crosshairs at the detected points back onto sample frames, including blink frames, where
the eyes are thin closed lines rather than filled pupils (handled by restricting blob
search to a face-shaped region, so the tail/mouth blobs that briefly out-rank the closed-
eye lines by area don't get picked up instead).

Fixed by adding `lib/widgets/nori_frame_anchors.dart` (`NoriFrameAnchors`, one entry per
frame: `eyeMidY`, `headTopY`, `tail`, all in the frames' shared 223×238 pixel space) and
giving `NoriBreathingSprite` an `overlayBuilder` hook that receives the current frame's
anchors and its own rendered width, composited in the *same* `AnimatedBuilder` tick as the
sprite image so the two can never fall out of sync. `accessory_art.dart` gained
`animatedPositionedAccessoryArt` (anchor-relative placement, calibrated by eye against
rendered frames the same way the old fixed placements were, just referencing a moving
anchor instead of a constant) alongside the pre-existing `positionedAccessoryArt`, which
`NoriRoomStage` now falls back to for any accessory without a calibrated anchor entry yet,
rather than the accessory disappearing. `smart-glasses`, `wizard-hat`,
`propeller-beanie`, `flower-crown`, and `cozy-headphones` all have anchor entries now,
using `eyeMid` and `headTop` respectively — see the open neck/hand-accessory gap above for
what's still unanchored. `CustomizationScreen`'s preview (a static `nori_front.png`, not
the breathing loop) never had this bug and is untouched — still uses the original fixed
placement.

Checked live via `flutter run -d chrome` on two device-toolbar presets: tracking held up
correctly on both (glasses stayed on the eyes through the whole breathing cycle, no
per-frame drift), surfacing two follow-on issues instead, both now fixed:

- **Equipped accessories rendered oversized and off-position on a wider preset, but not a
  narrower one.** Root cause: `NoriBreathingSprite`'s `Image` had no explicit `width`, and
  Flutter's default image layout only ever *shrinks* an unconstrained image to fit tighter
  constraints — it never grows one past its native pixel size (223×238 for these frames) to
  fill a more generous one. So on any screen offering more than 223 logical px of sprite
  width, the image's real rendered width silently stayed pinned at 223 while `spriteWidth`
  (used for the overlay's own scale/position math) kept assuming the larger offered width —
  the two only agreed by coincidence on screens narrow enough to stay under that threshold.
  This is a screen-width threshold, not a platform one — a wide-enough Android device would
  hit the identical bug — so it's fixed outright rather than documented as an iOS gap:
  `Image` now takes an explicit `width: spriteWidth`, forcing it to always render at the
  width the rest of the code already assumed.
- **Smart Glasses read too small** even where tracking/scale were otherwise correct. Its
  `_AnimatedAccessoryPlacement.scale` (0.27, inherited from the old fixed-placement value)
  undersized the lenses relative to his actual eye spacing (~0.27 of canvas width
  center-to-center) — bumped to 0.34 (with `dyFrac` recomputed from the same
  `-scale * 0.44 / 2` formula so it stays vertically centered on the eye line). Only
  `smart-glasses` was reported as wrong-sized, so the other four items' scales are
  untouched; revisit them the same way if they turn out to read too small/large too.
- **Still a small horizontal offset after the above two fixes.** `eyeMid`/`headTop`
  anchored accessories were relying on the parent `Stack`'s own `Alignment.topCenter` to
  center horizontally, which centers on the *canvas's* horizontal center (223/2 =
  111.5px) — but his tail sticks out on the left, which drags his alpha bounding box (and
  therefore that center-of-canvas point) left of where his face actually is. His actual
  face-symmetry axis, measured the same way as the other anchors (eye-midpoint x, which
  is 118.1–118.7px across all 67 frames — effectively constant), sits about 3% of his
  width to the right of that. Fixed by adding `kNoriFaceCenterX` (118.3,
  `lib/widgets/nori_frame_anchors.dart`) and computing an explicit `left` for every anchor
  kind in `animatedPositionedAccessoryArt` instead of only doing so for `tail` and leaving
  `eyeMid`/`headTop` to the Stack's alignment.

### 2026-09-11 — editing a habit from a past day silently destroyed today's progress

Fixed at the root cause identified in the audit: `MockHabitRepository.updateHabit`
(`lib/data/habit_repository.dart`) now always preserves the *live* `currentValue`/
`isCompletedToday`/`lastAwardedXp`/`lastAwardedCoins` from the stored today-habit,
via `habit.copyWith(currentValue: live.currentValue, ...)`, regardless of what those
fields happen to be on the `Habit` object a caller passes in. This makes the bug
structurally impossible rather than dependent on every caller carrying the right
fields forward — a past-day edit (or any future caller) can no longer clobber today's
state no matter what it passes. The interface doc on `updateHabit` was updated to
describe the new (safer) contract.

### 2026-09-11 — habit "Complete" button's underlying logic — investigated, not a bug

This was the "habit complete button's underlying logic" note attached to the past-day
bug above. Investigated and found `HomeScreen._claimHabit` was the odd one out: it
blocked tapping the checkbox below `isMinMet`/`isTargetMet` with a snackbar ("Log more
progress before completing this habit"), while `HabitsListScreen`/`CalendarScreen`
(via `HabitProgressCard`'s `_ProgressCard`) let "Complete" fire at any progress,
snapping straight to the full target/reward. First guess was that the *latter* was the
bug (0%-progress free XP), and a matching gate was added at the repository layer and
in the widget — but that was backwards. Confirmed (by whoever's driving): "Complete"
snapping straight to 100% regardless of current progress **is** the intended
behavior — a one-tap "I finished this" shortcut, like a binary habit's checkbox,
exactly as `_claimValue`'s own doc comment already said. `docs/FEATURES.md` §3's
"below minimum → no success" language describes the *reward tier* math, not a
prerequisite for the Complete button itself. Fix direction reversed: the
repo-layer/widget gate was reverted, and `HomeScreen._claimHabit`'s snackbar-block was
removed instead, so all three screens now behave the same — tap Complete, it jumps to
100% and pays the full reward, no minimum required anywhere.

### 2026-09-11 — evolution celebration never shown outside Home-tab actions

Root-caused: `PetRepository.syncEvolution` was called (and the pet's stage silently
updated) from four places — `HomeScreen._loadData`, `HomeScreen._reloadUserAndPet`,
`HabitsListScreen._applyReward`, `CalendarScreen._applyReward` — but only
`_reloadUserAndPet` (reward actions taken *while already on the Home tab*) ever
compared the before/after stage and called `showEvolutionCelebration`. A level-up
crossed while claiming from the Habits tab or Calendar evolved the pet with zero
visible feedback, and switching back to the Home tab afterward (`_loadData`, the
tab-switch reload path) didn't catch it either. All three other call sites now do the
same before/after stage check and show the celebration. Separately: the specific
originally-reported case (demo user level 5 → 7) likely wasn't actually eligible to
evolve regardless — `evolutionLevelThreshold` is 20 and still an open product decision
(see `docs/OPEN_DECISIONS.md` — Pet mechanics) — so that anecdote may have been a
false alarm for an unrelated reason even though the trigger-wiring gap it prompted was
real and is now fixed.

### 2026-09-11 — payment method screen rendered blank

Root cause found via a Flutter-web repro (not a headless-Chrome artifact — reproduced
identically in a normal, non-headless, freshly-restarted session): `_CheckoutBar`
(`PaymentMethodScreen`'s `bottomNavigationBar`) wrapped its content in `Center`.
`Scaffold` lays `bottomNavigationBar` out with a *loose* (not tight) height
constraint, and `Center`/`Align` with no `heightFactor` expands to fill all of the
space it's offered rather than shrink-wrapping to its child — so `_CheckoutBar`
ballooned to claim nearly the entire screen height, leaving `body` almost no room
(confirmed by swapping `body` for trivial placeholder content, which was equally
invisible). The checkout row itself still rendered, just vertically centered within
that oversized bar instead of pinned to the bottom, which is what looked like a
"blank screen with a floating price row." Fixed by changing `Center(child: ...)` to
`Align(heightFactor: 1, child: ...)`, which keeps the horizontal centering but makes
the bar shrink-wrap to its actual content height. Verified in a running instance:
full body content now renders, and the checkout button's snackbar fires correctly.

### 2026-09-11 — progress bar threshold tick rendered as a solid block

Root-caused via pixel-sampling a live render (see the still-open half of this finding
above): `ProgressBarPill`'s threshold marker used `FractionallySizedBox(widthFactor:
thresholdFraction, child: Container(width: AppBorder.standard, ...))` to try to place a
thin line at the threshold position. `FractionallySizedBox` gives its child a *tight*
width constraint of `widthFactor × available width`, which overrides the child's own
`width: AppBorder.standard` instead of just capping it — so the "line" rendered as a
solid dark block from 0% to the threshold. Fixed by computing the pixel offset via
`LayoutBuilder` and placing a fixed-width `Positioned` marker instead. Verified by
sampling fill colors before/after: before, a full block of `ink@0.5`-over-`moss`
(`rgb(100,103,70)`) spanned 0–50%; after, only a single-pixel-wide sample at exactly the
threshold position differs from the surrounding fill color.

### 2026-09-11 — Home habits panel: habit entries getting visually cut off

Root-caused: the expanded panel's scrollable list is capped at `ConstrainedBox(maxHeight:
screenHeight * 0.4)`, which essentially never lands on a whole-tile boundary, so the last
visible tile got hard-clipped mid-row with no visual cue the list was scrollable (it was
— confirmed by manually scrolling past the cut). Fixed with a `ShaderMask` fading the
list's bottom ~12% to transparent, applied only when the content actually overflows
(tracked via `NotificationListener<ScrollMetricsNotification>`, so a short list that
already fits isn't faded for no reason). Fading to transparent — not a solid color — was
the right call here specifically because the panel itself is translucent frosted glass
(`BackdropFilter` blur), so there's no flat background color to fade into.

### 2026-09-11 — `InventoryRepository.setEquippedAccessory` accepted any id

Now no-ops if `accessoryId` isn't in `ownedAccessoryIds` (`null`/unequip is still always
allowed). Unreachable via the UI today (`CustomizationScreen` only offers owned items),
but the data layer no longer relies on every future caller behaving.

### 2026-09-11 — habit / bucket-list item id collisions possible

`AddHabitScreen` and `BucketListScreen` generated ids from
`DateTime.now().millisecondsSinceEpoch` alone; two items created in the same millisecond
would collide and silently overwrite each other. Both now combine
`microsecondsSinceEpoch` with a random suffix.

### 2026-09-11 — `HabitsListScreen._onReorder` updated the UI before the repository call

Swapped the order: `AppData.habits.reorderHabits(...)` is now awaited first, and
`setState` only runs after it succeeds — so a failed reorder (once a real backend can
fail) leaves the displayed order unchanged instead of silently diverging from what's
actually stored.

### 2026-09-11 — two disagreeing streak sources

`NoriUser.currentStreak` was a static literal (`12`) that never changed, while
`MockCalendarRepository._currentStreak` walked real habit history and computed a
different number (`90`) — both shown simultaneously on Profile (confirmed via a
screenshot showing "12 Day Streak" and "90 days" on the same screen), and inconsistently
across Home/Calendar/Habits too. Fixed by making `MockUserRepository` depend on
`CalendarRepository` (mirroring how `MockCalendarRepository` already depends on
`HabitRepository`) and compute `currentStreak` live in `getCurrentUser()`, instead of
storing a stale copy. `NoriUser.copyWith` now also supports overriding `currentStreak`.
Verified: Home, Profile's streak chip, and Profile's Habit Statistics card all show `90d`
/ `90 Day Streak` / `90 days` consistently after the fix.

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
