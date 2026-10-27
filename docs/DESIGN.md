# DESIGN.md — Nori's "Flat Storybook" design system

The visual rules every Nori screen follows. Use it when building a new screen, reviewing one,
or briefing a design tool (Stitch, Claude Design) so its output matches the app.

**Source of truth is the code**, not this file: tokens live in [`lib/theme/`](../lib/theme/)
and component shapes in [`lib/widgets/`](../lib/widgets/). This doc mirrors them in prose. If
you add or change a token, change it in `lib/theme/` and update the matching table here in the
same commit. Everything below was read from the code as of 2026-10-21.

These are the defaults the existing screens already share, not a lock on new ideas. If a screen
genuinely needs something new (a new color, a new component), add it as a token or shared
widget and record it here, rather than hard-coding a one-off.

---

## 1. The look in one paragraph

Warm linen paper, thick dark-brown ink outlines, flat pastel fills. Shapes look like cut-out
stickers on a storybook page: rounded, outlined, no blur and no gradient. Depth comes from
**ink borders and hard offset shadows**, never from soft elevation. Headings are rounded and
friendly (Fredoka), body text is plain and readable (Karla). Icons are Material Symbols, never
emoji.

Originally ported from the Claude Design canvas, variant **2a**.

---

## 2. Color tokens — `lib/theme/app_colors.dart`

Never write a raw `Color(0x…)` or `Colors.*` in a screen. Use `AppColors.*`.

| Token | Hex | Role |
|---|---|---|
| `ink` | `#3A2E22` | Every outline/border, headings, primary text, icons |
| `inkMuted` | `#7A6B4F` | Secondary text, `labelSm` default, list-row icons |
| `inkFaint` | `#6E634F` | Hints, timestamps, empty-state text, unselected nav |
| `linen` | `#F3ECDD` | **Scaffold background**, progress-bar track |
| `linenAlt` | `#F6F1E4` | Text-field fill, subtle alt surface |
| `white` | `#FFFFFF` | Default card / list-row / nav-bar surface |
| `moss` | `#8FA06B` | Primary: level progress, checkboxes, `FilledButton` fill |
| `mossLight` | `#DCE6CC` | Selected states (nav item, highlighted row), pet portrait card |
| `mossDark` | `#5B7A45` | Section-header icons, selected nav icon, text-button actions |
| `terracotta` | `#C9986A` | Secondary: **primary CTA (`TactileButton`) fill**, FAB, today's-goal progress |
| `terracottaDark` | `#B5652F` | Text/icon on terracotta-tinted containers |
| `blush` | `#EED9CF` | Avatar background, happiness icon bg |
| `blushPink` | `#F0D9E0` | Accent card tint |
| `mustard` | `#FBE38A` | XP pill, reward pill |
| `mustardLight` | `#F4E3A8` | Streak chip, "Preview only" banner, "Soon" badge |
| `mustardDark` | `#9A7C1F` | Streak/coin icon, text on mustard chips |
| `sky` | `#D9E7EA` | Pale background tint (e.g. water habit) |
| `skyBlue` | `#7AB8D9` | Ring/bar **fill** that must read clearly (hygiene vital) — not a background |
| `error` / `onError` | `#BA1A1A` / `#FFFFFF` | Errors (Material defaults, no 2a equivalent) |
| `errorContainer` / `onErrorContainer` | `#FFDAD6` / `#93000A` | Error banners |

### Color rules
- **Background is always `linen`.** Cards sit on it in `white` or a pastel tint.
- **Pastel tints** (`mossLight`, `blushPink`, `mustardLight`, `sky`, `blush`, `linenAlt`,
  `terracotta`) are for card/badge fills. Text on them stays `ink`.
- **The "dark" variant of a hue** (`mossDark`, `terracottaDark`, `mustardDark`) is for icons or
  text that sit on that hue's light variant.
- **Habit color choices** are limited to the keys in `ColorRegistry`
  (`lib/data/color_registry.dart`): terracotta, sky, mossLight, blushPink, mustardLight, blush,
  linenAlt. A new user-pickable color must be added there too, or it won't serialize.
