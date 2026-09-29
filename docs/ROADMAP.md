# Nori — Roadmap

15-day sprints, organized by technical area (supersedes older generic sprint labels). Areas are
a development focus, not a permanent silo — the app still converges into one product.

| Phase | Focus | Status |
|---|---|---|
| Release 0 | Vision, requirements, mockups, stack decisions, backlog, pricing docs | Done |
| Frontend | Screens, nav, reusable components, pet visuals, habit UI — built so mock data can later swap for real data cleanly. Don't redesign arbitrarily where approved mockups (the Stitch export) already exist | **Near done** — all MVP-boundary screens/flows (see FEATURES.md) built against mock repositories and pre-release audited (2026-09-15/16: `docs/KNOWN_ISSUES.md`'s two pre-release audit passes); working tree has the fixes uncommitted |
| Backend | Firebase Auth wiring, Cloud Functions (business logic — habit claim/unclaim, XP/level-up, evolution trigger, shop purchases), and the feature-level Firestore read/write code in each repository. Currency-affecting rules (XP/coins mint/burn) live in Cloud Functions, not scattered in UI. See [BACKEND.md](BACKEND.md) | **Near done** — all 7 Cloud Functions deployed to `nori-pet` (2026-09-29); habit claim/unclaim independently verified end-to-end. Open: seed script, and Jimena's side hasn't had the same independent re-verification (code looks complete, not separately exercised) |
| Data | Firestore schema design (collections/fields for users, habits, habit logs, pet, inventory, ...) + security rules + indexes — a design pass that precedes most Backend-phase coding, per [BACKEND.md](BACKEND.md) | **Near done** — both verticals' `Firestore*Repository` implementations exist and rules are merged + deployed; see BACKEND.md's task checklist |
| GCP | Firebase/GCP project + console config, CI/CD, secrets/env config, deploying Cloud Functions + rules to the live project, cost awareness (Cloud Functions need the Blaze plan) | **Mostly done** — functions + rules deployed 2026-09-29, Blaze plan active. Open: CI/CD |
| QA | Test the critical flow: create/manage habit → complete → XP/pet progress reflected correctly | Not started |
| Hardening / Demo Day | Bug fixes, remove leftover mock behavior, verify deploy, demo prep | Not started |

Status is inferred from repo state (2026-09-16), not an official tracker — keep it current as
sprints open/close. If this conflicts with the actual backlog, the backlog wins.

For what's concretely in scope within each phase, see [FEATURES.md](FEATURES.md)'s MVP boundary
— e.g. "Backend" means the Must-build habit/XP/pet logic, not the vision-only social features.
