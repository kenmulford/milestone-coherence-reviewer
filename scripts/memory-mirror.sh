#!/usr/bin/env bash
# milestone-coherence-reviewer — memory-mirror helper (issue #5).
#
# Writes the coherence write-up to the user's memory store as the SUPPLEMENTAL
# audit-trail copy. The inline summary is the PRIMARY deliverable (docs/write-up.md);
# this is one of its three supplemental mirrors, so it is BEST-EFFORT: a write
# failure is reported on stderr and exits nonzero, but it NEVER crashes the caller
# and NEVER suppresses the inline summary (BRIEF.md l.68, l.89, l.96; the
# mirror-unavailable rule in docs/write-up.md "Graceful degradation").
#
# Target resolution — DETECT-OR-FALLBACK (RESOLVED, issue #5 Design):
#   Best-effort, CONSERVATIVE detection of the user's ALREADY-CONFIGURED memory
#   convention, in this order. It writes ONLY into a location the user opted into;
#   it never guesses-and-writes into a location the user has not configured:
#     1. Obsidian vault via $NPM_CLAUDE_VAULT_ROOT — only when the env var is set
#        AND a `Claude Memory/MEMORY.md` already exists under it (the existing file
#        is the opt-in signal). Append to that MEMORY.md.
#     2. A `.obsidian/` directory at the repo root — append to a coherence memory
#        file under the vault's `Claude Memory/`.
#     3. Claude Code project memory via an `autoMemoryDirectory` setting in a
#        `.claude/settings*.json` — write under that directory.
#   FALLBACK when NONE is detected: a git-invisible `.md` under
#   `.milestone-config/.runtime/` (default `coherence-memory.md`). That dir is
#   ALREADY git-invisible via the nested `.milestone-config/.gitignore` (`.runtime/`
#   entry) — no new ignore rule is added. A top-level `.milestone-config/*.md`
#   would NOT be ignored, so the fallback MUST live under `.runtime/`.
#
# USAGE:
#   memory-mirror.sh --slug <issue-or-pr-slug> [--repo-root <dir>] [--file <path>]
#   memory-mirror.sh --slug <slug> [--repo-root <dir>] < write-up.md   # content on stdin
#
#   --slug      issue/PR slug, used in the entry header (e.g. "issue-27", "pr-14").
#               The fallback filename is the fixed `coherence-memory.md`; the slug
#               appears only in the per-entry header, not the filename. Required.
#   --repo-root the repo root (default: $PWD). Used to find `.obsidian/`,
#               `.claude/settings*.json`, and the `.milestone-config/.runtime/`
#               fallback.
#   --file      read the write-up content from this file. If omitted, read stdin.
#
# OUTPUT: on success, prints the absolute path it wrote to, on stdout, and a
#   `MIRROR <tier> <path>` record to stderr for the caller's log. On failure,
#   prints `MIRROR-FAILED <reason>` to stderr and exits nonzero — best-effort.
#
# Exit codes: 0 = wrote the mirror. 2 = bad usage. 1 = best-effort write failed
#   (reported, never a crash; the caller continues with the inline summary).
#
# Dependency: jq, only to read the optional `autoMemoryDirectory` setting — the
#   suite's already-permitted JSON tool (same as resolve-config.sh). Detection
#   leg 3 is simply skipped if jq is absent; legs 1, 2 and the fallback need no jq.
set -u
export LC_ALL=C

PROG="memory-mirror"
err()  { printf '%s\n' "$*" >&2; }
fail() { err "MIRROR-FAILED	$*"; exit 1; }   # best-effort failure: report, exit 1, no crash

usage() {
  err "usage: $PROG --slug <issue-or-pr-slug> [--repo-root <dir>] [--file <path>]"
  err "       $PROG --slug <slug> [--repo-root <dir>] < write-up.md"
  exit 2
}

# ----------------------------------------------------------------------------
# Parse args
# ----------------------------------------------------------------------------
SLUG=""; REPO_ROOT="$PWD"; CONTENT_FILE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --slug)      [ "$#" -ge 2 ] || usage; SLUG="$2"; shift 2 ;;
    --repo-root) [ "$#" -ge 2 ] || usage; REPO_ROOT="$2"; shift 2 ;;
    --file)      [ "$#" -ge 2 ] || usage; CONTENT_FILE="$2"; shift 2 ;;
    -h|--help|help) usage ;;
    *) err "$PROG: unexpected arg: $1"; usage ;;
  esac
done
[ -n "$SLUG" ] || { err "$PROG: --slug is required"; usage; }
REPO_ROOT="${REPO_ROOT%/}"

