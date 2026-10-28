#!/usr/bin/env bash
# scripts/check-codex-manifest.test.sh — golden-case runner for
# scripts/check-codex-manifest.sh. Same shape as check-size-budgets.test.sh:
# a case table of fixture name -> expected exit + expected output substrings.
#
# Fixtures live under .github/workflows/fixtures/codex-manifest/<case>/, each a
# minimal plugin root (.claude-plugin/plugin.json, .codex-plugin/plugin.json,
# skills/).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SCRIPT="$ROOT/scripts/check-codex-manifest.sh"
FIX="$ROOT/.github/workflows/fixtures/codex-manifest"

pass=0
fail=0

# run_case NAME WANT_EXIT WANT_SUBSTRING...
run_case() {
  name="$1"; want_exit="$2"; shift 2
  fixture="$FIX/$name"
  if [ ! -d "$fixture" ]; then
    echo "FAIL $name: missing fixture dir $fixture" >&2
    fail=$((fail + 1))
    return
  fi
  got="$(bash "$SCRIPT" "$fixture" 2>&1)"
  rc=$?
  ok=1
  if [ "$rc" -ne "$want_exit" ]; then
    ok=0
    echo "FAIL $name: exit=$rc (want $want_exit)" >&2
  fi
  for want in "$@"; do
    case "$got" in
      *"$want"*) ;;
      *)
        ok=0
        echo "FAIL $name: output missing expected substring: $want" >&2
        ;;
    esac
  done
  if [ "$ok" -eq 1 ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "--- $name output ---" >&2
    printf '%s\n' "$got" >&2
  fi
}

[ -f "$SCRIPT" ] || { echo "FATAL: missing $SCRIPT" >&2; exit 3; }

run_case "happy" 0 \
  "OK	parse	.codex-plugin/plugin.json" \
  "OK	match	name" \
  "OK	match	version" \
  "OK	match	description" \
  "OK	required	name version description skills interface.displayName interface.shortDescription interface.developerName interface.category" \
  "OK	path	./skills/" \
  "SUMMARY	ok=6	failed=0"

run_case "version-mismatch" 1 \
  "FAIL	match	version	1.1.0 != 1.2.0"

run_case "name-mismatch" 1 \
  "FAIL	match	name	other-plugin != demo-plugin"

run_case "description-mismatch" 1 \
  "FAIL	match	description"

run_case "missing-path" 1 \
  "FAIL	path	./skills/	MISSING"

run_case "escaping-path" 1 \
  "FAIL	path	./skills/../../x/	ESCAPES"

run_case "missing-required" 1 \
  "FAIL	required	interface.shortDescription interface.developerName interface.category"

run_case "both-missing-version" 1 \
  "OK	match	version" \
  "FAIL	required	version	MISSING"

run_case "unprefixed-skills" 1 \
  "FAIL	path	skills/	NOT-DOT-SLASH"

run_case "malformed" 1 \
  "FAIL	parse	.codex-plugin/plugin.json"

run_case "missing-manifest" 1 \
  "FAIL	parse	.codex-plugin/plugin.json	MISSING"

echo "check-codex-manifest.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
