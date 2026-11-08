# Nori

Habit tracker combined with a virtual-pet game, built with Flutter. Two-person university
project for UFM's Desarrollo de Productos de Software course.

## Documentation

- [Overview](docs/OVERVIEW.md) — what Nori is, the core loop, platform target
- [Features](docs/FEATURES.md) — feature spec (habits, XP, streaks, pets, economy, social) and MVP boundary
- [Roadmap](docs/ROADMAP.md) — sprint structure and current phase
- [Backend](docs/BACKEND.md) — Firebase/Firestore/Cloud Functions plan
- [Database Diagram](docs/DB_DIAGRAM.md) — entity-relationship view of the Firestore collections
- [Open Decisions](docs/OPEN_DECISIONS.md) — unresolved product decisions
- [Design](docs/DESIGN.md) — the "Flat Storybook" visual system (tokens, components, layout)
- [Known Issues](docs/KNOWN_ISSUES.md) — open bugs and gaps
- [Resolved Log](docs/RESOLVED_LOG.md) — history of fixed issues and decisions
- [Code Notes](docs/CODE_NOTES.md) — code-level gotchas

## Getting started

Requires the Flutter SDK (Dart ^3.10.7).

```
flutter pub get
flutter run
```

- `flutter test` — run tests
- `flutter analyze` — lint (`flutter_lints`, see `analysis_options.yaml`)

Target platform is Android. There is no macOS desktop support configured and no local Android
emulator set up, so local testing runs via `flutter run -d chrome`, with Chrome DevTools' device
toolbar set to a mobile preset rather than the default desktop viewport.

## Structure

- `lib/` — application code: screens, widgets, models, data repositories
- `functions/` — Cloud Functions (TypeScript)
- `assets/` — images and pet animation frames
- `test/` — unit tests
- `docs/` — product documentation, see above
- `firebase.json`, `firestore.rules`, `firestore.indexes.json` — Firebase project config

## Backend

Firebase project `nori-pet`: Auth, Firestore, Cloud Functions. See [docs/BACKEND.md](docs/BACKEND.md).

## Authors

- Valeria Vásquez ([@valevasqc](https://github.com/valevasqc))
- Jimena Estrada ([@jimenaestradad](https://github.com/jimenaestradad))