# Sanitize the slug for filesystem use: keep word chars, dot and dash; collapse
# everything else to '-'. Prevents a slug like "feature/x" from escaping the dir.
SAFE_SLUG="$(printf '%s' "$SLUG" | tr -c 'A-Za-z0-9._-' '-')"
[ -n "$SAFE_SLUG" ] || SAFE_SLUG="coherence"

# ----------------------------------------------------------------------------
# Read the write-up content (from --file or stdin). Best-effort: an unreadable
# file is a write failure, not a crash.
# ----------------------------------------------------------------------------
if [ -n "$CONTENT_FILE" ]; then
  [ -f "$CONTENT_FILE" ] || fail "content file not found: $CONTENT_FILE"
  CONTENT="$(cat "$CONTENT_FILE"; printf 'X')"; CONTENT="${CONTENT%X}"
else
  CONTENT="$(cat; printf 'X')"; CONTENT="${CONTENT%X}"
fi
# An empty write-up is still a valid mirror (e.g. a clean-fit headline produced
# upstream) — we do not reject it; we record what we were given.

# ----------------------------------------------------------------------------
# Detect-or-fallback target resolution. Echoes "TIER<TAB>PATH"; the file is the
# memory file to APPEND to (a durable, growing audit trail, not an overwrite).
# Conservative: each leg requires an ALREADY-CONFIGURED opt-in signal.
# ----------------------------------------------------------------------------
resolve_target() {
  local f

  # Leg 1 — Obsidian vault via $NPM_CLAUDE_VAULT_ROOT. Opt-in signal: the env var
  # is set AND a `Claude Memory/MEMORY.md` already exists under it.
  if [ -n "${NPM_CLAUDE_VAULT_ROOT:-}" ]; then
    f="${NPM_CLAUDE_VAULT_ROOT%/}/Claude Memory/MEMORY.md"
    if [ -f "$f" ]; then printf 'vault-env\t%s' "$f"; return 0; fi
  fi

  # Leg 2 — a `.obsidian/` directory at the repo root is the opt-in for an
  # in-repo vault. Write a dedicated coherence memory file under its
  # `Claude Memory/` (created if absent — the user opted into the vault, so a
  # subdir of it is in-bounds).
  if [ -d "$REPO_ROOT/.obsidian" ]; then
    printf 'vault-repo\t%s' "$REPO_ROOT/Claude Memory/coherence-memory.md"; return 0
  fi

  # Leg 3 — Claude Code project memory via `autoMemoryDirectory` in any
  # `.claude/settings*.json`. Needs jq; skipped (not failed) when jq is absent.
  if [ -d "$REPO_ROOT/.claude" ] && command -v jq >/dev/null 2>&1; then
    local s dir
    for s in "$REPO_ROOT"/.claude/settings*.json; do
      [ -f "$s" ] || continue
      dir="$(jq -r '.autoMemoryDirectory // empty' "$s" 2>/dev/null)"
      [ -n "$dir" ] || continue
      # Absolutize a relative setting against the repo root.
      case "$dir" in /*) : ;; *) dir="$REPO_ROOT/$dir" ;; esac
      printf 'claude-mem\t%s' "${dir%/}/coherence-memory.md"; return 0
    done
  fi

  # Fallback — git-invisible `.md` under `.milestone-config/.runtime/`. That dir
  # is already ignored via the nested .milestone-config/.gitignore (`.runtime/`);
  # no new ignore rule. A top-level `.milestone-config/*.md` would NOT be ignored,
  # so the fallback lives UNDER .runtime/.
  printf 'fallback\t%s' "$REPO_ROOT/.milestone-config/.runtime/coherence-memory.md"
}

TARGET="$(resolve_target)"
TIER="${TARGET%%	*}"
MEM_FILE="${TARGET#*	}"

# ----------------------------------------------------------------------------
# Append the write-up as a dated, slug-headed entry. mkdir -p the parent so the
# fallback `.runtime/` (and any vault subdir) is created on demand. All filesystem
# ops are guarded: any failure is best-effort -> report and exit 1, never crash.
# ----------------------------------------------------------------------------
MEM_DIR="$(dirname "$MEM_FILE")"
mkdir -p "$MEM_DIR" 2>/dev/null || fail "could not create memory dir: $MEM_DIR"

# Header marks each entry so the growing audit trail stays scannable. Date is
# best-effort; an absent `date` does not abort the mirror.
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"

{
  printf '\n## Coherence write-up — %s (%s)\n\n' "$SAFE_SLUG" "$STAMP"
  printf '%s\n' "$CONTENT"
} >> "$MEM_FILE" 2>/dev/null || fail "could not write memory file: $MEM_FILE"

# Success: path on stdout (for the caller to surface), record on stderr (log).
err "MIRROR	$TIER	$MEM_FILE"
printf '%s\n' "$MEM_FILE"
exit 0
