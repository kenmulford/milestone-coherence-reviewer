#!/usr/bin/env bash
# milestone-coherence-reviewer — config + project-docs resolution layer (issue #2).
#
# The "gather once" half of the suite's resolve-once / "analyze once, then
# distribute" pattern (BRIEF.md l.33-40, l.114). The orchestrator calls this a
# SINGLE time per run to resolve the suite's shared mechanics and the cited
# `.project/` doc sections, then hands the result to downstream subagents as
# slices — no subagent re-reads the same file/section. This script does the read;
# the orchestrator owns the caching. (Resolve-once is enforced by the caller
# invoking once and reusing stdout, exactly like the driver's resolve-once block.)
#
# Two concerns, one cohesive layer (subcommand dispatch mirrors render-daemon.sh):
#
#   resolve-config.sh keys [REPO_ROOT]
#       Resolve the shared keys from `.milestone-config/driver.json` FIRST, root
#       `milestone-driver.json` as FALLBACK (identical order to the feeder and to
#       ci-preflight-steps.sh:64-68). Keys read, in place, never duplicated into a
#       coherence-owned file: sourceGlobs · uiSurfaceGlobs · integrationBranch ·
#       nonNegotiables · domainSkills (BRIEF.md l.90).
#
#   resolve-config.sh docs [REPO_ROOT] [PROJECT_DOCS_ROOT] -- DOC#ANCHOR [DOC#ANCHOR ...]
#       Resolve cited `.project/` sections via the INSTALLED milestone-driver's
#       `read-doc-section` primitive (located, not reimplemented). Each arg is
#       `<doc>#<anchor>` where <doc> is a filename under the docs root (default
#       `.project/`) and <anchor> is the heading text WITHOUT leading #s. Prints
#       only that section. The driver primitive is fail-CLOSED (missing anchor/
#       file -> nonzero, empty stdout); this layer CATCHES that and translates it
#       into the issue's absence-means-skip contract (BRIEF.md l.89). A `[TBD]`
#       section body is likewise skipped, not returned.
#
# OUTPUT — a deterministic, line-oriented, TAB-separated record stream (the suite
# convention; see ci-preflight-steps.sh). The caller parses once, distributes
# slices. Records:
#   KEY     <name>\t<value>                a resolved shared-key value. An array
#                                          key emits ONE record per element (so
#                                          arrays and scalars parse uniformly).
#   SKIP    <kind>\t<name>\t<reason>       an expected absence: a key absent from
#                                          a present config (kind=key), or a
#                                          section absent/[TBD]/unreadable
#                                          (kind=section). Absence-means-skip,
#                                          never a failure.
#   SIGNAL  <name>                         a degraded-mode flag for the caller to
#                                          fall back to bounded repo greps:
#                                            no-config        — neither config file
#                                            no-doc-grounding — no docs root / no
#                                                               primitive / nothing
#                                                               resolved
#   SECTION-BEGIN  <doc>\t<anchor>         start of a resolved doc section …
#   <section body lines, verbatim>         … its content (may span many lines) …
#   SECTION-END    <doc>\t<anchor>         … end marker (lets the caller slice it).
#   ERROR   <kind>\t<file>\t<detail>       a present-but-INVALID config file
#                                          (kind=malformed-config). Surfaced, not
#                                          silent; never fabricates values; never
#                                          crashes the run. Also written to stderr.
#   SUMMARY keys=<N>\tsections=<M>\tskipped=<K>\tsignals=<S>\terrors=<E>   (last).
#
# Exit codes: 0 = ran (incl. clean degradation). 2 = bad usage. 3 = a malformed
#   config was surfaced (the run continues; the nonzero lets the caller notice
#   the ERROR record without parsing). A malformed config is the ONE config
#   condition surfaced as an error rather than skipped — a present-but-invalid
#   file is a real fault, distinct from an absent file's expected degradation
#   (BRIEF.md l.96; §Constraints l.129).
#
# Dependency: jq, for the config reads only — the suite's blessed JSON tool
#   ("the cross-platform nonNegotiable already permits it", render-daemon.sh:57;
#   the exact pattern is ci-preflight-steps.sh:66-67). No NEW dependency. The
#   doc-section read uses the driver's dependency-free primitive, unchanged.
set -u
export LC_ALL=C

