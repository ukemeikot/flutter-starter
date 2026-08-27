# flutter_starter

A Flutter starter template for building apps with clean arch.

## Stack

- Flutter 3.x
- Material 3
- Riverpod
- GetIt
- Dio
- GoRouter
- flutter_dotenv
- Mocktail
- Flutter lints

## Project Layout

```txt
.
├── .env
├── .env.example
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart
│   │   └── theme/
│   │       ├── app_palette.dart
│   │       └── app_theme.dart
│   ├── core/
│   │   ├── core.dart
│   │   ├── api_utils/
│   │   │   ├── api_utils.dart
│   │   │   ├── api_client.dart
│   │   │   ├── api_failure.dart
│   │   │   └── api_response_model.dart
│   │   ├── config/
│   │   │   ├── config.dart
│   │   │   ├── app_config.dart
│   │   │   └── env_loader.dart
│   │   ├── locator/
│   │   │   ├── locator.dart
│   │   │   └── locator_service.dart
│   │   └── navigator/
│   │       ├── navigator.dart
│   │       └── app_router.dart
│   ├── features/
│   │   ├── features.dart
│   │   └── example_tasks/
│   │       ├── example_tasks.dart
│   │       ├── data/
│   │       │   ├── data.dart
│   │       │   └── tasks_datasource.dart
│   │       ├── domain/
│   │       │   ├── domain.dart
│   │       │   ├── models/
│   │       │   │   ├── models.dart
│   │       │   │   └── task_model.dart
│   │       │   └── repo/
│   │       │       ├── repo.dart
│   │       │       └── tasks_repo.dart
│   │       └── presentation/
│   │           ├── presentation.dart
│   │           ├── components/
│   │           │   ├── components.dart
│   │           │   └── tasks_header.dart
│   │           ├── providers/
│   │           │   ├── providers.dart
│   │           │   └── tasks_provider.dart
│   │           ├── views/
│   │           │   ├── views.dart
│   │           │   └── tasks_view.dart
│   │           └── widgets/
│   │               ├── widgets.dart
│   │               └── task_tile.dart
├── test/
│   ├── app_test.dart
│   ├── helpers/
│   │   └── test_material_app.dart
│   ├── unit/
│   │   └── features/
│   └── widget/
│       └── features/
├── analysis_options.yaml
├── pubspec.yaml
└── README.md
```

## Architecture

Each feature owns its UI, business rules, repository contract, and data implementation.

```txt
presentation -> domain <- data
```

- `app`: app setup and theme.
- `core`: shared infrastructure.
- `features`: vertical feature modules.
- `domain`: models and repo contracts.
- `data`: datasources and API access.
- `presentation`: views, components, widgets, providers, and UI state.

The `example_tasks` feature shows the full flow:

```txt
TasksView
  -> tasksProvider
  -> TasksRepo
  -> TasksDatasource
  -> ApiBaseService
```

## Core Rules

Keep `core` small. Add shared code only when more than one feature needs it.

Good `core` candidates:

- App config
- Dependency injection
- API base service
- API failure handling
- Navigation
- Storage, connectivity, logging, providers, enums, or app services when used

## Adding A Feature

1. Create `features/<feature_name>`.
2. Put datasources and API access in `data`.
3. Put models and repo contracts in `domain`.
4. Put screens, components, widgets, providers, and UI state in `presentation`.
5. Keep feature models in `domain/models`.
6. Register long-lived implementations in `core/locator/locator_service.dart`.

Avoid global `utils`, `constants`, or `services` folders for one-off code. Keep code inside the feature until it is truly shared.

## Barrel Exports

Every folder that exposes reusable Dart files should have a barrel file.

Use **exactly these two root-barrel imports** everywhere you need shared core plus feature exports (same order and URIs as `lib/features/example_tasks/data/tasks_datasource.dart`):

```dart
import 'package:flutter_starter/core/core.dart';
import 'package:flutter_starter/features/features.dart';
```

If you rename the app in `pubspec.yaml`, update the `package:` name in both lines to match. Narrower barrels are only for real import cycles or boundary clarity—this pair stays the default.

Export chain:

```txt
leaf files -> layer barrel -> feature barrel -> features.dart
shared core files -> core.dart
```

Rules:

- Add new exports whenever you add a reusable file.
- Prefer `core/core.dart` for shared app infrastructure.
- Prefer `features/features.dart` when code needs feature-level exports.
- Inside a feature, use the narrowest useful barrel when `features.dart` (or the feature barrel) would create an import cycle or blur boundaries—often a **layer** barrel (`data/data.dart`, `domain/domain.dart`, `presentation/presentation.dart`) or a **subfolder** barrel (`domain/repo/repo.dart`, `presentation/views/views.dart`, etc.).
- Avoid importing leaf `.dart` files directly unless every barrel option causes a real problem.

**Narrower than `features.dart`:** import that feature’s barrel file first, e.g. `lib/features/example_tasks/example_tasks.dart` (same pattern for any feature: `lib/features/<name>/<name>.dart`). That file already re-exports `data`, `domain`, and `presentation`. Reach for layer or subfolder barrels only when you need a smaller slice to break a cycle or keep dependencies obvious.

