# Nori — Product Overview

Gamified habit/goal tracker (Flutter), UFM Desarrollo de Productos de Software project. Two
devs: valevasqc (Valeria), jimenaestradad (Jimena).

## The idea

A Tamagotchi-style pet that grows from *real-life* progress instead of feeding/care actions.
The pet is a reward system, not the task itself.

```
create habit/goal → complete it → earn XP → Nori (pet) progresses → repeat
```

Every feature should serve this loop or its infrastructure. This is a habit/goal tracker with
a gamified reward layer — not a Tamagotchi simulator, not a to-do list.

- **Habit** — recurring, can be completed repeatedly ("read every day").
- **Goal** — usually completed once ("go to a concert").
- Users define their own; no fixed catalog.
- Manual completion is always valid — evidence/auto-verification (e.g. a Fitbit integration)
  is an extension, only built when a sprint explicitly scopes it in.
- Customization/rewards are tied to specific achievements (visible history of what the user
  did), not a shop or arbitrary cosmetics.

## MVP rule

When scoping any task: does it make `create → complete → XP → visible pet progress` work?
If not, it's probably not MVP. Prefer the smallest implementation that satisfies the actual
requirement over a more "complete" one nobody asked for.

## Out of scope (don't build without an explicit decision)

- **Social** — friends/followers, leaderboards, chat, public profiles, multiplayer, competition.
- **Economy** — marketplace, virtual currency, item shop, paid cosmetics, loot boxes, trading, rarity.
- **Automation/AI** — AI coaching, AI-generated habits, push notifications, complex analytics, health recommendations.
- **Literal Tamagotchi mechanics** — pet death, hunger/feeding, streak penalties.
- **Habit mechanics beyond the basics** — difficulty levels, categories, scheduling systems,
  reminder/notification logic — unless a sprint explicitly scopes one in.
- **Payments inside the app.**

Architecture unknowns (auth provider, DB, GCP services, XP/leveling formulas, monetization
model) aren't "banned" — they're just undecided. Track those in
[OPEN_DECISIONS.md](OPEN_DECISIONS.md) instead of guessing.

## Naming

Code and the business doc (`docs/Ejercicio1_IngenieriaDeSoftware` on `main`) call it **Nori**.
Some planning material calls the course project "Tamagotchi" — same product, use **Nori**.
