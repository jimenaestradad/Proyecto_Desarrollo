# Nori — Roadmap

15-day sprints, organized by technical area (supersedes older generic sprint labels). Areas are
a development focus, not a permanent silo — the app still converges into one product. Work is running
ahead of the sprint calendar, so a phase's status can be further along than the sprint that's
officially current.

| Phase | Focus | Status |
|---|---|---|
| Release 0 | Vision, requirements, mockups, stack decisions, backlog, pricing docs | Done |
| Frontend | Screens, nav, reusable components, pet visuals, habit UI — built so mock data can later swap for real data cleanly. Don't redesign arbitrarily where approved mockups (the Stitch export) already exist | **Near done** — all MVP-boundary screens/flows (see FEATURES.md) built against mock repositories and pre-release audited (2026-09-15/16: `docs/KNOWN_ISSUES.md`'s two pre-release audit passes); working tree has the fixes uncommitted |
| Backend | Firebase Auth wiring, Cloud Functions (business logic — habit claim/unclaim, XP/level-up, evolution trigger, shop purchases), and the feature-level Firestore read/write code in each repository. Currency-affecting rules (XP/coins mint/burn) live in Cloud Functions, not scattered in UI. See [BACKEND.md](BACKEND.md) | **Near done** — all 9 Cloud Functions live on `nori-pet` (latest deploy 2026-10-04); habit claim/unclaim and `onUserCreate` verified end to end. Open: adaptive XP (promised in the UI, never adjusts — KNOWN_ISSUES.md), committing the deployed code, and live checks of archive/delete, vacation mode and Jimena's flows |
| Data | Firestore schema design (collections/fields for users, habits, habit logs, pet, inventory, ...) + security rules + indexes — a design pass that precedes most Backend-phase coding, per [BACKEND.md](BACKEND.md) | **Done** — schema, rules (deployed 2026-10-04), every `Firestore*Repository`, and the seed script (run on the demo account 2026-10-05). No composite indexes needed: every query filters one field |
| GCP | Firebase/GCP project + console config, CI/CD, secrets/env config, deploying Cloud Functions + rules to the live project, cost awareness (Cloud Functions need the Blaze plan) | **Current sprint** (as of 2026-10-05). Already done ahead of it: Firebase project, Blaze plan, all 9 functions + rules deployed (latest 2026-10-04). Open: CI/CD, release APK build (KNOWN_ISSUES.md), cost check-in. Push notifications (FCM) would land here if built, but whether notifications exist at all is still open (OPEN_DECISIONS.md) |
| QA | Test the critical flow: create/manage habit → complete → XP/pet progress reflected correctly | Not started |
| Hardening / Demo Day | Bug fixes, remove leftover mock behavior, verify deploy, demo prep | Not started |

Status is inferred from repo state (last updated 2026-10-05), not an official tracker — keep it current as
sprints open/close. If this conflicts with the actual backlog, the backlog wins.

For what's concretely in scope within each phase, see [FEATURES.md](FEATURES.md)'s MVP boundary
— e.g. "Backend" means the Must-build habit/XP/pet logic, not the vision-only social features.
