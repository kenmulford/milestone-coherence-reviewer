#!/usr/bin/env bash
# scripts/check-codex-manifest.sh — the CI check for the Codex plugin manifest.
#
# Checks .codex-plugin/plugin.json against .claude-plugin/plugin.json (the
# version source of truth, .project/conventions.md#Versioning):
#   parse     .codex-plugin/plugin.json exists and is valid JSON.
#   match     `name`, `version`, `description` equal the Claude manifest's.
#   required  `name`, `version`, `description`, `skills`, and the four
#             `interface` fields are set.
#   path      `skills` / `hooks` start with `./`; every string value starting
#             with `./` stays inside the plugin root (no `..` segment) and exists.
#
# Usage:   check-codex-manifest.sh [REPO_ROOT]   (default: CWD)
# Output (stdout), TAB-separated, one line per check plus a summary:
#   OK    <check>  <subject>
#   FAIL  <check>  <subject>  <detail>
#   SUMMARY ok=<N> failed=<M>
# Exit 0 when every check passes, 1 otherwise. Dependency: jq.
#
# No pwsh twin: CI-only, like scripts/check-size-budgets.sh.
set -u
export LC_ALL=C

ROOT="${1:-$PWD}"
ROOT="${ROOT%/}"
CODEX=".codex-plugin/plugin.json"
CLAUDE=".claude-plugin/plugin.json"

ok=0
failed=0
pass_line() { printf 'OK\t%s\t%s\n' "$1" "$2"; ok=$((ok + 1)); }
fail_line() { printf 'FAIL\t%s\t%s\t%s\n' "$1" "$2" "$3"; failed=$((failed + 1)); }
finish() { printf 'SUMMARY\tok=%s\tfailed=%s\n' "$ok" "$failed"; [ "$failed" -eq 0 ]; exit $?; }

if [ ! -f "$ROOT/$CODEX" ]; then
  fail_line parse "$CODEX" MISSING
  finish
fi
if ! jq -e . "$ROOT/$CODEX" >/dev/null 2>&1; then
  fail_line parse "$CODEX" INVALID-JSON
  finish
fi
pass_line parse "$CODEX"

if ! jq -e . "$ROOT/$CLAUDE" >/dev/null 2>&1; then
  fail_line parse "$CLAUDE" MISSING-OR-INVALID
  finish
fi

for k in name version description; do
  want="$(jq -r --arg k "$k" '.[$k] // ""' "$ROOT/$CLAUDE")"
  got="$(jq -r --arg k "$k" '.[$k] // ""' "$ROOT/$CODEX")"
  if [ "$got" = "$want" ]; then
    pass_line match "$k"
  elif [ "$k" = description ]; then
    fail_line match "$k" differs
  else
    fail_line match "$k" "$got != $want"
  fi
done

REQUIRED="name version description skills interface.displayName interface.shortDescription interface.developerName interface.category"
missing=""
for k in $REQUIRED; do
  if ! jq -e --arg p "$k" 'getpath($p | split(".")) | strings | length > 0' "$ROOT/$CODEX" >/dev/null 2>&1; then
    missing="${missing:+$missing }$k"
  fi
done
if [ -z "$missing" ]; then
  pass_line required "$REQUIRED"
else
  fail_line required "$missing" MISSING
fi

# Component paths must carry the `./` prefix, or the path loop below never sees them.
for k in skills hooks; do
  v="$(jq -r --arg k "$k" '.[$k] // empty | strings' "$ROOT/$CODEX" | tr -d '\r')"
  case "$v" in
    ''|./*) ;;
    *) fail_line path "$v" NOT-DOT-SLASH ;;
  esac
done

while IFS= read -r p; do
  [ -n "$p" ] || continue
  case "/$p/" in
    */../*) fail_line path "$p" ESCAPES; continue ;;
  esac
  if [ -e "$ROOT/${p#./}" ]; then
    pass_line path "$p"
  else
    fail_line path "$p" MISSING
  fi
done < <(jq -r '.. | strings | select(startswith("./"))' "$ROOT/$CODEX" | tr -d '\r')

finish
