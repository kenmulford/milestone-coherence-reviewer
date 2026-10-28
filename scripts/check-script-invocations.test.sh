#!/usr/bin/env bash
# scripts/check-script-invocations.test.sh — golden-case runner for
# scripts/check-script-invocations.sh. Same shape as check-size-budgets.test.sh.
#
# Fixtures live under .github/workflows/fixtures/script-invocations/<case>/,
# each a minimal tree of the scanned files (skills/, agents/, docs/).
#   clean            — prefixed invocations, path citations, a driver-script
#                      cite, a script path passed as an argument, and the
#                      exempt docs/validation-note.md -> exit 0.
#   bare-agent       — `scripts/x.sh docs …` in an agent -> exit 1.
#   codeblock-skill  — a bare invocation on an indented code-block line.
#   dotslash-skill   — `./scripts/x.sh` with no arguments.
#   escaped-pipe-doc — the `<sh\|ps1>` table-cell placeholder form.
#   brace-flag-doc   — the `{sh,ps1}` placeholder followed by a flag.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SCRIPT="$ROOT/scripts/check-script-invocations.sh"
FIX="$ROOT/.github/workflows/fixtures/script-invocations"

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

run_case "clean" 0 \
  "SUMMARY	files=3	hits=0"

run_case "bare-agent" 1 \
  "FAIL	agents/demo.md:1" \
  "SUMMARY	files=1	hits=1"

run_case "codeblock-skill" 1 \
  "FAIL	skills/demo/SKILL.md:2"

run_case "dotslash-skill" 1 \
  "FAIL	skills/demo/SKILL.md:1"

run_case "escaped-pipe-doc" 1 \
  "FAIL	docs/contract.md:1"

run_case "brace-flag-doc" 1 \
  "FAIL	docs/contract.md:1"

echo "check-script-invocations.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
