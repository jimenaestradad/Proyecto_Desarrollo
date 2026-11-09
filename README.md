# Nori

Nori is a habit tracker with a virtual pet. You create habits, check them off each day, and the pet grows with you: completing habits earns XP and coins, XP raises your level and evolves the pet, and coins buy food, care items and accessories. Skipping habits has a cost too, since the pet's needs decay when you neglect it.

It was built for people who start habit apps and drop them after a few days. The pet is there to give each check-off a visible result.

Made for the course Desarrollo de Productos de Software at Universidad Francisco Marroquín.

**Live app:** https://nori-pet.web.app

**Quote and pricing model:** [docs/business/COTIZACION.md](docs/business/COTIZACION.md) (in Spanish)

## What it does

- Habits of several types (yes/no, quantity, duration, multiple completions per day, and limit habits where the goal is to stay under a number), with daily, weekday, weekend or custom-day schedules, streaks, and a vacation mode that freezes streaks.
- XP, levels and coins. Rewards are calculated on the server, not in the app.
- A pet that evolves as you level up, can be fed and cared for, and can wear accessories bought in the shop.
- Calendar history, achievements, a bucket list, and in-app notifications.
- Email and Google sign-in, and account deletion.

The Social tab (friends, leaderboard, competitions) is an interface mock with fake data. There is no social backend yet. (This was decided as out of scope since the beginning of the project)

## Tech

| Part | Technology |
|---|---|
| App | Flutter (Dart 3.10), targeting Android; also runs in the browser |
| Auth | Firebase Authentication |
| Database | Cloud Firestore (project `nori-pet`) |
| Backend | Cloud Functions for Firebase, TypeScript on Node 22 |
| Hosting | Firebase Hosting |
| Container | Docker (nginx image that serves the web build) |
| CI | GitHub Actions |

Habit completion, XP, coins and shop purchases go through Cloud Functions so the rules live in one place. Firestore security rules block clients from writing those values directly.

## Running it locally

You need the Flutter SDK. The app talks to the live `nori-pet` Firebase project, so there is no local Firebase emulator setup. (The Docker image below only serves the web build; it connects to the same live project.)

```
flutter pub get
flutter run -d chrome
```

Nori is built for Android phones. The layout has mobile and desktop breakpoints, but we did not test the desktop layout because it is not the target platform; only the mobile layout was checked. To see what the Android app looks like, open Chrome DevTools and turn on the device toolbar with a phone preset.

## Docker

The `Dockerfile` packages the web build into an nginx image:

```
flutter build web --release
docker build -t nori .
docker run --rm -p 8080:80 nori
```

Then open http://localhost:8080. `Dockerfile.build` does the same but compiles the app inside Docker, so no local Flutter is needed.

## Tests

```
flutter test          # app tests
flutter analyze       # lint

cd functions
npm ci
npm test              # Cloud Functions tests
npm run lint
```

GitHub Actions runs all of the above on every push and pull request
(`.github/workflows/ci.yml`).

## Project layout

```
lib/          app code: screens, widgets, models, data repositories
functions/    Cloud Functions (TypeScript)
test/         app tests
assets/       images and pet animation frames
docs/         documentation, see below
Dockerfile, Dockerfile.build, nginx.conf    Docker setup for the web build
firestore.rules, firestore.indexes.json, firebase.json    Firebase configuration
```

## Documentation

The docs are grouped by topic in `docs/`:

- `docs/business/`: [COTIZACION.md](docs/business/COTIZACION.md), the quote and pricing model
- `docs/product/`: what Nori is and should do. [OVERVIEW.md](docs/product/OVERVIEW.md), [FEATURES.md](docs/product/FEATURES.md) (feature spec and MVP scope), [ROADMAP.md](docs/product/ROADMAP.md), [OPEN_DECISIONS.md](docs/product/OPEN_DECISIONS.md), [DESIGN.md](docs/product/DESIGN.md)
- `docs/technical/`: how it is built. [BACKEND.md](docs/technical/BACKEND.md) (Firestore schema, security rules, Cloud Functions), [DB_DIAGRAM.md](docs/technical/DB_DIAGRAM.md) (database diagram), [CODE_NOTES.md](docs/technical/CODE_NOTES.md)
- `docs/quality/`: testing and bugs. [KNOWN_ISSUES.md](docs/quality/KNOWN_ISSUES.md), [RESOLVED_LOG.md](docs/quality/RESOLVED_LOG.md)

## Authors

- Valeria Vasquez ([@valevasqc](https://github.com/valevasqc))
- Jimena Estrada ([@jimenaestradad](https://github.com/jimenaestradad))
