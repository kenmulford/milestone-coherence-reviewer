#!/usr/bin/env bash
# scripts/check-script-invocations.sh — the CI check that run-time instruction
# text invokes this plugin's scripts through the plugin root.
#
# A consumer repo has no scripts/ directory, so an invocation written as
# `scripts/<x> …` or `./scripts/<x>` resolves against the wrong CWD on every
# runtime. Invocations are written `"${CLAUDE_PLUGIN_ROOT}/scripts/<x>" …`.
#
# Scanned: skills/*/SKILL.md, skills/*.md, agents/*.md, docs/*.md.
# Exempt:  docs/validation-note.md (a record of past commands, not instructions).
#
# A hit is either:
#   - `./scripts/<x>` anywhere, or
#   - `scripts/<x>.<ext>` followed by an argument (a flag, a `<placeholder>`,
#     or a subcommand: keys, docs, cite), not preceded by `/`. `<ext>` is
#     sh, ps1, `<sh|ps1>`, `<sh\|ps1>`, or `{sh,ps1}`.
# A path alone, `scripts/x.sh (anchor)`, and `<other-plugin>/scripts/x.sh` are
# citations and pass.
#
# Usage:   check-script-invocations.sh [REPO_ROOT]   (default: CWD)
# Output (stdout), TAB-separated:
#   FAIL  <file>:<line>  <line text>
#   SUMMARY files=<scanned> hits=<N>
# Exit 0 with no hits, 1 otherwise.
#
# No pwsh twin: CI-only, like scripts/check-size-budgets.sh.
set -u
export LC_ALL=C

ROOT="${1:-$PWD}"
ROOT="${ROOT%/}"

PRE='(^|[^A-Za-z0-9_./}-])'
EXT='(sh|ps1|<sh\\?\|ps1>|\{sh,ps1\})'
ARGS='"?[ ]+(-|<|keys([^A-Za-z]|$)|docs([^A-Za-z]|$)|cite([^A-Za-z]|$))'
INVOKE="${PRE}scripts/[A-Za-z0-9_.-]+\.${EXT}${ARGS}"
DOTSLASH="${PRE}\./scripts/"

files=0
hits=0
for f in "$ROOT"/skills/*/SKILL.md "$ROOT"/skills/*.md "$ROOT"/agents/*.md "$ROOT"/docs/*.md; do
  [ -f "$f" ] || continue
  rel="${f#"$ROOT"/}"
  [ "$rel" = "docs/validation-note.md" ] && continue
  files=$((files + 1))
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    printf 'FAIL\t%s:%s\t%s\n' "$rel" "${m%%:*}" "${m#*:}"
    hits=$((hits + 1))
  done < <(grep -nE -e "$INVOKE" -e "$DOTSLASH" "$f" | tr -d '\r')
done

printf 'SUMMARY\tfiles=%s\thits=%s\n' "$files" "$hits"
[ "$hits" -eq 0 ]
