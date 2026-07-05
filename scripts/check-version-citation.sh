#!/usr/bin/env bash
# scripts/check-version-citation.sh — the .project/ version-citation currency
# check (issue #48), gating drift between .project/*.md's version citations
# and .claude-plugin/plugin.json's actual `version` field (the exact drift
# issue #41 fixed upstream: .project/conventions.md:46 cited `0.1.1` while
# plugin.json's real version was `0.2.0`).
#
# What this checks, in plain terms:
#   .project/conventions.md#Versioning documents .claude-plugin/plugin.json's
#   `version` field as the single source of version truth, and other
#   .project/ docs sometimes cite that number in prose (e.g. the real line
#   "... .claude-plugin/plugin.json `version` 0.2.1 ..."). This script scans
#   every .project/*.md file for that citation shape and fails the moment a
#   cited number stops matching the real `version` in plugin.json — so the
#   authority file can never again silently drift from the manifest.
#
# Match heuristic (a heuristic by design, not a Markdown/prose parser):
#   A line only qualifies as a citation once it contains BOTH the literal
#   substring "plugin.json" (the citing context) AND the literal sequence
#   `version` (backtick-wrapped) followed, within 12 non-digit characters, by
#   a semver-shaped token (X.Y.Z). That shape is this repo's own established
#   citation style (conventions.md#Versioning, conventions.md:46) — a bare
#   mention of "plugin.json" or "version" alone, with no trailing number
#   (e.g. conventions.md:17's "`plugin.json` (version source of truth)", or
#   design-philosophy.md's "`version`** — the single source of version
#   truth"), does not match, by design: there is nothing to compare there,
#   so nothing is flagged.
#
# No-match handling: no .project/ directory, no *.md files in it, or no line
#   matching the shape above -> PASS. Absence of a citation is not an error
#   (there is nothing to compare); a mismatched citation IS the one failure
#   this script raises.
#
# Bash-3.2 compatible (no ${var,,}, no declare -A, no mapfile/readarray) —
# matches the discipline of scripts/resolve-config.sh and
# scripts/memory-mirror.sh, even though the ubuntu-latest CI runner this
# feeds ships bash 5.x in its `run:` steps.
#
# Dependency: jq, for reading plugin.json's `version` only — the suite's
#   already-approved JSON tool (.project/library-manifest.md#Approved
#   libraries (by purpose)). No new dependency introduced.
#
# Run it locally from the repo root:  ./scripts/check-version-citation.sh
# Exit 0 = clean (a matching citation, or nothing to compare).
# Exit 1 = a citation's version no longer matches plugin.json (fixture-
#   mismatch case).
# Exit 2 = a setup fault (missing plugin.json, or an unreadable `version`
#   field) — never treated as "clean".

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

PLUGIN_JSON=".claude-plugin/plugin.json"
DOCS_DIR=".project"

if [ ! -f "${PLUGIN_JSON}" ]; then
  echo "ERROR: ${PLUGIN_JSON} not found." >&2
  exit 2
fi

ACTUAL_VERSION="$(jq -r '.version // empty' "${PLUGIN_JSON}")"
if [ -z "${ACTUAL_VERSION}" ]; then
  echo "ERROR: ${PLUGIN_JSON} has no readable .version field." >&2
  exit 2
fi

if [ ! -d "${DOCS_DIR}" ]; then
  echo "PASS: no ${DOCS_DIR}/ directory — nothing to compare."
  exit 0
fi

# The citation shape: `version` followed, within a short non-digit run, by an
# X.Y.Z token. Matched only on lines that also mention plugin.json (the gate,
# applied via the `grep -n 'plugin\.json'` pass below).
CITATION_RE='`version`[^0-9]{0,12}[0-9]+\.[0-9]+\.[0-9]+'
SEMVER_TAIL_RE='[0-9]+\.[0-9]+\.[0-9]+$'

mismatch=0
checked_any=0

shopt -s nullglob
for f in "${DOCS_DIR}"/*.md; do
  [ -f "${f}" ] || continue

  # Lines citing plugin.json — the "citing context" gate.
  while IFS= read -r grepline; do
    [ -n "${grepline}" ] || continue
    lineno="${grepline%%:*}"
    content="${grepline#*:}"

    # Every non-overlapping `version`+trailing-number occurrence on the line.
    while IFS= read -r match; do
      [ -n "${match}" ] || continue
      cited="$(printf '%s\n' "${match}" | grep -Eo "${SEMVER_TAIL_RE}" || true)"
      [ -n "${cited}" ] || continue
      checked_any=1
      if [ "${cited}" != "${ACTUAL_VERSION}" ]; then
        echo "FAIL: ${f}:${lineno} cites plugin.json version ${cited}, but ${PLUGIN_JSON} version is ${ACTUAL_VERSION}." >&2
        mismatch=1
      fi
    done < <(printf '%s\n' "${content}" | grep -Eo "${CITATION_RE}" || true)
  done < <(grep -n 'plugin\.json' "${f}" || true)
done

if [ "${mismatch}" -eq 1 ]; then
  exit 1
fi

if [ "${checked_any}" -eq 0 ]; then
  echo "PASS: no plugin.json version citation found in ${DOCS_DIR}/*.md — nothing to compare."
else
  echo "PASS: all plugin.json version citations in ${DOCS_DIR}/*.md match ${PLUGIN_JSON} version ${ACTUAL_VERSION}."
fi
exit 0
