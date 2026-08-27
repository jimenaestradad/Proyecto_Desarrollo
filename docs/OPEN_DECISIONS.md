# Nori — Open Product Decisions

Product/business rules implementation will eventually need, but that aren't defined yet in
[OVERVIEW.md](OVERVIEW.md), the approved requirements, or the codebase. Don't invent these —
add a row when a task needs one and none exists, resolve it with the team, then move the
resolution into OVERVIEW.md (or code) and delete the row.

| # | Decision needed | Why it blocks implementation | Status |
|---|---|---|---|
| 1 | XP awarded per habit/goal completion (fixed? per-activity? user-set?) | Needed the moment "complete a habit" writes any progress value | Unresolved |
| 2 | Level thresholds / how XP maps to Nori growth stages | Needed to render Nori's progression visually | Unresolved |
| 3 | Number and definition of Nori growth stages/forms | Needed for frontend assets and data model | Unresolved |
| 4 | Streak bonuses or multipliers (if any) | Not part of MVP scope by default (see OVERVIEW.md) | Leaning "none for MVP," needs confirmation |
| 5 | Which achievements unlock which customization items, and how that mapping is authored (hardcoded list? admin config?) | Needed once any reward/customization is implemented | Unresolved |
| 6 | Auth provider/strategy | Needed for Backend sprint | Unresolved |
| 7 | Database choice and schema | Needed for Data sprint | Unresolved |
| 8 | Specific GCP services to use for hosting/deploy | Needed for GCP sprint | Unresolved |
| 9 | Whether any habit type requires evidence beyond manual completion in the MVP | Manual completion is always valid by default; evidence is an extension | Leaning "no," needs confirmation before building |
| 10 | End-user monetization model (if any) for the shipped product | Business docs discuss possible models (SaaS/subscription/freemium/etc.) but none is chosen for the MVP | Unresolved — don't implement billing/paywalls without this |

When you hit one of these while implementing: stop and ask, don't pick a default.