PROG="resolve-config"
err() { printf '%s\n' "$*" >&2; }

# ----------------------------------------------------------------------------
# Buffered emission so SUMMARY can come last while records stream in order
# (mirrors ci-preflight-steps.sh's emit/flush).
# ----------------------------------------------------------------------------
n_keys=0; n_sections=0; n_skipped=0; n_signals=0; n_errors=0
out_lines=()
emit() { out_lines+=("$1"); }
flush() {
  # Print every buffered line VERBATIM, including blank lines that occur inside a
  # SECTION body (real Markdown sections contain blank lines; dropping them
  # collapsed the body and broke .sh/.ps1 parity — finding 4). The (( ... )) guard
  # handles the empty-buffer case under `set -u` instead of a per-line non-empty
  # test, so blank body lines round-trip.
  local l
  if [ "${#out_lines[@]}" -gt 0 ]; then
    for l in "${out_lines[@]}"; do printf '%s\n' "$l"; done
  fi
  printf 'SUMMARY\tkeys=%s\tsections=%s\tskipped=%s\tsignals=%s\terrors=%s\n' \
    "$n_keys" "$n_sections" "$n_skipped" "$n_signals" "$n_errors"
}
rec_key()    { emit "KEY	$1	$2"; n_keys=$((n_keys+1)); }
rec_skip()   { emit "SKIP	$1	$2	$3"; n_skipped=$((n_skipped+1)); }
rec_signal() { emit "SIGNAL	$1"; n_signals=$((n_signals+1)); }
rec_error()  { emit "ERROR	$1	$2	$3"; n_errors=$((n_errors+1)); err "$PROG: $1: $2: $3"; }

# encode_value: make a single value EXACTLY one record, never corrupting the
# TAB-separated stream, regardless of internal newlines OR tabs. Canonical escape
# order (identical in the .ps1 twin): backslash -> "\\" FIRST, then newline ->
# "\n", then TAB -> "\t". Backslash must be escaped first so the backslashes we
# introduce are not double-escaped. A literal TAB in a value would otherwise add
# spurious columns to a KEY<TAB>name<TAB>value record (re-review finding 1); a
# trailing/embedded newline would otherwise split or be dropped (re-review
# finding 2). Extends ci-preflight-steps.sh:80-81's encode_cmd, which escaped
# only backslash+newline, with the TAB case the record stream requires.
#
# Implemented with pure bash parameter expansion (no awk/sed) so it is the exact
# byte-for-byte analogue of the .ps1's .Replace() chain — and so a trailing
# newline is preserved (awk's RS/ORS record model dropped the final empty record;
# $(...) strips trailing newlines — both diverged from the .ps1, re-review
# finding 2). bash holds any byte except NUL, which jq-decoded JSON string values
# never contain, so every value round-trips.
encode_value() {
  local s="$1"
  s="${s//\\/\\\\}"     # 1) backslash -> \\   (FIRST)
  s="${s//$'\n'/\\n}"   # 2) newline   -> \n
  s="${s//$'\t'/\\t}"   # 3) TAB       -> \t
  printf '%s' "$s"
}

usage() {
  err "usage: $PROG keys [REPO_ROOT]"
  err "       $PROG docs [REPO_ROOT] [PROJECT_DOCS_ROOT] -- DOC#ANCHOR [DOC#ANCHOR ...]"
  exit 2
}

# Fixed list of the shared keys this layer reads, in place, from the driver/root
# config — never duplicated into a coherence-owned file (BRIEF.md l.90).
SHARED_KEYS="sourceGlobs uiSurfaceGlobs integrationBranch nonNegotiables domainSkills"

