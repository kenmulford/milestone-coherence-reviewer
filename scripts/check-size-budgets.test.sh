#!/usr/bin/env bash
# scripts/check-size-budgets.test.sh — minimal golden-case runner for
# scripts/check-size-budgets.sh (issue #49).
#
# This repo has no unit-test suite or tests/ directory
# (.project/conventions.md#Test patterns — "no unit-test suite or test
# directory"), so this stays a small, single-purpose runner colocated with
# the script it tests, not a general test framework. It mirrors the SHAPE of
# milestone-driver's tests/check-size-budgets.test.sh (a case table of
# fixture name -> expected exit code, run against fixture repo roots) at
# minimal weight: expected-substring checks instead of a separate golden
# `_expected/*.txt` file per case.
#
# Fixtures live under .github/workflows/fixtures/size-budgets/<case>/,
# mirroring the three governed files' real relative paths — colocated with
# the workflow that consumes them (this issue's own "Fixture location"
# design decision), not under a general test/fixture convention this repo
# does not have.
#
# Cases prove the acceptance criteria in issue #49:
#   happy             — every governed file at/under its ceiling -> exit 0.
#   over-description  — the agent description one word over 150 -> exit 1,
#                        naming the file and the ceiling it exceeded.
#   over-skill        — a SKILL.md one word over its ceiling -> exit 1, named.
#   missing-file      — a named governed file absent -> exit 1 (MISSING).
#   malformed         — agent frontmatter has no description: key -> exit 1
#                        (NODESC), not a silent skip/pass.
#   inline-description — the agent description given as an inline scalar
#                        (`description: <text>` on the same line as the key,
#                        not a block scalar) one word over 150 -> exit 1,
#                        naming the file and the ceiling it exceeded. Proves
#                        measure_description() measures the same-line
#                        remainder, not just an indented block-scalar body.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SCRIPT="$ROOT/scripts/check-size-budgets.sh"
FIX="$ROOT/.github/workflows/fixtures/size-budgets"

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

[ -x "$SCRIPT" ] || [ -f "$SCRIPT" ] || { echo "FATAL: missing $SCRIPT" >&2; exit 3; }

run_case "happy" 0 \
  "OK	agents/coherence-reviewer.md	150/150" \
  "OK	skills/review/SKILL.md	5090/5090" \
  "OK	skills/sweep/SKILL.md	4550/4550" \
  "SUMMARY	ok=3	failed=0"

run_case "over-description" 1 \
  "FAIL	agents/coherence-reviewer.md	151/150"

run_case "over-skill" 1 \
  "FAIL	skills/review/SKILL.md	5091/5090"

run_case "missing-file" 1 \
  "FAIL	skills/sweep/SKILL.md	MISSING/4550"

run_case "malformed" 1 \
  "FAIL	agents/coherence-reviewer.md	NODESC/150"

run_case "inline-description" 1 \
  "FAIL	agents/coherence-reviewer.md	151/150"

echo "check-size-budgets.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