- **Avatars for other people** (feed authors, leaderboard rows) get a deterministic fill from
  `NoriAvatar`'s palette: mossLight, blushPink, mustardLight, sky, terracotta.

### Material color scheme mapping (`app_theme.dart`)
primary = moss · secondary = terracotta · tertiary = mustardDark (container: mustard) ·
surface = linen · outline = ink · surfaceTint = transparent (no M3 elevation tint).

---

## 3. Typography — `lib/theme/app_text_styles.dart`

Two Google Fonts only. All styles default to `ink` except `labelSm` (`inkMuted`).

| Token | Font | Size / line height | Weight | Use |
|---|---|---|---|---|
| `display` | Fredoka | 40 / 48 | 700 | Big celebratory moments (level up, evolution) |
| `headlineLg` | Fredoka | 32 / 40 | 700 | Large page titles (wide layouts) |
| `headlineLgMobile` | Fredoka | 24 / 32 | 600 | Sub-screen titles in `NoriScreenHeader`, error/empty-state headings |
| `headlineMd` | Fredoka | 24 / 30 | 600 | Tab-level titles ("Habits", "Social"); at **18px** it's the section-header size |
| `bodyLg` | Karla | 18 / 28 | 400 | Lead paragraphs, error explanations |
| `bodyMd` | Karla | 16 / 24 | 400 | Default body, captions, text-field input |
| `labelLg` | Karla | 14 / 20 | 700, +0.2 tracking | Card titles, list-row labels, button labels |
| `labelSm` | Karla | 11 / 16 | 700, +0.3 tracking | Metadata, timestamps, field labels, chips, nav labels |

Rules:
- **Fredoka = headings only. Karla = everything else**, including buttons.
- Vary weight/color via `.copyWith(...)` on a token; don't construct a fresh `TextStyle`.
- Secondary information drops to `inkMuted` or `inkFaint`, not a lighter weight or opacity.

---

## 4. Spacing, radius, borders — `lib/theme/app_spacing.dart`

### Spacing (8px grid)
| Token | px | Typical use |
|---|---|---|
| `unit` | 8 | Gap between an icon and its label, tight inner gaps |
| `stackSm` | 12 | Between cards in a list, small card padding |
| `gutter` | 16 | List-row padding, text-field horizontal padding, top page padding |
| `containerPaddingMobile` | 20 | **Page side padding**, default `NoriCard` padding |
| `stackMd` | 24 | Header → first content; between related groups |
| `stackLg` | 48 | Between major page sections; bottom page padding |
| `containerPaddingDesktop` | 40 | Not used on the Android target |

### Radius
| Token | px | Use |
|---|---|---|
| `sm` | 16 | **Default**: cards, list rows, dialogs, banners, nav item highlight |
| `md` | 24 | Larger feature panels (Home, Calendar sheets, Customization) |
| `lg` | 32 | Hero stages (pet room, level-up / evolution cards) |
| `full` | 9999 | Pills: buttons, text fields, XP/streak/reward chips |

Rounded-square icon badges use `sm * 0.75` (12).

### Borders (`AppBorder`) — always `AppColors.ink`
| Token | px | Use |
|---|---|---|
| `thin` | 2 | Chips, pills, icon badges, list rows, small/secondary cards, progress tracks |
| `standard` | 2.5 | Default `NoriCard`, `TactileButton`, text fields, bottom nav top edge, circular icon buttons |
| `thick` | 3 | Avatars, focused text field, **selected** state of a choice tile, hero cards |

**Selection is shown by thickening the border (thin → thick) and/or a `mossLight` fill**, not by
changing the border color.

---

## 5. Elevation and depth

- **No soft shadows.** Depth = ink outline.
- The one "lifted" effect is the **hard offset shadow**: `BoxShadow(color: ink, offset: (0, 3))`,
  zero blur, on `TactileButton`. On press it disappears and the button moves down 3px (100ms,
  easeOut), like a sticker being pressed flat.
