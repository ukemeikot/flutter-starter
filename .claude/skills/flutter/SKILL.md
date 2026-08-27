---
name: flutter
description:
  How to work with Flutter and Dart in this project, and how to reach the
  official Flutter/Dart agent skills. Use when writing Dart, building widgets,
  wiring Riverpod providers or GetIt registrations, adding routes with GoRouter,
  calling APIs through Dio, writing tests, or upgrading the Flutter SDK.
metadata:
  source: https://docs.flutter.dev/ai/agent-skills
---

# Flutter

This project targets **Flutter 3.47.1 / Dart 3.13** with clean architecture,
**Riverpod** for state, **GetIt** for the service locator, **GoRouter** for
routing, **Dio** for HTTP, and **flutter_dotenv** for configuration.

## Official skills are not vendored here

Flutter and Dart publish agent skills, maintained alongside the SDK:

- [flutter/agent-plugins](https://github.com/flutter/agent-plugins) — responsive
  layouts, declarative routing, JSON serialization
- [dart-lang/skills](https://github.com/dart-lang/skills) — generating unit
  tests, resolving package dependencies, fixing static analysis errors

They are **installed**, not copied into the repo, because they track the SDK — a
vendored copy would start giving stale advice after the next Flutter release.

```sh
npx skills add flutter/agent-plugins --skill '*' --agent universal --yes
npx skills add dart-lang/skills --skill '*' --agent universal --yes
```

Universal installs land in `.agents/skills/`. For the plugin route (which also
wires up the Dart and Flutter MCP server) follow
<https://docs.flutter.dev/ai/get-started>.

If they are not installed, use the canonical docs rather than recalling API
shapes from memory — Flutter's API surface moves between releases:
<https://docs.flutter.dev> and <https://api.flutter.dev>.

## The `.env` trap

`pubspec.yaml` declares `.env` as a bundled asset, and `.gitignore` excludes it.
Flutter **hard-fails** asset resolution when a declared asset is missing:

```
Error detected in pubspec.yaml:
No file or variants found for asset: .env.
```

So a fresh clone cannot build until you run:

```sh
cp .env.example .env
```

This is required, not optional. CI does it explicitly before any build step.

Config precedence in `AppConfig.fromEnvironment()` is `--dart-define` → dotenv →
hardcoded defaults. `AppConfig` guards on `dotenv.isInitialized`, so it also works
in tests where `loadAppEnv()` never ran.

## Architecture

Feature-first clean architecture. A feature owns its data, domain and
presentation layers:

```
lib/features/<feature>/
  data/           datasources
  domain/         models, repository interfaces
  presentation/   views, widgets, components, providers
lib/core/         api_utils, config, locator, navigator
lib/app/          app shell and theme
```

- Each directory has a barrel file (`core.dart`, `features.dart`, …). Add new
  files to the relevant barrel rather than importing deep paths elsewhere.
- Register singletons in `lib/core/locator/locator_service.dart`.
- Riverpod providers live in the feature's `presentation/providers/`.
- Routes go in `lib/core/navigator/app_router.dart`.

## Before you commit

```sh
cp .env.example .env                                   # if you have no .env yet
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
bash tool/supply_chain_scan.sh .
```

## Security constraints

Dart has no npm-style lifecycle scripts, but plenty still executes at build time:
Gradle files, the CocoaPods `Podfile` (Ruby, especially `post_install`),
`hook/build.dart` native-asset hooks, and desktop `CMakeLists.txt`. Those are the
implant targets here.

- Keep dependencies on pub.dev. No `git:` or `path:` deps, no
  `dependency_overrides` without review — the scan fails on all three.
- Never add process execution or network calls to a Gradle file, Podfile or
  build hook.
- Never paste minified or generated content into a build file.
- Do not add a CI step that downloads and executes a script from the network.
