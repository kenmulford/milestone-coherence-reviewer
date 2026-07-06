#!/usr/bin/env bash
# scripts/check-size-budgets.sh — the CI size-budget check (issue #49).
#
# Guards two things from silently regrowing after issue #43's trim:
#   1. agents/coherence-reviewer.md's frontmatter `description:` block scalar
#      (the field alone, NOT the whole file) — a FIXED ceiling of 150 words.
#      This number is absolute, per the issue, and is never re-derived here
#      (unlike the two ceilings below).
#   2. skills/review/SKILL.md and skills/sweep/SKILL.md — the WHOLE file via
#      `wc -w` — each ceiling is that file's word count measured against the
#      live post-#43 tree at the time this check was authored, plus ~5%
#      headroom, rounded to a clean number (mirrors milestone-driver's
#      check-size-budgets.sh ratchet discipline, issue #295):
#        - CEILINGS ONLY GO DOWN, NEVER UP on their own; growth requires a
#          recorded decision on the issue that grows the file, which raises
#          the ceiling in that SAME change.
#        - A file that shrinks should have its ceiling lowered to the new
#          actual + headroom in the same change that shrinks it.
#
# Scope is exactly the three files below — no glob over agents/** or
# skills/**/SKILL.md (.project/conventions.md#File & folder layout: `agents/`
# is "the read-only review engine", `skills/` holds "the `review` entry
# point"). A missing governed file is a loud FAIL, never a silently-reduced
# scope.
#
# Usage:   check-size-budgets.sh [REPO_ROOT]
#   REPO_ROOT   path to a checked-out repo root (default: CWD). Lets the same
#   checking logic run against fixtures under
#   .github/workflows/fixtures/size-budgets/<case>/ for local verification,
#   with no separate test framework (.project/conventions.md#Test patterns —
#   this repo has no unit-test suite or test directory).
#
# Output (stdout), one line per governed file plus a trailing summary,
# TAB-separated (mirrors milestone-driver's check-size-budgets.sh stream):
#   OK    <path>  <actual>/<ceiling>
#   FAIL  <path>  <actual-or-MISSING-or-NODESC>/<ceiling>
# NODESC marks the one setup fault distinct from a missing file: the file
# exists but its frontmatter has no top-level `description:` key at all.
#   SUMMARY ok=<N> failed=<M>
# Exit 0 when every governed file is present, well-formed, and at/under its
# ceiling; exit 1 when any file is missing, malformed, or over. bash-3.2-safe
# (no ${var,,}, no `declare -A`, no `mapfile`) — matches the discipline of
# scripts/check-version-citation.sh even though the ubuntu-latest CI runner
# this feeds ships bash 5.x in its `run:` steps.
#
# No pwsh twin: like scripts/check-version-citation.sh (issue #48), this
# script is consumed only by the CI job on ubuntu-latest, not by any
# cross-platform host-selection script — so no check-size-budgets.ps1.
set -u
export LC_ALL=C

ROOT="${1:-$PWD}"
ROOT="${ROOT%/}"

# Parallel arrays (bash-3.2-safe — no associative arrays). Index i in FILES
# lines up with KINDS[i] and CEILINGS[i]. See the header for the ratchet
# discipline governing the two "wordcount" ceilings; the "description"
# ceiling is a fixed, absolute 150 per the issue and is not derived.
FILES=(
  "agents/coherence-reviewer.md"
  "skills/review/SKILL.md"
  "skills/sweep/SKILL.md"
)
KINDS=(
  "description"
  "wordcount"
  "wordcount"
)
CEILINGS=(
  150
  5100
  4550
)

# Length-parity guard: FILES/KINDS/CEILINGS are hand-edited parallel arrays
# with no structural link between them — a dropped/added entry in one and
# not the others must fail loud, not desync the loop (which would
# misattribute ceilings/kinds under `set -u`, or die mid-loop on an unbound
# index).
if [ "${#FILES[@]}" -ne "${#KINDS[@]}" ] || [ "${#FILES[@]}" -ne "${#CEILINGS[@]}" ]; then
  printf 'ERROR check-size-budgets: FILES(%s)/KINDS(%s)/CEILINGS(%s) length mismatch — fix the table\n' \
    "${#FILES[@]}" "${#KINDS[@]}" "${#CEILINGS[@]}" >&2
  exit 1
fi

# measure_description FILE -> prints the word count of the frontmatter
# `description:` value to stdout, or "NODESC" if the file has no top-level
# `description:` key. Handles both YAML scalar styles: a block scalar
# (`description: |` or `>`, body on the indented lines that follow) and an
# inline scalar (`description: some text` on the same line) — the same-line
# remainder is captured too, after stripping a bare block-indicator (`|`,
# `>`, with optional chomp/indent modifiers) so the indicator itself is never
# counted as a word. The block runs from the `description:` line to the next
# un-indented (column-0) frontmatter key — this generalizes past the
# specific `model:` key that happens to follow it in this file today.
measure_description() {
  file="$1"
  if ! grep -q '^description:' "${file}"; then
    printf 'NODESC'
    return
  fi
  awk '
    /^description:/ {
      flag=1
      rest=$0
      sub(/^description:[ \t]*/, "", rest)
      if (rest !~ /^[|>][+-]?[0-9]?[+-]?$/) print rest
      next
    }
    flag && /^[A-Za-z_][A-Za-z0-9_-]*:/ { flag=0 }
    flag
  ' "${file}" | wc -w | tr -d ' '
}

ok=0
failed=0
i=0
while [ "$i" -lt "${#FILES[@]}" ]; do
  f="${FILES[$i]}"
  kind="${KINDS[$i]}"
  ceiling="${CEILINGS[$i]}"
  path="$ROOT/$f"

  if [ ! -f "$path" ]; then
    printf 'FAIL\t%s\tMISSING/%s\n' "$f" "$ceiling"
    failed=$((failed + 1))
    i=$((i + 1))
    continue
  fi

  if [ "$kind" = "description" ]; then
    actual="$(measure_description "$path")"
  else
    actual="$(wc -w < "$path" | tr -d ' ')"
  fi

  if [ "$actual" = "NODESC" ]; then
    printf 'FAIL\t%s\tNODESC/%s\n' "$f" "$ceiling"
    failed=$((failed + 1))
  elif [ "$actual" -gt "$ceiling" ]; then
    printf 'FAIL\t%s\t%s/%s\n' "$f" "$actual" "$ceiling"
    failed=$((failed + 1))
  else
    printf 'OK\t%s\t%s/%s\n' "$f" "$actual" "$ceiling"
    ok=$((ok + 1))
  fi
  i=$((i + 1))
done

printf 'SUMMARY\tok=%s\tfailed=%s\n' "$ok" "$failed"
[ "$failed" -eq 0 ]
