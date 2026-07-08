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
#
# RECALL MODE (read-only; issue #69):
#   memory-mirror.sh --recall [--repo-root <dir>] -- <path> [<path> ...]
#   Reads (never writes) the SAME store the write mode would append to (resolve_target
#   is reused verbatim) and greps the prior write-up entries for grounding refs whose
#   `<path>:<line>` path component byte-matches one of the given touched paths. Does
#   exactly ONE read + ONE linear pass; emits a TAB-separated record stream on stdout,
#   SUMMARY last:
#     ENTRY-BEGIN<TAB>slug<TAB>ts · MATCH<TAB>path<TAB>line · <entry body lines verbatim>
#     · ENTRY-END<TAB>slug<TAB>ts · NONE<TAB>no prior write-ups found (iff 0 entries
#     matched) · SUMMARY<TAB>entries=<N><TAB>matches=<M>.
#   An absent, empty, or unreadable store is EXPECTED, not exceptional: NONE + zero
#   SUMMARY, exit 0. Recall has NO MIRROR-FAILED case and writes nothing to stderr on
#   that path (fail-soft / absence-means-skip). Exit codes: 0 on any well-formed recall;
#   2 on bad usage (no path list after `--`, or --recall combined with --slug/--file).
set -u
export LC_ALL=C

PROG="memory-mirror"
err()  { printf '%s\n' "$*" >&2; }
fail() { err "MIRROR-FAILED	$*"; exit 1; }   # best-effort failure: report, exit 1, no crash

usage() {
  err "usage: $PROG --slug <issue-or-pr-slug> [--repo-root <dir>] [--file <path>]"
  err "       $PROG --slug <slug> [--repo-root <dir>] < write-up.md"
  err "       $PROG --recall [--repo-root <dir>] -- <path> [<path> ...]"
  exit 2
}

# ----------------------------------------------------------------------------
# Parse args. Two modes share one flag loop:
#   write  (default): --slug <slug> [--repo-root <dir>] [--file <path>]  -> append entry
#   recall (--recall): [--repo-root <dir>] -- <path> [<path> ...]        -> read-only grep
# The trailing `-- <path>...` list mirrors resolve-config.sh's `docs` subcommand
# convention (resolve-config.sh:242-266).
# ----------------------------------------------------------------------------
SLUG=""; REPO_ROOT="$PWD"; CONTENT_FILE=""; RECALL=0; SAW_DDASH=0; PATHS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --slug)      [ "$#" -ge 2 ] || usage; SLUG="$2"; shift 2 ;;
    --repo-root) [ "$#" -ge 2 ] || usage; REPO_ROOT="$2"; shift 2 ;;
    --file)      [ "$#" -ge 2 ] || usage; CONTENT_FILE="$2"; shift 2 ;;
    --recall)    RECALL=1; shift ;;
    --)          SAW_DDASH=1; shift; PATHS=("$@"); break ;;
    -h|--help|help) usage ;;
    *) err "$PROG: unexpected arg: $1"; usage ;;
  esac
done
REPO_ROOT="${REPO_ROOT%/}"

# Mode validation. Recall is read-only: it takes a touched-path list after `--` and
# rejects the write-mode flags; write mode never accepts a bare `--`.
if [ "$RECALL" -eq 1 ]; then
  { [ -n "$SLUG" ] || [ -n "$CONTENT_FILE" ]; } && usage   # --recall + --slug/--file -> exit 2
  [ "${#PATHS[@]}" -ge 1 ] || usage                        # --recall needs >=1 path after --
else
  [ "$SAW_DDASH" -eq 1 ] && { err "$PROG: unexpected arg: --"; usage; }
  [ -n "$SLUG" ] || { err "$PROG: --slug is required"; usage; }
fi

# Write-mode preparation (slug sanitize + content read). Skipped entirely for
# recall, which reads no stdin and needs no slug.
if [ "$RECALL" -ne 1 ]; then
  # Sanitize the slug for filesystem use: keep word chars, dot and dash; collapse
  # everything else to '-'. Prevents a slug like "feature/x" from escaping the dir.
  SAFE_SLUG="$(printf '%s' "$SLUG" | tr -c 'A-Za-z0-9._-' '-')"
  [ -n "$SAFE_SLUG" ] || SAFE_SLUG="coherence"

  # Read the write-up content (from --file or stdin). Best-effort: an unreadable
  # file is a write failure, not a crash.
  if [ -n "$CONTENT_FILE" ]; then
    [ -f "$CONTENT_FILE" ] || fail "content file not found: $CONTENT_FILE"
    CONTENT="$(cat "$CONTENT_FILE"; printf 'X')"; CONTENT="${CONTENT%X}"
  else
    CONTENT="$(cat; printf 'X')"; CONTENT="${CONTENT%X}"
  fi
  # An empty write-up is still a valid mirror (e.g. a clean-fit headline produced
  # upstream) — we do not reject it; we record what we were given.
