# Nori — Roadmap

15-day sprints, organized by technical area (supersedes older generic sprint labels). Areas are
a development focus, not a permanent silo — the app still converges into one product.

| Phase | Focus | Status |
|---|---|---|
| Release 0 | Vision, requirements, mockups, stack decisions, backlog, pricing docs | Done |
| Frontend | Screens, nav, reusable components, pet visuals, habit/goal UI — built so mock data can later swap for real data cleanly. Don't redesign arbitrarily where approved mockups (the Stitch export) already exist | **In progress** — Flutter scaffold + first Stitch screen (Sign Up) |
| Backend | API/contracts, auth, habit/goal + completion/progression logic. Business rules live server-side, not scattered in UI | Not started |
| Data | Data model, DB schema, persistence, migrations; replace mock data | Not started |
| GCP | Deploy on Google Cloud Platform (not AWS) — hosting, env config, secrets, CI/CD, cost awareness | Not started |
| QA | Test the critical flow: create/manage habit or goal → complete → progress reflected correctly | Not started |
| Hardening / Demo Day | Bug fixes, remove leftover mock behavior, verify deploy, demo prep | Not started |

Status is inferred from repo state (2026-08-27), not an official tracker — keep it current as
sprints open/close. If this conflicts with the actual backlog, the backlog wins.
