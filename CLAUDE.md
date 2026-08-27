# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Nori** — a habit/goal tracking app with gamification, built in Flutter. This is a two-person
university project (UFM, Desarrollo de Productos de Software): **valevasqc** (Valeria) and
**jimenaestradad** (Jimena).

Product scope, roadmap, and rationale live in `docs/`, not here — read them before making any
product/scope decision:

- `docs/OVERVIEW.md` — what Nori is, the core loop, MVP scope and what's explicitly out
- `docs/ROADMAP.md` — sprint structure and current phase
- `docs/OPEN_DECISIONS.md` — unresolved product decisions (e.g. XP formulas) — check here before inventing a rule

## Commands

- `flutter pub get` — install dependencies
- `flutter run` — run the app
- `flutter test` — run tests (none exist yet)
- `flutter analyze` — lint (`flutter_lints`, configured in `analysis_options.yaml`)

## Structure

Bare `flutter create` scaffold — `lib/main.dart` is the only app code so far, no `test/`
directory yet. `Frontend` (repo root, no file extension) is a standalone Stitch-exported static
HTML mockup — a design reference, not part of the Flutter build.

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
  `docs/OPEN_DECISIONS.md`).

## Working with valevasqc

When valevasqc is driving, spawn a Codex subagent (`mcp__codex__codex`) for purely mechanical
work whenever it would save Claude tokens — boilerplate, repetitive edits, formatting-level
refactors. All reasoning, design, and product/scope decisions stay with Claude; never delegate
judgment calls to Codex.