fi

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
# RECALL (read-only): ONE read + ONE linear pass over the resolved store, then a
# TAB-separated record stream on stdout (ENTRY-BEGIN / MATCH / body / ENTRY-END /
# NONE / SUMMARY), SUMMARY last — the buffered emit/flush shape of resolve-config.sh
# (:75-93). resolve_target above is reused verbatim, so recall reads the SAME store
# a write would append to. An absent, empty, or unreadable store is EXPECTED, not a
# fault: NONE + zero SUMMARY, exit 0. Recall has NO MIRROR-FAILED case (fail-soft /
# absence-means-skip, .project/design-philosophy.md#Error & failure philosophy).
# ----------------------------------------------------------------------------
if [ "$RECALL" -eq 1 ]; then
  RTAB=$'\t'
  # Header delimiter the write mode emits (l.158; the dash is em-dash U+2014). A
  # matching line starts a new entry and yields its slug + timestamp. The slug
  # charset matches the write mode's sanitizer; the timestamp is anything non-`)`.
  header_re='^## Coherence write-up — ([A-Za-z0-9._-]+) \(([^)]+)\)$'
  # Grounding ref inside an entry body: a maximal `<path>:<line>` token (path charset
  # A-Za-z0-9._/- with maximal munch, so backticks/spaces/parens delimit naturally and
  # `x/foo.sh:1` cannot match touched `foo.sh`). Only this citation form matches
  # (docs/write-up.md:56).
  ref_re='([A-Za-z0-9._/-]+):([0-9]+)'
  out=(); n_entries=0; n_matches=0
  cur_slug=""; cur_ts=""; in_entry=0
  ebody=(); ematch=(); ecount=0

  # Flush the current entry to the output buffer iff it matched >=1 touched path:
  # ENTRY-BEGIN, then its MATCH records (scan order), then its body verbatim, ENTRY-END.
  flush_entry() {
    if [ "$in_entry" -eq 1 ] && [ "$ecount" -gt 0 ]; then
      out+=("ENTRY-BEGIN${RTAB}${cur_slug}${RTAB}${cur_ts}")
      local r b
      for r in "${ematch[@]}"; do out+=("$r"); done
      for b in "${ebody[@]}";  do out+=("$b"); done
      out+=("ENTRY-END${RTAB}${cur_slug}${RTAB}${cur_ts}")
      n_entries=$((n_entries+1)); n_matches=$((n_matches+ecount))
    fi
    in_entry=0; ebody=(); ematch=(); ecount=0
  }

  # Single read + single pass. Absent/empty/unreadable -> skip the loop -> NONE.
  if [ -f "$MEM_FILE" ] && [ -r "$MEM_FILE" ] && [ -s "$MEM_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      line="${line//$'\r'/}"                       # strip ALL CR (parity, resolve-config.sh:346-355)
      if [[ $line =~ $header_re ]]; then
        flush_entry
        cur_slug="${BASH_REMATCH[1]}"; cur_ts="${BASH_REMATCH[2]}"
        in_entry=1; ebody=(); ematch=(); ecount=0
      elif [ "$in_entry" -eq 1 ]; then
        ebody+=("$line")                           # body verbatim; the header line is never a body line
        rest="$line"
        while [[ $rest =~ $ref_re ]]; do
          full="${BASH_REMATCH[0]}"; pc="${BASH_REMATCH[1]}"; lc="${BASH_REMATCH[2]}"
          for p in "${PATHS[@]}"; do
            if [ "$pc" = "$p" ]; then               # byte-identical, case-sensitive, no normalization
              ematch+=("MATCH${RTAB}${pc}${RTAB}${lc}"); ecount=$((ecount+1)); break
            fi
          done
          rest="${rest#*"$full"}"                   # advance past this maximal token; no dedupe
        done
      fi
      # lines before the first header belong to no entry and are ignored
    done < "$MEM_FILE"
    flush_entry
  fi

  # Emit buffered entry records, then NONE (iff 0 entries matched), then SUMMARY last.
  if [ "${#out[@]}" -gt 0 ]; then
    for l in "${out[@]}"; do printf '%s\n' "$l"; done
  fi
  [ "$n_entries" -eq 0 ] && printf 'NONE\tno prior write-ups found\n'
  printf 'SUMMARY\tentries=%s\tmatches=%s\n' "$n_entries" "$n_matches"
  exit 0
fi

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