# resolve_profile_path <repo_root> -> echoes the config file to read, or empty.
#   `.milestone-config/driver.json` first, root `milestone-driver.json` fallback
#   (ci-preflight-steps.sh:64-65). NOTE: `.milestone-config/feeder.json` is the
#   FEEDER's and is NOT a source of these shared keys (issue #2 Design).
resolve_profile_path() {
  local root="$1" p
  p="$root/.milestone-config/driver.json"; [ -f "$p" ] && { printf '%s' "$p"; return 0; }
  p="$root/milestone-driver.json";         [ -f "$p" ] && { printf '%s' "$p"; return 0; }
  printf ''
}

# ----------------------------------------------------------------------------
# keys subcommand
# ----------------------------------------------------------------------------
cmd_keys() {
  local root="${1:-$PWD}"; root="${root%/}"

  command -v jq >/dev/null 2>&1 || { rec_error missing-tool jq "jq is required to read JSON config"; flush; return 3; }

  local profile; profile="$(resolve_profile_path "$root")"
  if [ -z "$profile" ]; then
    # Degraded: neither config file. No resolved keys; signal so the caller
    # falls back to bounded repo greps (BRIEF.md l.96). Not an error.
    rec_signal no-config
    flush; return 0
  fi

  # Validate the JSON ONCE. jq exits nonzero (5) on a parse error — distinct from
  # a valid file with a missing key (exit 0, empty value). A present-but-invalid
  # file is surfaced, never silently skipped, never crashes (BRIEF.md l.96).
  if ! jq -e . "$profile" >/dev/null 2>&1; then
    local detail; detail="$(jq . "$profile" 2>&1 >/dev/null | head -1)"
    rec_error malformed-config "$profile" "${detail:-invalid JSON}"
    flush; return 3
  fi

  local k val present
  for k in $SHARED_KEYS; do
    # Presence test (-e): a key set to null or absent both -> skip; only a real
    # value is emitted. This is also why we never fabricate a default.
    if jq -e --arg k "$k" 'has($k) and (.[$k] != null)' "$profile" >/dev/null 2>&1; then
      present=1
    else
      present=0
    fi
    if [ "$present" -eq 0 ]; then
      rec_skip key "$k" "absent-from-config"
      continue
    fi
    # Emit one record per array element; a scalar emits one record. jq prints each
    # element NUL-terminated (read consumes them with -d '') so a value with an
    # embedded newline arrives WHOLE — never split across the read loop (finding 1).
    # encode_value then collapses any internal newline to a literal "\n", so the
    # value is exactly one record. Strip all CR for Windows-authored config parity
    # (ci-preflight-steps.sh strips CR per line) before encoding.
    while IFS= read -r -d '' val; do
      val="${val//$'\r'/}"
      rec_key "$k" "$(encode_value "$val")"
    done < <(jq -j --arg k "$k" '.[$k] | if type=="array" then .[] else . end | tostring + "\u0000"' "$profile" 2>/dev/null)
  done

  flush
  return 0
}

