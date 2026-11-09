# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Nori** — a habit tracker combined with a virtual-pet game, built in Flutter. This is a
two-person university project (UFM, Desarrollo de Productos de Software): **valevasqc**
(Valeria) and **jimenaestradad** (Jimena).

Product scope, roadmap, and rationale live in `docs/`, not here — read them before making any
product/scope decision. The feature set is still being defined incrementally, so check these
before assuming anything is decided:

- `docs/product/OVERVIEW.md` — what Nori is, the core loop, platform target
- `docs/product/FEATURES.md` — the actual feature spec (habits, XP, streaks, pets, economy, social) and MVP boundary — source of truth for scope, not OVERVIEW.md
- `docs/product/ROADMAP.md` — sprint structure and current phase
- `docs/product/OPEN_DECISIONS.md` — unresolved product decisions (e.g. XP formulas) — check here before inventing a rule
- `docs/product/DESIGN.md` — the "Flat Storybook" visual system (tokens, components, layout, checklist) — follow it for any UI work; tokens themselves live in `lib/theme/`

## Commands

There's no macOS desktop support configured and no Android emulator set up locally, so local
testing is via `flutter run -d chrome`, with Chrome DevTools' device toolbar (Inspect → toggle
device toolbar) set to a Pixel or iPhone preset — not the raw desktop viewport. The UI has
mobile/desktop breakpoints (`isWide` checks around 700-800px), and only the mobile layout matches
the actual Android target.

## Working conventions

- **Priority when things conflict:** explicit instruction from whoever's driving > approved
  requirements/backlog > existing intentional code behavior > `docs/` > assumptions (ask
  before assuming).
- Inspect existing code and conventions before changing them. Don't migrate frameworks, DB,
  cloud provider, or auth approach without a concrete reason — there's no universally "best"
  stack, just what fits this project.
- Don't delete or rewrite existing intentional behavior just because it isn't mentioned in
  `docs/` — flag the gap instead.
- When proposing non-trivial work, label claims **CONFIRMED** (backed by code/docs/requirements),
  **INFERRED** (implied but not stated), or **UNRESOLVED** (needs a decision — see
  `docs/product/OPEN_DECISIONS.md`).
- **Icons, never emoji**, anywhere in the UI — use `Icons.*` (Material Symbols) for every glyph
  (habit type badges, care actions, nav, empty states, etc.). Target platform is Android only for
  now (this ships as an APK, not iOS — see `docs/product/OVERVIEW.md`), and emoji glyphs render
  inconsistently across Android OEM keyboards/fonts in a way a bundled icon font doesn't.

## Working with valevasqc

When valevasqc is driving, spawn a Codex subagent (`mcp__codex__codex`) for purely mechanical
work whenever it would save Claude tokens — boilerplate, repetitive edits, formatting-level
refactors. All reasoning, design, and product/scope decisions stay with Claude; never delegate
judgment calls to Codex.

Don't run exhaustive Playwright verification passes (multiple viewports, every interaction
screenshotted, etc.) for small/incremental UI changes — it wastes tokens. Reserve Playwright for
big changes where something may plausibly have gone wrong (a new screen, a structural layout
change, a bug fix you can't otherwise confirm); for small tweaks, a quick `flutter analyze` plus
reasoning about the change is enough.
