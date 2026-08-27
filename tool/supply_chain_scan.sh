#!/usr/bin/env bash
#
# Supply-chain implant scanner for Flutter/Dart projects.
#
# Dart has no npm-style lifecycle scripts, so the build-time execution points are
# different from a JS project. What actually runs during `flutter build`:
#
#   * Gradle files (android/**/*.gradle, *.gradle.kts) -- arbitrary Kotlin/Groovy
#   * CocoaPods Podfile -- arbitrary Ruby, especially post_install hooks
#   * hook/build.dart and hook/link.dart -- Dart native-asset build hooks
#   * CMakeLists.txt on desktop targets
#
# Plus the dependency graph itself: pubspec git/path deps and dependency_overrides
# can pull code from outside pub.dev entirely.
#
# Runs entirely from the repo. It deliberately downloads nothing -- a scanner
# fetched at scan time is itself a supply-chain dependency.

set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

FAILED=0
fail() {
  echo "FAIL [$1] $2" >&2
  FAILED=1
}

prune=(-path ./build -o -path ./.git -o -path ./.dart_tool -o -path ./ios/Pods)

echo "[1/6] Checking dependency sources in pubspec.yaml..."
# A starter should resolve entirely from pub.dev. git:, path: and custom hosted:
# sources bypass pub.dev's (limited) scrutiny and point at arbitrary code.
if [ -f pubspec.yaml ]; then
  if grep -qE '^\s*dependency_overrides:' pubspec.yaml; then
    fail "dependency-overrides" "pubspec.yaml declares dependency_overrides -- review each entry by hand"
  fi
  if grep -qE '^\s+(git|path):\s*$|^\s+git:\s+\S' pubspec.yaml; then
    fail "off-registry-dep" "pubspec.yaml references a git: or path: dependency"
  fi
fi

echo "[2/6] Checking pubspec.lock resolves to pub.dev..."
if [ -f pubspec.lock ]; then
  # Every hosted entry should carry the canonical pub.dev URL.
  bad_urls=$(grep -E '^\s+url:' pubspec.lock | grep -v 'https://pub.dev' || true)
  if [ -n "$bad_urls" ]; then
    fail "off-registry-lock" "pubspec.lock contains non-pub.dev hosted URLs:"
    printf '%s\n' "$bad_urls" >&2
  fi
  if grep -qE '^\s+source:\s+git' pubspec.lock; then
    fail "off-registry-lock" "pubspec.lock contains a git source"
  fi
fi

echo "[3/6] Checking build-time hooks for oversized or padded content..."
# Same trick as the JS-side implants: a legitimate head, a long run of padding,
# then the payload sitting off the right edge of the editor.
mapfile -t BUILD_FILES < <(
  find . \( "${prune[@]}" \) -prune -o -type f \( \
    -name '*.gradle' -o -name '*.gradle.kts' -o -name 'Podfile' \
    -o -name 'CMakeLists.txt' -o -path './hook/*.dart' \
  \) -print
)
for f in "${BUILD_FILES[@]}"; do
  [ -e "$f" ] || continue
  size=$(wc -c < "$f")
  if [ "$size" -gt 20480 ]; then
    fail "file-size" "$f is ${size} bytes -- unusually large for a build file"
  fi
  awk -v f="$f" '
    length > 500 {
      printf "FAIL [long-line] %s:%d (%d chars)\n", f, NR, length > "/dev/stderr"
      bad = 1
    }
    END { exit bad ? 1 : 0 }
  ' "$f" || FAILED=1
done

echo "[4/6] Checking for process execution and network access in build hooks..."
# Nothing in a Gradle/Podfile/build-hook for a starter needs to shell out or
# open a socket.
EXEC_PATTERNS=(
  'Runtime\.getRuntime\(\)\.exec'
  'ProcessBuilder'
  '\bexec\s*\('
  'Process\.(run|start|runSync)'
  '\bcurl\b|\bwget\b'
  'URL\(|HttpURLConnection|OkHttpClient'
  'system\s*\('
  'eval\s*\('
)
for f in "${BUILD_FILES[@]}"; do
  [ -e "$f" ] || continue
  for pattern in "${EXEC_PATTERNS[@]}"; do
    if grep -qE "$pattern" "$f" 2>/dev/null; then
      fail "build-hook-capability" "$f matches: $pattern"
    fi
  done
done

echo "[5/6] Checking Dart sources for obfuscation and dynamic execution..."
mapfile -t DART_FILES < <(
  find . \( "${prune[@]}" \) -prune -o -type f -name '*.dart' -print
)
DART_PATTERNS=(
  '_0x[0-9a-f]{4,6}'
  'dart:mirrors'
  'Process\.(run|start|runSync)'
  'Isolate\.spawnUri'
  '[A-Za-z0-9+/]{200,}={0,2}'
)
for f in "${DART_FILES[@]}"; do
  [ -e "$f" ] || continue
  for pattern in "${DART_PATTERNS[@]}"; do
    if grep -qE "$pattern" "$f" 2>/dev/null; then
      fail "dart-suspicious" "$f matches: $pattern"
    fi
  done
  awk -v f="$f" '
    length > 500 {
      printf "FAIL [long-line] %s:%d (%d chars)\n", f, NR, length > "/dev/stderr"
      bad = 1
    }
    END { exit bad ? 1 : 0 }
  ' "$f" || FAILED=1
done

echo "[6/6] Checking CI workflows do not execute remote code..."
# A workflow that curls a script and pipes it to a shell inherits the trust of
# whatever host it fetched from.
if [ -d .github/workflows ]; then
  for f in .github/workflows/*.y*ml; do
    [ -e "$f" ] || continue
    if grep -qE '(curl|wget)[^|]*\|[[:space:]]*(ba)?sh' "$f"; then
      fail "ci-remote-exec" "$f pipes a downloaded script into a shell"
    fi
    if grep -qE '(curl|wget).*(-o|--output|-O)\s' "$f"; then
      fail "ci-remote-fetch" "$f downloads a file at run time -- vendor it instead"
    fi
  done
fi

if [ "$FAILED" -ne 0 ]; then
  echo "" >&2
  echo "Scan FAILED. Do not run pub get or build until resolved." >&2
  exit 1
fi

echo "OK: no supply-chain implant signatures found."