# ----------------------------------------------------------------------------
# Locate the INSTALLED milestone-driver's read-doc-section primitive.
# Most-robust-first; degrades to empty (caller treats every section as
# unresolvable -> absence-means-skip). We do NOT reimplement the primitive.
# ----------------------------------------------------------------------------
locate_read_doc_section() {
  local cand plugins_root

  # (1) Co-installed sibling via CLAUDE_PLUGIN_ROOT. That var is THIS plugin's
  #     own versioned install dir: <plugins>/cache/<marketplace>/<plugin>/<ver>.
  #     Two dirname's strip <plugin>/<ver>, leaving the marketplace dir under
  #     which the driver is a sibling: <marketplace>/milestone-driver/<ver>/...
  #     (NO extra "*/" level — that never matched the real cache layout; finding
  #     2). Pick the highest SemVer dir with sort -V.
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    local market_dir; market_dir="$(dirname "$(dirname "$CLAUDE_PLUGIN_ROOT")")"
    cand="$(ls -d "$market_dir"/milestone-driver/*/scripts/read-doc-section.sh 2>/dev/null | sort -V | tail -1)"
    [ -n "$cand" ] && [ -f "$cand" ] && { printf '%s' "$cand"; return 0; }
  fi

  # Determine the plugins root (CLAUDE_CONFIG_DIR override, else ~/.claude).
  plugins_root="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins"

  # (2) Canonical, version-independent: the installed-plugins manifest maps
  #     "milestone-driver@milestone-suite" -> [{ installPath, ... }].
  local manifest="$plugins_root/installed_plugins.json"
  if [ -f "$manifest" ] && command -v jq >/dev/null 2>&1; then
    local ip
    ip="$(jq -r '.plugins["milestone-driver@milestone-suite"] // [] | .[0].installPath // empty' "$manifest" 2>/dev/null)"
    if [ -n "$ip" ] && [ -f "$ip/scripts/read-doc-section.sh" ]; then
      printf '%s' "$ip/scripts/read-doc-section.sh"; return 0
    fi
  fi

  # (3) Glob the cache, highest version wins.
  cand="$(ls -d "$plugins_root"/cache/milestone-suite/milestone-driver/*/scripts/read-doc-section.sh 2>/dev/null | sort -V | tail -1)"
  [ -n "$cand" ] && [ -f "$cand" ] && { printf '%s' "$cand"; return 0; }

  printf ''
}