## Configuration

Env files live at the **project root** (`.env`, `.env.example`) and are listed under `flutter.assets` so [`flutter_dotenv`](https://pub.dev/packages/flutter_dotenv) can load them before dependency injection runs.

The repo ships a **safe default** `.env` so `flutter analyze` and first runs work without extra setup. Treat `.env.example` as a template you can copy if you ever delete `.env`.

1. Edit `.env` for your machine.
2. Do not commit real secrets; prefer CI variables or `--dart-define` for production values.

```txt
API_BASE_URL=https://api.example.com
USE_MOCK_DATA=false
```

`USE_MOCK_DATA` accepts `true` / `false` (also `1` / `0`, `yes` / `no`).

### Overrides for CI or release builds

`--dart-define` still works and **wins over `.env`** when you need non-file config:

```sh
flutter run --dart-define=API_BASE_URL=https://api.example.com --dart-define=USE_MOCK_DATA=false
```

Defaults when neither `.env` nor defines set a value:

```txt
API_BASE_URL=https://example.com/api
USE_MOCK_DATA=true
```

## Getting started

```sh
git clone https://github.com/ukemeikot/flutter-starter.git
cd flutter-starter
```

The repo root **is** the Flutter project: `pubspec.yaml` and `lib/` sit at the top
level. There is no nested `flutter_starter/` directory.

### 1. Create your `.env` (required)

`pubspec.yaml` declares `.env` as a bundled asset and `.gitignore` excludes it.
Flutter hard-fails asset resolution when a declared asset is missing, so **the
project will not build until this file exists**:

```sh
cp .env.example .env
```

```powershell
Copy-Item .env.example .env   # Windows PowerShell
```

Skipping this produces:

```txt
Error detected in pubspec.yaml:
No file or variants found for asset: .env.
```

### 2. Run

```sh
flutter pub get
flutter run
```

## Common Commands

```sh
dart format lib test
dart analyze
flutter test
```

## Testing

Tests should mirror the app structure:

- `test/helpers`: reusable test setup
- `test/unit`: datasources, repo contracts, and services
- `test/widget`: views and reusable widgets

Mock dependencies at the layer boundary being tested.

## AI agent skills

Agent guidance lives in [`AGENTS.md`](AGENTS.md) and `.claude/skills/`. Claude Code
picks the skills up automatically; other agents should start from `AGENTS.md`.

| Skill                                        | Source                                                                                                                       | Covers                                                          |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------- |
| [`flutter`](.claude/skills/flutter/SKILL.md) | [docs.flutter.dev/ai/agent-skills](https://docs.flutter.dev/ai/agent-skills)                                                  | Project conventions, the `.env` trap, architecture, build gates |

The **official Flutter and Dart agent skills** are installed rather than vendored,
since they track the SDK and a frozen copy would go stale after the next release:

```sh
npx skills add flutter/agent-plugins --skill '*' --agent universal --yes
npx skills add dart-lang/skills --skill '*' --agent universal --yes
```

- [flutter/agent-plugins](https://github.com/flutter/agent-plugins) — responsive
  layouts, declarative routing, JSON serialization
- [dart-lang/skills](https://github.com/dart-lang/skills) — generating unit tests,
  resolving dependencies, fixing analysis errors

The plugin route at <https://docs.flutter.dev/ai/get-started> also wires up the
Dart and Flutter MCP server.

**Thanks to the Flutter and Dart teams for publishing these openly.**

## Security

### Supply-chain scanning

A self-contained scanner lives at
[`tool/supply_chain_scan.sh`](tool/supply_chain_scan.sh) and runs in CI on every
push and pull request:

```sh
bash tool/supply_chain_scan.sh .
```

Dart has no npm-style lifecycle scripts, but plenty still executes during
`flutter build` — Gradle files, the CocoaPods `Podfile` (Ruby, especially
`post_install`), `hook/build.dart` native-asset hooks, and desktop
`CMakeLists.txt`. Those are the implant targets in a Flutter project, and they are
rarely read line by line during review.

The scan checks that dependencies resolve to pub.dev (no `git:`/`path:` sources,
no unreviewed `dependency_overrides`), that build files are not oversized or
whitespace-padded, that they contain no process execution or network access, that
Dart sources carry no obfuscation or dynamic execution, and that no CI step
downloads and runs remote code.

It is deliberately vendored rather than downloaded at scan time — fetching a
scanner over the network would reintroduce exactly the class of dependency it
exists to catch.

### Other checks

| Check                        | Runs on                   |
| ---------------------------- | ------------------------- |
| Gitleaks                     | push, PR, weekly schedule |
| `flutter analyze --fatal-infos` | every CI run           |
| Dependabot (`pub`, gradle, actions) | weekly             |

CodeQL is intentionally absent — it has no Dart analyzer. Static analysis comes
from `flutter analyze --fatal-infos`, and dependency advisories from Dependabot's
`pub` ecosystem.
