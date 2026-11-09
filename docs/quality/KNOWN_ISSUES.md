# Nori — Known Issues

This file contains only currently open bugs and gaps, not a task queue tied to any
particular session — log something here the moment you notice it even if you don't plan
to fix it right away. When a fix lands, write a terse 2–4 sentence entry directly in
`docs/quality/RESOLVED_LOG.md` using `### YYYY-MM-DD — <short title>`: state what changed and
why, not a narrative. Then remove or trim the item from wherever it was listed as open
here — don't leave a closed item worded as if it's still a problem.

**Priority flags** — how urgent, not how easy:
- 🔴 **Critical** — active bug, data loss, or a core feature that's visibly broken
- 🟠 **Important** — real risk, accessibility failure, missing core feedback, or notable
  debt that will bite soon
- 🟡 **Minor** — polish, cosmetic, backlog debt, or a deliberate/known stand-in

---

## 🔴 Critical

(None open right now — see docs/quality/RESOLVED_LOG.md)

---

## 🟠 Important

### 🟠 Placeholder pictures: nearly done, one gap left (added 2026-11-07, mostly fixed 2026-11-08)

Social now shows real photos, friends' pets show the real Nori, and all 23 achievements have badge
art in one shared style, and circle and competition rows show their cover thumbnails (see
RESOLVED_LOG, 2026-11-08). What is still plain:

- The signed-in user's own avatar is still the default illustration (Google sign-in photo, if any,
  is not used), and picked photos are session-only (see "Picked photos are session-only" below).

### Fix before MVP launch (decided 2026-11-07)

- **Home and Habits don't roll over at midnight (CONFIRMED, 🟠).** They reload when you switch to
  their tab, but nothing reloads them when the app comes back from the background or the date
  changes. A phone left on Home past midnight keeps showing yesterday's habits (and their done /
  not-done state) while new actions write to today's log. Fix: a `WidgetsBindingObserver` that, on
  resume, compares the day key it loaded with today's and reloads when they differ (Home,
  `HabitsListScreen` and the Calendar's "today"); a timer at local midnight covers an app left in
  the foreground. Small, no backend change.
- **New accounts start with no habit categories (CONFIRMED, 🟠; the "nothing tells them" half is fixed, see RESOLVED_LOG.md 2026-11-07 "No-categories hint").**
  `onUserCreate` seeds `habitCategories: []`, so a first habit has an empty Category dropdown (its
  hint says "Choose or add a category"; the field is optional, so the habit then saves with a blank
  subtitle). Fix: seed Health, Study and Finance in `functions/src/onUserCreate.ts` (the demo
  account already has them) so a first habit needs no extra step; "Add Category" stays in the
  dropdown. Needs a redeploy of `onUserCreate`, and only affects accounts created after it.