# ----------------------------------------------------------------------------
# docs subcommand
# ----------------------------------------------------------------------------
cmd_docs() {
  # Parse: [REPO_ROOT] [PROJECT_DOCS_ROOT] -- DOC#ANCHOR ...
  local root="$PWD" docs_root="" saw_root=0
  local -a specs=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --) shift; specs=("$@"); break ;;
      *)
        if [ "$saw_root" -eq 0 ]; then root="$1"; saw_root=1
        elif [ -z "$docs_root" ]; then docs_root="$1"
        else err "$PROG: docs: unexpected positional arg before --: $1"; usage; fi
        shift ;;
    esac
  done
  root="${root%/}"
  # projectDocs key default is `.project/` (BRIEF.md l.89). Allow an explicit
  # override (e.g. the driver's `projectDocs` profile value) as the 2nd arg.
  [ -z "$docs_root" ] && docs_root="$root/.project"
  docs_root="${docs_root%/}"
  # Absolutize a relative override against the repo root.
  case "$docs_root" in /*) : ;; *) docs_root="$root/$docs_root" ;; esac

  if [ "${#specs[@]}" -eq 0 ]; then
    err "$PROG: docs: no DOC#ANCHOR specs given (after --)"; usage
  fi

  # Empty / no-grounding state: no docs root at all -> empty result + signal so
  # the caller degrades to bounded greps; not a crash (BRIEF.md l.89, l.96).
  if [ ! -d "$docs_root" ]; then
    rec_signal no-doc-grounding
    flush; return 0
  fi

  # Locate the driver primitive once. Missing -> we cannot resolve any section;
  # signal no-doc-grounding (caller degrades) and skip each spec. Not a crash.
  local reader; reader="$(locate_read_doc_section)"
  if [ -z "$reader" ]; then
    local spec
    for spec in "${specs[@]}"; do
      rec_skip section "$spec" "primitive-unavailable"
    done
    rec_signal no-doc-grounding
    flush; return 0
  fi

  local resolved=0 spec doc anchor docpath body rc
  for spec in "${specs[@]}"; do
    # Split on the FIRST '#': doc is before, anchor (heading text) is after.
    doc="${spec%%#*}"
    anchor="${spec#*#}"
    if [ "$doc" = "$spec" ] || [ -z "$doc" ] || [ -z "$anchor" ]; then
      rec_skip section "$spec" "malformed-spec-expected-DOC#ANCHOR"
      continue
    fi
    docpath="$docs_root/$doc"

    # Invoke the driver primitive. It is fail-CLOSED: a missing file/anchor exits
    # nonzero with empty stdout. We CATCH that nonzero and translate it into
    # absence-means-skip (BRIEF.md l.89; issue #2 triage note).
    #
    # Capture with a sentinel byte then strip it, so a body that ends in blank
    # lines is preserved VERBATIM. A plain `$(...)` strips ALL trailing newlines,
    # which dropped a section's trailing blank lines and diverged from the .ps1
    # twin (re-review finding 3). The body is the grounding payload and the
    # primitive emits it verbatim, so we PRESERVE it verbatim here too.
    body="$(bash "$reader" "$docpath" "$anchor" 2>/dev/null; printf 'X')"; rc=$?
    body="${body%X}"
    if [ "$rc" -ne 0 ]; then
      rec_skip section "$spec" "absent-or-unreadable"
      continue
    fi
    # The primitive terminates its output with exactly one trailing newline (its
    # final `printf '%s\n'`). Strip that ONE line-terminator so the body splits
    # into the same line set the .ps1 twin gets from `& pwsh` (which strips the
    # single final newline when building its array). Any blank lines BEFORE it —
    # the section's real trailing blanks — are kept, byte-for-byte identical to
    # the .ps1 (re-review finding 3).
    body="${body%$'\n'}"

    # Classify on the NON-heading body only (drop line 1, the matched heading).
    # below = the body with the heading removed.
    local below; below="$(printf '%s\n' "$body" | sed '1d')"
    # Body with only the heading line and nothing else is empty grounding.
    if [ "$(printf '%s' "$below" | tr -d '[:space:]')" = "" ]; then
      rec_skip section "$spec" "empty-section"
      continue
    fi
    # A section is a [TBD] PLACEHOLDER only when its non-heading body is SOLELY a
    # [TBD] marker — i.e. once blank lines are dropped, the only content is a lone
    # line equal to "[TBD]" (trimmed). A substantive section that merely MENTIONS
    # [TBD] in one sub-bullet is real grounding and is NOT dropped (finding 3).
    if [ "$(printf '%s\n' "$below" | grep -v '^[[:space:]]*$' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')" = "[TBD]" ]; then
      rec_skip section "$spec" "tbd-placeholder"
      continue
    fi

    emit "SECTION-BEGIN	$doc	$anchor"
    # Body verbatim, line by line, into the buffer (preserves the caller's slice),
    # INCLUDING any trailing blank lines. $body had its single trailing
    # line-terminator stripped above; the heredoc re-adds exactly one, so the
    # `while read` yields the same line set — heading + content + every interior
    # AND trailing blank line — that the .ps1 twin's array carries (re-review
    # finding 3). The `|| [ -n "$line" ]` keeps a final unterminated segment.
    #
    # Strip a trailing CR from each body line before emit. A CRLF-authored
    # `.project/` doc leaves the CR on every line here (`read -r` keeps it, and the
    # driver primitive's own `read -r` retains it too), but the .ps1 twin emits
    # those lines CR-free (pwsh native-command capture and the primitive's
    # Get-Content both strip CR). Canonicalizing the body to CR-free LF on BOTH
    # twins restores byte-for-byte parity for CRLF docs (re-review finding 9) and
    # mirrors the CR-strip already applied to KEY values above (l.189).
    while IFS= read -r line || [ -n "$line" ]; do emit "${line//$'\r'/}"; done <<EOF_BODY
$body
EOF_BODY
    emit "SECTION-END	$doc	$anchor"
    n_sections=$((n_sections+1)); resolved=$((resolved+1))
  done

  # Nothing resolved at all (every cited section absent/[TBD]) -> signal the
  # caller to degrade, just like an absent docs root (BRIEF.md l.96).
  [ "$resolved" -eq 0 ] && rec_signal no-doc-grounding

  flush
  return 0
}

# ----------------------------------------------------------------------------
# dispatch
# ----------------------------------------------------------------------------
[ "$#" -ge 1 ] || usage
SUB="$1"; shift
case "$SUB" in
  keys) cmd_keys "$@" ;;
  docs) cmd_docs "$@" ;;
  -h|--help|help) usage ;;
  *) err "$PROG: unknown subcommand: $SUB"; usage ;;
esac