- **No gradients** for surfaces. (`pet_vital_ring.dart` uses a `SweepGradient` only as a hard-stop
  ring fill, plus a soft shadow. That's a known exception, not a pattern to copy.)
- M3 surface tint is disabled (`surfaceTint: transparent`), so cards never pick up a colored cast.

---

## 6. Iconography

- **Material Symbols (`Icons.*`) for every glyph. Never emoji**: not in labels, copy, empty
  states or sample data. Emoji render inconsistently across Android OEM fonts.
- Default icon color is `ink`. Section-header icons are `mossDark` at 20px. Unselected nav icons
  are `inkFaint`, selected are `mossDark`, at 22px.
- Icons that a user picks for a habit or bucket-list item must exist in the icon registries
  (`lib/data/icon_registry.dart`), or release builds tree-shake them away.
- Badged icons go in a `NoriIconBadge` (colored fill + thin ink border, circle or rounded square).

---

## 7. Components — `lib/widgets/`

Reach for these before building a local shape. If a screen needs a near-duplicate, extend the
shared widget instead.

| Widget | What it is | Key specs |
|---|---|---|
| `NoriCard` | The ink-bordered card shell used almost everywhere | white, radius 16, border 2.5, padding 20 (all overridable) |
| `TactileButton` | **Primary CTA** | terracotta pill, ink text `labelLg`, border 2.5, hard 3px shadow, 14px vertical padding, optional trailing icon, 50% fill when disabled |
| `FilledButton` (themed) | Secondary filled action, dialog confirm | moss fill, ink text |
| `TextButton` (`mossDark` fg) | Tertiary / "See all" / section trailing action | no border |
| `CircularIconButton` | Header action (Shop, Archived, Notifications…) | 88%-white circle, 2.5 ink border, 20px ink icon, 8px padding, tooltip required |
| `NoriIconBadge` | Colored icon tile | fixed size, thin border, circle or 12-radius square |
| `NoriAvatar` | User avatar | circle, 3px border, blush bg; illustrated default for you, initials + palette color for others; 40px default |
| `XpPill` | "★ 1,250 XP" | mustard pill, thin border, star icon, `labelLg` (compact: `labelSm`) |
| `StreakChip` | "12d" | mustardLight pill, flame icon in mustardDark |
| `RewardPill` | "+20 XP · coin 10" | mustard pill, coin icon `monetization_on` in mustardDark |
| `ProgressBarPill` | Chunky progress bar | 12px tall, fully rounded, linen track, thin ink border, moss fill (override color), optional threshold tick |
| `SectionHeader` | Section title row | optional mossDark 20px icon, Fredoka 18px title, trailing widget slot |
| `NoriScreenHeader` | Top-of-screen row | leading (back button or avatar), title, optional trailing (pills, icon buttons) |
| `NoriScrollScaffold` | Page body | scroll view, padding 20 / 16 top / 48 bottom, centered, max-width capped |
| `NoriListRow` | Tappable nav row | white, radius 16, thin border, icon (inkMuted) + `labelLg` + optional trailing + chevron |
| `NoriTextField` | Labeled input | `labelSm` label above, pill shape, linenAlt fill, 2.5 border → 3 when focused, ink prefix icon |
| `NoriBottomNav` | 5-tab bar | white, 2.5 ink top border; selected item = mossLight fill + thin border + radius 16 |
| `FutureFeatureBanner` / `SoonBadge` | "Preview only" / "Soon" markers | mustardLight, thin border, `rocket_launch` icon |
| `NoriInfoBanner` | Short explanatory note | sky fill, thin ink border, radius 16, 20px icon + `labelLg` text; optional close button via `onDismiss` (Add Habit's "Adaptive XP" / "Minimum Threshold" notes) |
| `OneTimeHint` | A `NoriInfoBanner` shown once per account until dismissed | state in `TipsStore` (`shared_preferences`, keyed by uid); takes no space when hidden; one per screen, max two lines of copy |
| `showNoriTextPrompt` | One-line text dialog | the dialog spec below, Cancel + Save; used for category names |
| `LoadErrorView` | First-load failure | `cloud_off_rounded` 56px, `headlineLgMobile` title, `bodyLg` muted message, non-expanded TactileButton "Try again" |

Dialogs: `AlertDialog` with white background, radius 16, thin ink border; `TextButton` cancel +
`FilledButton` confirm (see `delete_habit_dialog.dart`).

---

## 8. Layout patterns

- **Target: Android phones, ~412×915.** Design for that width first. Some screens have wide
  breakpoints (Home ≥800, Customization ≥700) but only the mobile layout ships.
- **Page skeleton:** `Scaffold` → `SafeArea` → `NoriScrollScaffold(maxWidth: …)` →
  header row → `stackMd` → content sections separated by `stackLg`.
- **Tab-level header** (Home, Habits, Social, Profile): title in `headlineMd` + trailing cluster of
  `CircularIconButton`s / `XpPill` / `StreakChip`. Social and Profile lead with the user's avatar.
- **Pushed sub-screen header:** `NoriScreenHeader.backButton` + title in `headlineLgMobile`.
- **Sections:** `SectionHeader` → `stackSm` → cards separated by `stackSm`.
- **Horizontal carousels** (e.g. circles, badges): fixed-height `ListView` of ~96px-wide
  bordered tiles, gap `stackSm`, last tile is a dashed-feel "add" tile (linenAlt, inkFaint
  border and icon).
- **Bottom nav** is persistent across the 5 tabs (Home, Habits, Calendar, Social, Profile);
  tabs live in an `IndexedStack` so scroll position survives tab switches.

---

## 9. States

- **Loading:** centered `CircularProgressIndicator` (themed moss) for a first load.
- **Error:** `LoadErrorView` with retry. Never spin forever.
- **Empty:** today mostly a centered `bodyMd` line in `inkFaint` (e.g. "No habits scheduled for
  today."). For a richer empty state, keep the same language: one Material icon (not
  illustration-by-emoji), a `headlineLgMobile` line, muted body, and one `TactileButton` CTA.
- **Disabled:** 50%-alpha fill on the button; text stays ink.
- **Feedback for not-yet-built actions:** a "Coming soon" `SnackBar`.
- **First-run help:** never a permanent line of helper text and never a spotlight overlay.
  (1) `IntroScreen`: three swipeable `NoriCard`s (icon badge, `headlineLgMobile` title, `bodyLg`
  muted body) shown once after naming the pet, with Skip, step dots and a `TactileButton`.
  (2) `OneTimeHint`: a dismissible `NoriInfoBanner` on Habits and Calendar, once. Both are
  replayable from Settings > Help > "Replay intro and tips". New hints are a `Tip` enum value plus
  one `OneTimeHint`; keep them to a single sentence and don't put one on Home.

---

## 10. Copy and voice

Short, warm, plain. Sentence case for buttons and titles ("Post proof", "Try again"). The pet is
"Nori". Errors explain what happened and what to do, without blame ("Couldn't reach the server
-- try again."). No emoji in copy.

---

## 11. Quick checklist for a new screen

- [ ] Background `linen`; surfaces `white` or a pastel token; no raw colors.
- [ ] Every bordered shape uses `ink` at `thin`/`standard`/`thick`.
- [ ] No blurred shadows, no gradients; only the `TactileButton` hard shadow.
- [ ] Fredoka for headings, Karla for everything else; only `AppTextStyles` tokens.
- [ ] Spacing from `AppSpacing`, radius from `AppRadius`.
- [ ] Icons are `Icons.*`; zero emoji anywhere, including sample data.
- [ ] One primary CTA per view, as a `TactileButton`.
- [ ] Shared widgets (`NoriCard`, `SectionHeader`, `NoriScreenHeader`, pills) reused, not rebuilt.
- [ ] Loading, error and empty states exist.
- [ ] Checked at ~412px mobile width.

## 12. Briefing an external design tool (Stitch etc.)

Paste §1, the §2 color table, §3, §4, §5 and §6 as the style section, and add: "phone viewport
412×915, persistent 5-tab bottom nav (Home, Habits, Calendar, Social, Profile), Material
Symbols icons only, never emoji". Anything it produces still gets mapped back onto the §7
widgets when implemented. Don't introduce new tokens just because a generated mock used them.