- **Plans are chosen and the screens show them, but nothing enforces or bills them (CONFIRMED, 🟠).**
  Free / Nori Plus ($3.99/mo, $29.99/yr) / Nori Duo ($5.99/mo, $44.99/yr) are in
  docs/business/COTIZACION.md Part 2 (prices approved by valevasqc 2026-11-08; Jimena hasn't weighed in).
  The Nori Plus and payment preview screens now show them. Still open: the 5-habit and 3-goal Free limits
  exist nowhere in the code (the free demo account has 6 habits), checkout is a mock, no Google Play
  Billing, no ads, and Duo's account linking doesn't exist. The screens keep their "Preview only" banner
  until the Fase 2 work (COTIZACION.md §7) lands. Server-side limit design and estimate (~11 pts, after
  the demo): docs/technical/BACKEND.md, "Plan limits".

### Vacation mode: frozen days still unverified (2026-10-05)

Untested: how the calendar and streak treat a frozen *past or future* day, because a same-day
freeze changes nothing visible. Two things seen on the way (2026-11-03 QA pass): ending a freeze
the same day it started leaves a zero-length range (`start == end == today`) in `vacationRanges`
(UNRESOLVED whether anything reads that as a frozen day), and nothing outside Settings shows that
Vacation is on (no banner on Home/Habits, and the Calendar legend has no "frozen" entry).

### Instant-feedback pass 2026-11-05: what is still open

Not yet run in a browser or on a device (only read, `flutter analyze` and unit tests): Shop
purchases and equip, Home care items, the Habits list (claim/undo/progress, rollback, skeleton), the
Calendar (month cache, retry view, day sheet) and the XP/coin spinner. Real offline was never tried
either, only a script that blocks requests; a hung request rolls back only after the 20 s
`remoteTimeout`.

- **Undo returns to the pre-Complete value only for the current session (CONFIRMED, 🟡).** The value
  is remembered in memory (`PreClaimValues`), so after an app restart, Undo on a Completed progress
  habit leaves it at the target. Persisting it means a field on the day's log and a rules/function
  change; not done.

### External QA audit 2026-11-05 (`AUDITORIA_QA.md`): triage

Run by a helper against the production web build in a container (`192.168.0.17:8099`) and the live
`nori-pet` project, with two throwaway accounts it deleted afterwards. 12 of 12 server-side abuse
attempts were blocked (forged XP/coins, cross-account reads, repeat claims, future days, negative
quantities, username hijack), so the BACKEND.md protections hold. Triage of its findings:

- **F2 password floor of 6 on the server.** The app asks for 8+ with a letter and a number
  (`validators.dart`); Firebase still accepts 6 for anyone calling the API directly, and there is
  no live character counter or strength meter (the audit's suggestion, not built).
- **F6 `functions/Dockerfile` is a Docker exercise, not the backend: no code change.** The real
  backend is Cloud Functions; say so in the course write-up if the rubric asks for a containerized
  backend. These files are local-only homework (git-ignored).
- **Monetization docs contradict the Nori Plus preview ($4.99 / $39.99).** Noted under
  Monetization in OPEN_DECISIONS.md; the product call is yours.
- **Browser ad blockers break the app (`ERR_BLOCKED_BY_CLIENT`).** An ad blocker or Brave Shields
  blocks `firestore.googleapis.com` (seen on the helper's machine). It is not an app bug:
  Firestore's long-polling channel is refused, so loads fail or hang. Test with the blocker off for
  that site or in a clean profile.
- **Social "View standings" shows a full-screen green card on a desktop window (reported
  2026-11-05, not reproduced).** Widget tests of the Leaderboard and Competition screens at
  1400×900, 1400×500 and 900×700 (`test/screens/wide_social_layout_test.dart`) find no oversized
  card, so it likely needs the live account's data. Green cards on those screens are the
  highlighted own-row (`mossLight`), the rank-2 podium block and a competition header whose color
  is green. Which one filled the screen is the missing detail.

### QA pass 2026-11-03: bugs found (web debug build, 412×915, `demo@test.com`)

Full click-through of every tab plus the evolution path, with the browser console and Cloud
Functions logs read alongside. Static checks were clean (`flutter test` 73/73; `flutter analyze` one
`unused_element_parameter` warning at `lib/widgets/accessory_art.dart:204`). Everything below is
CONFIRMED unless marked otherwise.

- **`purchaseCareItem` lost its public Cloud Run binding on 2026-11-03; the cause is UNRESOLVED.**
  No `SetIamPolicy` audit entry explains when (the last deploy touching it was 2026-10-26 18:14,
  revision 00006). The console fix set `invoker-iam-disabled=true` (not an IAM binding), and all
  three callables now answer a CORS preflight with 204. Callable functions must be public at the
  Cloud Run layer because the real auth check is the Firebase ID token inside the function, and the
  same 403 would hit Android. The 401s on `deleteaccount`/`claimhabit` during the 2026-10-26 deploy
  look like the same problem (INFERRED: a deploy can drop the public binding). After any deploy,
  re-check that every callable answers a preflight with 204: `curl -s -o /dev/null -w "%{http_code}"
  -X OPTIONS <fn url> -H "Origin: http://localhost" -H "Access-Control-Request-Method: POST" -H
  "Access-Control-Request-Headers: authorization,content-type"`.
- **Minor:** the care sheet route has no semantics label (console warning on every open);
  "See pet" from a notification lands on Home with the habit panel open, covering the pet; the evolved
  sprite in the evolution overlay pops in late (blank circle for ~1.8s); Archived Habits "Restore"
  label crowds its button edge.

### QA pass 2 (2026-11-03, afternoon): second sweep, load times, more bugs

Second pass over everything the first one skipped, same setup. All Cloud Run services were checked
too: every function except the scheduled `petcarecheck` is public, all 9 callables answer a CORS
preflight with 204, and there were **zero 4xx/5xx responses** from any function during the whole run
(6 `purchaseCareItem`, 2 `purchaseAccessory`, 6 `claimHabit`, plus bucket-list and unclaim calls, all
200). XP, coins and level reconcile exactly against the logs (total XP 2,458 = habit logs 1,658 +
bucket goals 800; coins 505 = 1,215 earned − 710 spent). The older 401s on `deleteaccount`/
`claimhabit` (2026-10-26) are gone now (see the `purchaseCareItem` item above for the preflight check).

**Passed (no bug):** all 6 care items bought and used; both hats bought and equipped; all five habit
types (Binary, Quantity, Duration, Multiple, Limit) logged, completed and undone; previous-day
navigation and backfill; bucket list add/edit/undo/re-claim/delete; categories add/rename/delete;
archive and restore; edit-habit save; Edit Profile save; Replay intro; Nori Plus (preview only);
calendar month navigation; every Social screen opens (mock); Forgot Password dialog; wrong-password
login message; evolution at level 7 (earlier pass).

**New bugs**
- **Deleting a category used by a habit is allowed with no warning.** "Study" was deleted while "Read
  10 mins" used it; nothing broke (the edit form still shows the old label) but the habit now carries
  a category that no longer exists. Category and bucket-list deletes have no confirmation.
- **Nori Plus says Free is limited to 3 habits, but nothing enforces it** (the free demo account has
  6). Fine for a labeled preview; worth knowing before presenting.

**Load times (debug web build, Chrome headless, remote Firebase `nori-pet`; a release build will be
faster for boot, but the Firestore/function waits below are network-bound and will not change)**

| What | Time | Verdict |
|---|---|---|
| First login after starting the app | ~10–12s to a usable Home | **Too slow** |
| Login (warm) | route 2.0s, Home usable 4.3s | slow-ish |
| Cold reload with a saved session | Flutter up 3.5s, Home usable 7.6s | **Too slow**; ~4s is data loading after boot |
| Tab switch (Home/Habits/Calendar/Social/Profile) | 0.1–0.2s | fine (cached) |
| Previous day on Habits | 0.6s | fine |
| Calendar previous/next month | 1.6–1.8s each | **slow, no skeleton** (2026-11-07: title moves at once, visited months come from a cache, new ones show a spinner; the read itself is unchanged) |
| Open Settings / Shop / Achievements | 1.3s / 1.0s / 0.9s | borderline |
| Bucket List, Notifications, Archived Habits | 0.1–0.5s | fine |
| Complete / checkbox claim (Cloud Function) | 1.5–2.7s, first after idle 3s+ | XP/coins badge still waits for the function (2026-11-07: its icon spins until it lands) |
| Buy care item / accessory (Cloud Function) | 1.5–3.0s | 2026-11-07: the purchase now shows at once and the call runs behind it; the function time itself is unchanged |
| Add / edit bucket goal, archive, restore, rename | 0.6–0.8s | fine |
| Log out | 0.6s | fine (but shows the error above) |

**Still open, not solved.** On 2026-11-03 Home's `_loadData`, `getCurrentUser` (user doc + streak),
the calendar's month load and the shop's two reads were changed to run their independent reads
together (`Future.wait`; see RESOLVED_LOG.md). It did **not** measurably help: the Home data phase
(Flutter up → Home usable) was ~4.1s before and 3.5–4.2s after (two samples, debug build), so the
sequential awaits were not the main cost. UNRESOLVED where the ~4s goes. Next step is to time each
read in `_loadData` separately (suspects: the streak walk behind `getCurrentUser`, which reads habit
definitions, a 45-day log chunk and the vacation log in turn, and the definitions being fetched 3+
times per load). The actions in the table all work.

### QA pass 3 (2026-11-04): sign-up, delete account, profile, reorder

Run against live `nori-pet` with a throwaway account (created, used and deleted twice; the demo
account was only logged into). Backend verified with the Admin SDK, not just the UI. Cloud Run: zero
4xx/5xx from any function during the pass; the only 4xx were the expected auth rejections from
deliberate bad input.

**Passed:** sign-up validation (empty fields, short/taken username with a live hint, mismatched or weak
password, existing email, malformed email); full sign-up provisioning (Auth user, `/users` doc, baby
pet at 100/100/100, inventory, username claim); naming the pet; intro cards; first habit completion
(+20 XP, +10 coins, 1-day streak, sunglasses gift); creating a first category from Add Habit; the
verification-email banner (Resend with a 30s cooldown, Dismiss); email change with a wrong and a right
password; long-press drag reorder (persisted); **Delete Account** (wrong username and wrong password
both refuse; a real delete removes the Auth user, `/users` doc, every subcollection and the username
claim, in ~5s, and the old credentials no longer log in).

**Open**
- **The first claim after a quiet spell takes 3-8s** (cold start of `claimHabit`, also the first
  claim of a new account). Later calls are 1.5-2.5s. Warm the app up before a demo, or set `minInstances: 1` on
  `claimHabit`, `unclaimHabit` and the purchase functions for the demo window (small cost).
- **Google sign-in was never exercised in QA** (needs a real Google popup; Android also needs the
  signing key's SHA fingerprints registered in Firebase). On any other machine (e.g. a LAN IP) it
  fails until that address is added to Firebase Auth's authorized domains; only `localhost` works today.

### Cognitive load & interaction gaps (2026-09-10 audit)

- **Add Habit puts 13 decision points on one uninterrupted scroll**: name, icon (6
  options), category (4), tracking type (6), target, unit, min-threshold toggle+value,
  difficulty (3), repeat (4), custom days (7), end-date toggle+range, vacation toggle —
  none of it chunked into steps, so the page reflows under the user's thumb as conditional
  sections appear mid-scroll. By a fair distance the most demanding screen in the app.

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
FlutterFire's web plugin registration includes auth.

### Sign-up can still fail if onUserCreate cold-starts very slowly (2026-09-30)

`sign_up_screen.dart` writes the profile right after the account is created, but `/users/{uid}`
comes from the asynchronous `onUserCreate` trigger. The write retries for about 4s (8 × 600ms), so
a trigger slower than that still fails the first attempt (the person then taps Create Account
again and it resumes at the failed step). Never reproduced; a first sign-up after the function has
sat idle is the case to try in QA.

### UX/UI audit 2026-11-07 (after the bug-fix round): what the quick-win pass did not fix

Rendered every tab and the Shop, Customization, Add Habit, Bucket List, Notifications, Achievements
and Settings at 412px as `demo@test.com`; the quick wins are in RESOLVED_LOG.md. Welcome, Login and
Sign up were not looked at (can't sign back in from the browser). Accessibility is out of scope.
CONFIRMED unless marked.

- **Top bar: one header for all five tabs (decision pending, valevasqc is undecided 2026-11-07).**
  Suggested rule: title left, then XP pill, bell, at most one action for that tab; no decorative
  avatar (it isn't tappable on Calendar, Profile or Social); streak stays in the content. Today Home is
  a HUD card, Habits stacks the XP pill alone above its title, Calendar and Profile lead with an
  avatar, and Social adds a bell and a menu. Would become one shared `NoriTabHeader`. Mockups are in
  the "Nori UX proposals" artifact (section 1).
- **Demo account shows "Please verify your email address" on every tab (🟠).** It can never verify,
  and the banner takes two lines at 412px; dismissal lasts one app session only. Best fix is data:
  set `emailVerified: true` for demo@test.com (e.g. in `resetDemoAccount`, needs a deploy), so no app
  code special-cases it.
- **Tab headers use four layouts (🟠, still open; confirmed again 2026-11-08).** Home is a HUD card;
  Habits is now XP + streak on the left, flag + bell on the right, and the title on its own line below
  (reorganised 2026-11-08, see RESOLVED_LOG.md); Calendar and Profile are avatar + title + XP pill;
  Social adds a bell and a menu. XP is on every tab. One shared tab header would fix it, and the
  Habits layout above is a reasonable starting point for it.
- **Add Habit (🟠).** Three XP figures for one choice ("Medium · 20 XP", "Medium 16-24" in the Adaptive
  XP note, "+20 XP" in the preview). It opens on Quantity rather than Binary (the hint text and icon
  match Quantity, so it may be deliberate: your call). Difficulty and Repeat chips wrap and leave one
  chip alone on a second line; the 5 tracking-type cards leave one alone in a 2-column grid.
- **Habit card wording (🟡).** The same action is "Complete", "Claimed", "Completed" and "Mark Day
  Safe". Binary habits have a checkbox that shifts the title right, so titles don't line up between
  cards. Seven solid dark-green Complete buttons in a row are heavy: a lighter secondary style for
  Complete would calm the list. `Limit / Negative` is still the type's label in the add form.
- **Shop (🟡).** (Baby-sprite previews after evolving moved up to "Fix before MVP launch".) Dino Onesie now has art (2026-11-08). "Buy · +3" doesn't say that +3 is the quantity you get.
- **Small text (🟡).** `labelSm` (11px) is used about 100 times, including text people need to read:
  habit category lines, tracking-type descriptions, helper text under fields, reward pills, "Completed
  to bottom". Raising it to 12 and moving descriptions to `bodyMd` is a global change that needs a
  look at every screen for overflow, so it was not done blind.
- **Home HUD (🟡).** Avatar, name card, coin pill and Shop button are four different heights, and the
  name card sits over the round window in the room art.
- **Calendar (🟡).** Four big stat tiles push the grid below the fold; the legend's "Missed" (cream)
  and "Upcoming" (white) are hard to tell apart and "Upcoming" wraps onto its own line; every day cell
  has the same heavy border so the grid looks busy.
- **Bucket List (🟡).** The subtitle and "2 / 3 completed" start further left than the cards below;
  goals not done look grey and finished ones bright (the reverse of expectation).
- **Notifications (🟡).** Identical "Nori is feeling lonely" messages stack day after day (collapse
  into one line with a count). Icon circles are heavy dark fills against a pastel palette; unread dots
  differ in color per type.
- **Achievements (🟡).** Locked trophies with illustrations look more rewarding than unlocked flat
  icons (see also "Achievements could look better" below).
- **Card-in-card nesting and filler copy (🟡).** Settings' "Free Plan" card holds a single Nori Plus
  row. "Keep up the good work!" shows at 0/7. All-caps appears only in "AVAILABLE BALANCE" and the
  notification category labels.
- **Wardrobe (🟡).** Not tested whether the accessories panel's drag handle drags.
- **Inbox follow-ups (🟡).** The merged inbox's "Pet" filter also holds achievements, streaks and
  level-ups, so the name may confuse (rename is a one-line change in `NotificationFilter`). The old
  Social inbox's "Clear" button was not carried over. The reward chip on claim shows the card's
  preview amount; if the server pays a different amount (adaptive XP) the chip and the XP pill can
  differ by a few points (INFERRED, not seen).
- **Developer row (🟡).** "Reset demo account" is visible on demo@test.com, so anyone looking at the
  demo sees it; hide it in release builds or behind a debug flag if the demo gets shown.
- **To check on the Android phone.** Tap feel of the 36-41dp buttons, system font scaling with all the
  11px text, status bar / notch over Home's top bar, and animation smoothness. The new floating add
  button and the red care rings were seen at 412px in Chrome only.

### Android phone pass 2026-11-08 (moto g 20, Android 11, 720x1600, `demo@test.com`): open items

First run on a real phone (fixed items are in RESOLVED_LOG.md, same date). Open:

- **Achievement preview tiles keep a lot of empty space at the bottom (CONFIRMED, 🟡).** After
  top-aligning, a 2-line title leaves a gap under shorter ones; `childAspectRatio` 0.72 could be
  tuned (check it with the system font size raised first). valevasqc: leave it for now (timing),
  keep it logged.
- **Calendar day cells are 41x41dp, just under 48dp (CONFIRMED size, 🟡).** Measured on the moto g 20;
  valevasqc chose to fix only the bottom nav (done 2026-11-08), so the cells stay as they are. Taps
  landed fine in this pass.
- **Profile "Habit statistics" has no cap (UNRESOLVED, 🟡; raised 2026-11-08).** It lists every habit
  (the 30-day breakdown), so it grows with the account. Proposed: Profile keeps weekly completion plus
  the first few habits (best and most missed) and a "View all" to a dedicated Statistics screen, the
  same pattern as "My achievements". Needs a yes and a choice of how many to preview.
- **"Reset demo account" is partial (CONFIRMED, 🟡).** It reverses bucket-list payouts and tops up coins
  and care items, but does not undo habit claims or return the account to the documented baseline
  (level 6, 1,524 XP, 760 coins); that still needs an Admin SDK script. Unclaiming a habit does not
  give the XP back either (Undo now does, but the reset script predates it).

### UX/UI audit 2026-10-26: what the easy-win pass did not fix

Whole-app audit (code + a rendered pass on a 412×915 viewport, signed in as `demo@test.com`; the
easy wins are in RESOLVED_LOG.md). Labels: **CONFIRMED** = seen in the render or in code,
**INFERRED** = likely but not reproduced, **UNRESOLVED** = needs a decision.

- **Small tap targets may cause mis-taps for everyone (CONFIRMED sizes, UNRESOLVED impact, 🟡).**
  Judged by whether an average user misses taps, not as a disability issue. Sizes: Home's header
  Shop button and other `CircularIconButton`s 36dp, the email banner's dismiss and every "More"
  menu 40dp, Calendar day cells 41dp, Social's Nudge/Details/See all/reaction/Mark Achieved buttons
  ~32dp tall (Social is showcase-only). 36-41dp is usable for most people; ~32dp is the likeliest
  to be missed. On Android Flutter may already pad small buttons to a 48dp touch area, so the real
  problem could be smaller than these sizes suggest. Try it on the phone first, and raise this to 🟠
  only if taps visibly miss. The Habits header is done (2026-11-07, see RESOLVED_LOG.md);
  `CircularIconButton` now has a `largeTapTarget` option for other headers, and Home's is next.
  Calendar's header still has the old one-row chip + pill layout. The new Habits header has not been
  looked at on a screen yet.
- **Add Habit: the red field errors have not been seen on a screen (🟡).** A failed Save scrolls
  to the field, focuses it and shows the message in red under it (2026-11-07), checked only with
  `flutter analyze`. Look at it once at 412px; a stepper would still fix the 13-decision-point
  finding above.
- **Snackbars are the only feedback channel, and none has an action (CONFIRMED, 🟡).** All 16 use the
  default duration with no Undo. The ones that most want it: archiving a habit ("restore it from
  Archived habits"), deleting an unfinished bucket-list item (deletes instantly, no dialog, no undo),
  and shop purchases (one tap spends coins; fine at current prices, revisit if prices grow).
- **No FAQ or help screen (CONFIRMED, 🟡).** Intro cards and one-time hints exist (RESOLVED_LOG.md),
  but Nielsen #10 is still the weakest heuristic: nothing to look up later. Overlaps "First-run
  help" below. Jargon a first-timer will hit unexplained: "Minimum Threshold: Streak protection",
  "Adaptive XP" (the limit button, now "I stayed under", has a one-time hint).
- **Settings is sparse (CONFIRMED, 🟡).** It renders only a few small cards. Missing change
  password, notification preferences, about/support; what else belongs there is a product/IA
  call, not a styling tweak.
- **No dark theme and no Dynamic Color (CONFIRMED, UNRESOLVED).** Android's Material guidance treats
  dark as a first-class scheme. A product call given the hand-drawn linen look; log it so it's a choice.

**Found while building the intro/hints (2026-10-26)**
- **Nori's sprite doesn't show distress (CONFIRMED, 🟡).** At 0% on all three vitals the pet looks
  exactly as content as at 100%. The Home rings now turn red with a dot below 30 (RESOLVED_LOG.md,
  2026-11-07), so the need is visible; mood sprites (new frames per mood, for both forms) are an art
  problem and not planned.

**Consistency**
- **Login and Sign up don't match (CONFIRMED, 🟡).** Login has Google sign-in, a password visibility
  toggle and placeholder-only fields; Sign up has labeled fields, no Google option and no visibility
  toggle. Sign up's hints ("Alex Human", "••••••••") read as already-filled values, especially the
  dots in the password fields.
- **Soft blur and gradients on Welcome (CONFIRMED, 🟡).** Two blurred color blobs behind the page and
  a blurred shadow under the mascot card go against DESIGN.md §5 ("no soft shadows, no gradients").
  Either intentional for the first impression (then note it in DESIGN.md) or remove.

**Flows**
- **Whole habit row toggles the claim (CONFIRMED, 🟡).** On Home/Habits a binary habit's entire tile
  is the claim target, so a tap meant to scroll or open the menu can claim it. Unclaim undoes it, so
  low risk, but there's no claim feedback to notice the mistake (see "No reward feedback on claim").
- **Social odds and ends (CONFIRMED, 🟡; Social is frontend-only).** "Nudge" on Friends is plain
  text with no button look; Add Friend's Search button sits disabled with no hint why; Post Proof
  promises "+50 XP", which nothing pays yet (INFERRED from "Social tab is frontend-only").

### Code audit 2026-11-07: what the fix pass left open (code only, no UI/UX)

Whole-codebase code pass; the fixed items are in RESOLVED_LOG.md (same date). Open:

- **Functions not deployed yet (🟠).** The `petCareCheck` hardening and the small refactors in
  `resetDemoAccount`, `uncompleteBucketListItem` and `seedPlan` are in `functions/` only until
  `firebase deploy --only functions` runs. Until then a forged `pet/main.lastDecayAt` can still
  stop the hourly reminder run. (A `lastDecayAt is timestamp` check in the pet update rule would
  also close it at the source, but it's a console-synced rules deploy and the function now copes.)
- **The creation-day check is off by up to a day both ways (CONFIRMED, 🟡).** `createdAt` is an
  instant, but `claimHabit`'s `toKey` runs it through `localDayKeyOf`, which rounds to the nearest
  midnight, so a habit created after local noon counts from the next day in the adaptive-XP window
  (the client's `isScheduledOn` truncates, so they disagree). The existence check uses a flat 25 h
  allowance (`claimHabit.ts:59`), so a habit created at 00:30 can still be claimed for the day
  before. Fix: one helper that turns an instant into the caller's local day without rounding, used
  by both.
- **Creating a habit offline can save it later (PLAUSIBLE, 🟡).** `createHabit` is a plain `set`
  (`habit_repository.dart:692`); Firestore queues it, so the app can report failure and the habit
  appear on reconnect.
- **Complete, then Undo quickly, can end up completed (PLAUSIBLE, 🟡).** The two callables run
  concurrently (`optimisticHabitEdit`) and nothing orders them per habit. Not reproduced.
- **Smaller UI-code items (🟡).** Notifications: if the second load phase fails after stored items
  rendered, no error shows (`notifications_screen.dart:32`). Home's quick-log chip has no width cap,
  so a very long unit could overflow the row (`habit_tile.dart:110`, MEDIUM).
- **Duplication left (🟡).** `NoriBreathingSprite` and `NoriEvolvedSprite` share their controller,
  precache and reduced-motion code; left alone because accessory placement depends on them and each
  change needs a live render (see "Accessory placement"). Bucket caps and the weekly limit are
  hand-copied between `bucket_list_item.dart` and `bucketRewards.ts` (cross-language; keep in sync
  by hand like the shop catalogs).
- **Oversized files (🟡).** `add_habit_screen.dart` is ~1,330 lines with a ~470-line `build`;
  `home_screen.dart` is ~1,280.

**Decided 2026-11-07 (valevasqc): claiming a day the habit isn't scheduled on is fine.** The app
never offers it (the "not due today" list is edit-only), and each habit-day pays once anyway.

### Code audit 2026-10-26: what the quick-win pass did not fix

Whole-codebase code-quality and security pass (backend: `functions/`, `firestore.rules`, the Dart
data layer; frontend: every screen and shared widget, code only, not UI/UX). Checked against the
OWASP Secure Coding checklist and Google Cloud's Architecture Framework. The fixes that were quick
and safe are in RESOLVED_LOG.md (same date); everything below is still open. Line numbers are as of
this pass.

**Security and backend**

- **Usernames are only kept consistent by the client (CONFIRMED, 🟠).** `firestore.rules` lets
  `users/{uid}.username` be set to any string, so it isn't tied to `/usernames` (a modified client
  could show someone else's handle once Social is real). One uid can hold any number of names, and
  `usernameForUid` uses `.limit(1)`, so which name comes back is arbitrary if there are several. The
  app writes the index and the profile in one transaction, but the rules don't require it. Fix
  shape: in the rules, require
  `exists(/databases/$(database)/documents/usernames/$(request.resource.data.username.lower()))`
  owned by the caller. Rules are hand-synced with the console, so this needs a deploy. (The id
  length/character check on `/usernames` creates is deployed as of 2026-11-05; it does not tie
  `users/{uid}.username` to the index.)
- **No App Check, budget alert, or API-key restriction (CONFIRMED, 🟠).** Any client holding the
  (public, committed) Firebase config can call every callable. Open: App Check (`enforceAppCheck` on
  the callables), a billing budget alert, and restricting the API key to the Android app in the GCP
  console.
- **`careItemCountsOnlyDecreased` hard-codes the six item ids (CONFIRMED, 🟡).**
  `firestore.rules:7`. An inventory missing one key makes the rule error, which denies *every*
  inventory write including equipping; a seventh item would have no guard at all. Worth reworking
  before the catalog grows. (The `>= 0` floor is done, see RESOLVED_LOG 2026-11-07.)
- **`petCareCheck` won't scale (CONFIRMED, 🟡).** Now every 6 hours instead of hourly (code changed
  2026-11-08, **not deployed yet**: run `firebase deploy --only functions:petCareCheck`), which cut its
  reads 6x but not the problem below. `functions/src/petCareCheck.ts` reads every pet
  and runs one transaction per notified user, one after another. Fine at today's scale; batch the
  checks, or query only recently-cared-for pets (needs a collection-group index on `lastDecayAt`),
  when it matters. Dormant pets no longer get reminders, but their old notifications still can't
  be deleted.
- **No spend cap on Firestore or Auth, no App Check (CONFIRMED, 🟠).** Firebase spend caps only cover
  Functions/App Hosting/AI Logic/Extensions, and the project has them on Functions and Cloud Run
  (BACKEND.md, "GCP sprint status"). Firestore reads and writes can only be alerted on (a $5 and a
  $1 early-warning budget), so a looping or forged client could run up cost before anyone reads the
  email. App Check (Play Integrity) would reject non-app clients; not started. A billing kill switch was
  considered and rejected: it takes the whole project, user data included, offline.
- **Client writes have no type or length validation in the rules (CONFIRMED, 🟡).** Name,
  `habitCategories`, notification `message`, habit and bucket-list text fields, and the pet name
  (the app caps it at 20, the rules don't). Only affects the user's own data today; matters once
  other users can read it. A pet-name rule needs care: `pet/main` updates re-send the existing name,
  so a length rule could block care actions for pets named before the limit.

**Need a decision (game design, not fixed on purpose)**

- **Tomorrow can be claimed a day early (CONFIRMED).** `parseDayArgs` accepts any UTC offset up to
  +14h, so tomorrow's dayKey passes the "not in the future" check if the client claims a +14h
  offset. Each day still pays once; only the timing is off.
- **Achievements read only the last 90 days (CONFIRMED).** Every count-based achievement is
  capped by that window, so a long streak or a high total can't keep growing past it. The
  completion-count ones top out at 50, well inside it, so nothing is unreachable today; a future
  bigger tier would need a Firestore `count()` query instead. Also: "On Track" checks every active
  habit rather than today's scheduled ones, and "Habit Architect" counts habits active today, not
  habits created.

**Data correctness**

- **Mock repositories have drifted from the Firestore ones (CONFIRMED, 🟡).** The mocks only run
  signed out and in tests, but: mock binary claims compute the reward before marking complete
  (returns 0 XP), mock "today" ignores the schedule, mock habits have no `createdAt`, mock state
  doesn't roll over at midnight, mock bucket-list un-complete still takes the reward back, and mock
  pet decay truncates to whole minutes and resets its clock on every read.
- **Nori+ ignores the selected plan (CONFIRMED, 🟡).** Checkout always shows yearly; premium is
  mock.

**Efficiency (Firestore reads)**

- **Archived Habits runs one log query per archived habit (CONFIRMED, 🟡),** just to decide whether
  Delete is offered (`archived_habits_screen.dart:45`).
- **Every social write reloads every mounted social screen,** including covered routes and the
  hub, and each reload re-reads the user from Firestore. Accepted: Social is a showcase (see the
  scope note under "Social tab is frontend-only").

**Modularity and duplication: what's left after the 2026-10-26 clean-up (CONFIRMED, 🟡)**

What remains is deliberate or needs a decision:

- **Rules that live in more than one language.** Care-item and accessory prices
  (`firestore.rules`, `functions/src/shop.ts`, the Dart catalogs), `MAX_DELETABLE_ACTIVE_DAYS` (TS
  and Dart), and the pet decay rate (`kPetDecayPerHour` in Dart, `PET_DECAY_PER_HOUR` in
  `notifications.ts`) are each hand-synced, with a comment at every copy.
  `test/data/catalog_sync_test.dart` now fails if the prices, grants, item ids, delete limit or
  decay rate drift apart, so editing one copy without the others is caught by `flutter test`. One
  shared `catalog.json` still isn't a quick win: `functions/` deploys on its own, so it can't import
  a file from the repo root, and the app would need it bundled as an asset too. Worth it only if
  the catalog grows.
- **Home keeps its own claim handler (also the old "Duplicated logic" audit item).**
  `HomeScreen._runClaim` is today-only, uses the plain `claimHabit` methods, and detects level-ups
  by diffing before/after state so a claim made on another tab still celebrates on switching back.
  `HabitDayActions` (Habits list, Calendar day sheet) celebrates from the claim result's flags
  instead; both share `OptimisticHabits` for the instant-feedback updates. Merging them would change when Home
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

### Accounts left without a username are never cleaned up (2026-11-07)

"Not you? Use a different account" on the username picker signs out but leaves the Firebase account
behind: the Auth user plus the `/users`, pet and inventory documents `onUserCreate` made for it, with
no username claimed. Harmless (it can't hold a name, shows up nowhere, and resumes at the picker if
that account signs in again), and sign-ups abandoned before the username step leave the same thing.
Future tidy-up: a scheduled Cloud Function that deletes accounts with no claimed username after
about a week, reusing the `deleteAccount` teardown. Not for the MVP: it is a new function plus a
deploy, and a bug in a bulk delete is costly, so give it a dry-run mode first. Deleting on the
spot instead was rejected: `deleteAccount` needs a sign-in from the last 5 minutes, which a person
stuck after an app restart no longer has.

### Picked photos are session-only (2026-11-05)

A profile picture or proof photo chosen from the device lives in memory (`SessionPhotos`) and is
gone on restart or sign-out; `avatarUrl` still only comes from Google sign-in. Persisting it needs
somewhere to store the file (Firebase Storage is not enabled on `nori-pet`; or a small resized
data-URI in the user doc), the save code writing `avatarUrl` (the rules already let the owner write
that field), a "remove photo" action, and an Android camera/gallery check.

### Profile email is only synced to a confirmed email change on the next Edit Profile save (2026-10-26)

Edit Profile shows the login email (`AppData.auth.currentEmail`) and writes it to the
`/users/{uid}` doc on save, so after the confirmation link is clicked the Firestore `email`
field stays stale until the user next saves that screen. Nothing else displays it today. Also
note Firebase signs the user out once the change is confirmed, so they log back in with the new
address — worth confirming in QA on a real inbox.

### claimHabit still trusts two client-written habit fields (2026-09-24, found while implementing it)

`claimHabit` no longer trusts the habit doc's `xpReward`/`coinReward`/`adaptiveMultiplier`
(it derives base rewards from `difficulty` and clamps the multiplier — see docs/technical/BACKEND.md's
Cloud Functions list). Two smaller cheats are still possible, because `firestore.rules`' habit
`allow create` accepts any payload: (1) a client can create a habit with a backdated
`createdAt`, then claim it on every past day back to that date; (2) a client can create any
number of habits and claim each one daily. Each claim is capped at 45 XP (hard × 1.5), so
this stays the bounded "moderate" trust level docs/technical/BACKEND.md chose, not an open mint. The fix,
if it's ever worth doing: require `createdAt == request.time` in the create rule (the client
would send `FieldValue.serverTimestamp()`, and `FirestoreHabitRepository.addHabit` would need
to switch to that).

### Pet vitals are a direct client write, so buying care items is optional (2026-09-28 audit)

`firestore.rules` lets a client set `hunger`/`hygiene`/`happiness` on `pet/main` to any value,
so a modified client can keep the pet at 100 without spending coins on food/care items. This is
the trust level chosen for cosmetic stats (docs/technical/BACKEND.md); logged only because the shop economy
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
release SHA-1). Run one before Demo Day, not on it. No Android SDK is set up on the dev Mac (`flutter doctor`
reports it missing), so nothing has run on a real Android device either.

### Dart mock still has a 75% "min" reward tier (2026-09-28 audit)

The server has no partial tier anymore (the minimum threshold keeps streaks but pays nothing —
FEATURES.md §3), but `HabitRewardTier.min` (0.75×) and `Habit.rewardTier` in
`lib/models/habit.dart` still exist and drive `MockHabitRepository`'s rewards. Since claims snap to
the target it's rarely reached, but it's a second copy of the reward rule that now disagrees with
`functions/src/rewards.ts`. Remove it once nothing in the UI reads the tier.

### functions/ has 10 transitive npm audit findings (2026-09-24, scaffold; recounted 2026-10-26)

`npm audit --omit=dev` now reports 10 (9 moderate, 1 high), all inside `firebase-admin`'s own
Google Cloud dependencies (`google-gax` → `gaxios`/`teeny-request` → `uuid`, `retry-request`).
Nori's functions never call those packages directly, so this is hygiene, not urgency. Fixing it
means the major upgrades `firebase-admin@14` and `firebase-functions@7`; now that the functions
have tests (`npm test`), that upgrade can be regression-checked instead of done blind.

### Tail Charm Clasp doesn't show on the evolved Nori (2026-11-04, deliberate)

Head accessories (crown, bow, sunglasses, goggles, chef hat) now track the evolved form (see
docs/quality/RESOLVED_LOG.md, 2026-11-04). The **Tail Charm Clasp** is the exception: the evolved tail is
hidden behind the wings or legs for roughly three quarters of the loop, with only a small stub
visible mid-hop, so a charm hung on it would float in mid-air. It stays equipped but is not drawn
once the pet evolves (`accessoryFitsEvolved` in `accessory_art.dart`).

**Intended resolution (valevasqc, 2026-11-04; not built):** in the real app the tail clasp would be
replaced by a similar accessory that does fit the evolved form — e.g. swapping the old piece for a
new one in the player's inventory when the pet evolves — rather than giving the clasp its own spot
on the evolved art. Open details when this is picked up: what the replacement is, whether the swap
is automatic or offered, and what happens to an already-equipped/owned clasp (refund, convert, keep
for the baby form). Until then, players can still buy and equip it on an evolved pet, and nothing
tells them it won't show; the Shop's evolved preview of the clasp just shows a bare evolved pet.

### Neck/hand accessory anchors not implemented (necktie, bow, hand-held items)

Per-frame anchor points now exist for eye-midpoint and head-top (see docs/quality/RESOLVED_LOG.md,
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

### Remaining layout defects (2026-09-10 audit; re-verified against current code 2026-09-15)

**Not re-verified** (kept as originally audited, no update):
- **Customization header title centering**: the `const SizedBox(width: 48)` spacer
  (`customization_screen.dart:151`) is still a hardcoded guess rather than a shared/
  measured value, but it happens to equal the default `IconButton` tap-target width it's
  balancing, so there's likely no visible misalignment today — a code-quality nit, not a
  confirmed visible bug. Downgraded from "worth a visual check" to "leave alone until it
  actually misaligns."

### Architecture: component duplication instead of reuse (2026-09-10 audit; remaining items deliberately deferred)

Still open — deliberately deferred, these couple decoration to something else
(tap-ripple, animation, or an already-compound local layout) so a plain shell swap
would either add risk or not actually reduce duplication:

| Concept | Status |
|---|---|
| Tap-ripple cards (`Material`/`InkWell`/`AnimatedContainer` wrapping their own decoration) | Not migrated to `NoriCard` — `habit_tile.dart`'s `InkWell(child: Container(...))`, `nori_list_row.dart`'s `NoriListRow` (`Material` shape + `InkWell`), and `payment_method_screen.dart`'s `_PaymentOptionCard` (`AnimatedContainer` color transition) each need the border radius to stay in sync with a ripple/animation, not just a static decoration — left bespoke rather than force-coupling two widgets' radius values. |
| Compound local shells (`_CardShell` in habit_progress_card.dart's *content*, `_ItemCardShell`'s inner tile in shop_screen.dart) | Each file already deduped its own 2-3 variants into one local widget before this pass — `NoriCard` now backs each shell's outer `Container`, but the compound layout inside (claim/unclaim buttons, badge overlay) stays local since it's not decoration, it's behavior/layout specific to that screen. |
| Remaining un-migrated card classes | Reviewed 2026-10-26 with a scan for containers that are exactly a solid color + radius + ink border: `_TypeCard`, `_PlanCard`, Customization's slots and the payment options have tap-ripple, selected-state or animated styling, so they stay bespoke. |

### Dead code (2026-09-10 audit)

Desktop-vs-mobile branching is still deliberately left in place in two screens, both documented
as structural deviations rather than plain copies of the dead pattern: `HomeScreen` (its own
`Align`+`SizedBox` layout, not `Center`+`ConstrainedBox`, with a code comment explaining why) and
`CustomizationScreen` (700 vs. 800 threshold, and per-child padding instead of one outer padding —
doesn't share the other screens' structure closely enough to retrofit safely). **Not** part of
this: `CustomizationScreen`'s grid breakpoints at 440/620, `NotificationsScreen`'s `< 360` check,
and `PaymentMethodScreen`'s form-layout breakpoint at 440 are real in-phone breakpoints and should
stay.

**Decision (2026-11-07, valevasqc): keep them.** A working desktop layout is not dead code, so
these two `isWide` branches stay. Don't remove them as part of a cleanup pass.

### Minor / cohesion (2026-09-10 audit)

- `NoriShell` uses `IndexedStack` (`lib/navigation/nori_shell.dart:35`) to keep every tab
  mounted, so `NoriBreathingSprite`'s `..repeat()` animation (`nori_breathing_sprite.dart`)
  keeps repainting its 67-frame loop the whole time the user is on Habits/Calendar/
  Social/Profile, not just Home. `IndexedStack` is the right call for preserving scroll
  and panel state (see the doc comment at `home_screen.dart:27-32`) — this isn't an
  argument against it, just a note that the sprite itself should pause when off-screen.

### Testing backlog (2026-09-10 audit)

Tests exist (`flutter test`: habit JSON/archive, pet care, social, calendar rules; `npm test`
in `functions/`: rewards, XP curve, adaptive XP, request parsing, notifications, seed plan, 42 in
all). Still untested: `shop.ts`, `bucketList.ts`, `deleteHabit`/`deleteAccount`, every transaction
path, and the Firestore repositories. The original list, some of it possibly covered by now: (1)
`Habit.computeReward()`/`rewardTier` (`lib/models/habit.dart`) — the economy math, five
consumers, zero coverage, test the `limit` type first since its pass/fail logic is
inverted from the other five types; (2) the claim → unclaim round-trip on
`MockHabitRepository` — assert the XP/coin delta nets to zero, since a drift here is
invisible in the UI and would go unnoticed for weeks; (3) a regression test for the
past-day edit bug (fixed 2026-09-11; the test is not written); (4) `Habit.isScheduledOn` — decides which habits appear on
every day, calendar cell, and the streak walk, so an off-by-one silently rewrites history
with no crash; (5) `MockUserRepository.addXp`'s level-boundary math (crossing up,
crossing down on an unclaim, floor at level 1).

### Achievements could look better (dictated 2026-09-10; 14 of 18 still flat icons)

Only 4 of 18 (`habit-architect`, `on-track`, `perfect-week`, `first-step`) have real crest art; the
other 14 still use the flat Material-icon badge treatment. Whoever's driving has more art to generate for the rest —
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
clients write their own numbers. Proof photos picked on the device are kept in memory for the session
(`SessionPhotos`); there is no Storage in the stack. "You" is real (2026-10-21): `getMe()` reads the signed-in
account's name, username, level, XP, streak and pet, plus XP awarded over the last 7 days
(`lib/data/social_account.dart`, reads only; falls back to the seeded "Hannah Walker" if a read
fails), and the proof composer lists your habits completed today (sample list if none). Not yet
verified against live Firestore with a real account. Because weekly XP is real and the friends are
seeded at 400–1,450, a light week ranks you last. `proofCount` and your side of friend-streak
days are still seed data. Mock-only
leftovers to delete with the mock: `resetDemo` and the hub menu's "Preview: no friends yet" items,
and `tool/social_preview.dart` (renders any social screen without sign-in: `flutter run -d chrome
-t tool/social_preview.dart`, `?screen=<name>` / `?empty=1`).

Social achievements (2026-10-26): the Social category in `achievement_repository.dart` has five
live achievements — Better Together, Helping Hand, Proof Pal, Circle Starter, Accountability
Duo — computed from `SocialRepository.getSocialActivity()`, i.e. from the mock social data, so
their progress is placeholder until social has a backend (and resets on app restart).

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

The intro cards and one-time hints shipped (docs/quality/RESOLVED_LOG.md). Left: the Add Habit terms that
still lack a plain-language explanation, and any hint for Home (kept
off on purpose, it's already dense). A hint is one `Tip` value plus one `OneTimeHint` if wanted later.
Also worth knowing: the seen-state lives in `shared_preferences` (`TipsStore`, keyed by uid), so
it is per device. A reinstall or a second phone replays the intro and every hint, and if storage
fails the hints default to seen rather than nagging. Moving it to Firestore was judged too much
(a rules change plus a deploy) for something this small.

### Accessory placement: confirm each item on a real render (2026-09-14, status unverified since)

Each accessory renders in up to three places: the Shop/equip icon (`AccessoryItem.image`), the
static Customization preview (`_kPlacements` in `lib/widgets/accessory_art.dart`) and the animated
Home sprite (`_kAnimatedPlacements`). As of 2026-09-14 only Sunglasses was confirmed on both
screens; placement fixes landed since (RESOLVED_LOG.md, 2026-11-04 and later) but no
item-by-item confirmation is recorded. When picking it up, render each item at ~412px width and
adjust from what is on screen, one item at a time, rather than re-deriving numbers from the
reference sheets.

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
  — its flatness is a *content* gap, not a visual-treatment one; see "Settings is sparse"
  (UX/UI audit above).

Deliberately not attempted this pass: implementing these blind risks the same
"looks-wrong-in-code, still-wrong-on-screen" cycle the accessory-placement work hit (see
above) — any of the above should get a live render check (`flutter run -d chrome` at the
~412px mobile viewport) before being called done, not just a code read. Flagging with
concrete fix shapes rather than shipping unverified.

### Accessibility and Android guidelines (decided 2026-11-07: last priority)

This is a class project and we are not designing for users with disabilities, so screen-reader and
color-blind items are dropped. Readability for the average user is not (see RESOLVED_LOG.md,
"Text contrast"). What is left, all to check on a real phone:

- **Text scaling at 1.3x was never rendered (UNRESOLVED).** Plenty of ordinary users set a larger
  font. Code looks safe (the bottom nav was already fixed for it and only one fixed-height text
  wrapper was found), but nothing confirms it. Set Settings > Font size to Large and look for
  clipped or overflowing text.
- **Contrast fix not yet seen on a screen.** The darker text tones were checked by ratio and
  `flutter analyze` only. Look at Home, Habits, Calendar and Profile once.
- **`moss` as a text/icon color is 2.4-2.8:1 in one spot (INFERRED, minor).** The username
  "available" check icon. `moss` elsewhere is a fill with an ink outline, which is fine.
- **Screen-reader labels are in place but never heard on TalkBack** (Home pet, accessory tiles,
  Shop chips, the Completed-to-bottom switch, Calendar days). Not a priority.
