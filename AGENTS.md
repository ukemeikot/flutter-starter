# Agent guide

Entry point for AI coding agents working in this repository. Claude Code also
loads the skills under `.claude/skills/`; other agents should read this file plus
the skill it points to.

## Skills

| Skill                                        | Use for                                                                       |
| -------------------------------------------- | ----------------------------------------------------------------------------- |
| [`flutter`](.claude/skills/flutter/SKILL.md) | Flutter/Dart, Riverpod, GetIt, GoRouter, Dio, dotenv, testing, SDK upgrades    |

The official Flutter and Dart agent skills
([flutter/agent-plugins](https://github.com/flutter/agent-plugins) and
[dart-lang/skills](https://github.com/dart-lang/skills)) are **installed rather
than vendored**, because they track the SDK and a frozen copy would go stale:

```sh
npx skills add flutter/agent-plugins --skill '*' --agent universal --yes
npx skills add dart-lang/skills --skill '*' --agent universal --yes
```

## Read this before your first build

`pubspec.yaml` declares `.env` as a bundled asset and `.gitignore` excludes it.
Flutter hard-fails on a declared-but-missing asset, so a fresh clone does not
build until you run:

```sh
cp .env.example .env
```

## Project shape

Feature-first clean architecture:

```
lib/features/<feature>/{data,domain,presentation}/
lib/core/{api_utils,config,locator,navigator}/
lib/app/            app shell and theme
```

- Barrel files (`core.dart`, `features.dart`, `presentation.dart`, …) are the
  public surface of each directory. Add new files to the barrel instead of
  importing deep paths from other layers.
- State: Riverpod. Service locator: GetIt, registered in
  `lib/core/locator/locator_service.dart`. Routing: GoRouter in
  `lib/core/navigator/app_router.dart`. HTTP: Dio via `lib/core/api_utils/`.
- Config precedence is `--dart-define` → dotenv → defaults, in
  `lib/core/config/app_config.dart`.

## Before you commit

Every one of these runs in CI and must pass:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
bash tool/supply_chain_scan.sh .
```

## Security constraints

Dart has no npm-style lifecycle scripts, but a lot still executes during
`flutter build`: Gradle files, the CocoaPods `Podfile` (Ruby, especially
`post_install`), `hook/build.dart` native-asset hooks, and desktop
`CMakeLists.txt`. Those are the implant targets in a Flutter project, and the
vendored scan covers them.

- Keep every dependency on pub.dev. No `git:` or `path:` dependencies and no
  `dependency_overrides` without review — the scan fails on all three.
- No process execution or network access in Gradle files, the Podfile, or build
  hooks.
- Never paste minified or generated content into a build file.
- Do not add a CI step that downloads and executes a script from the network.
- CodeQL has no Dart analyzer, so `flutter analyze --fatal-infos` and Dependabot's
  `pub` ecosystem carry that weight instead. Keep both green.
