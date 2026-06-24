#!/usr/bin/env pwsh
# milestone-coherence-reviewer — memory-mirror helper (issue #5).
# PowerShell 7+ twin of memory-mirror.sh — same detect-or-fallback resolution,
# same best-effort contract, same exit codes. (Cross-platform: bash-first, pwsh
# fallback — BRIEF.md §Constraints l.131; host selection mirrors resolve-config.{sh,ps1}.)
#
# Writes the coherence write-up to the user's memory store as the SUPPLEMENTAL
# audit-trail copy. The inline summary is the PRIMARY deliverable (docs/write-up.md);
# this is one of its three supplemental mirrors, so it is BEST-EFFORT: a write
# failure is reported on stderr and exits nonzero, but it NEVER crashes the caller
# and NEVER suppresses the inline summary (BRIEF.md l.68, l.89, l.96).
#
# See memory-mirror.sh for the full contract. Summary:
#   memory-mirror.ps1 --slug <issue-or-pr-slug> [--repo-root <dir>] [--file <path>]
#   memory-mirror.ps1 --slug <slug> [--repo-root <dir>]   # content on stdin
#
# Target resolution — DETECT-OR-FALLBACK (conservative; each leg needs an
# already-configured opt-in signal):
#   1. $env:NPM_CLAUDE_VAULT_ROOT set AND `Claude Memory/MEMORY.md` exists under it
#   2. a `.obsidian/` dir at the repo root
#   3. `autoMemoryDirectory` in a `.claude/settings*.json`
#   FALLBACK: a git-invisible `.md` under `.milestone-config/.runtime/` (already
#   ignored via the nested .gitignore `.runtime/` entry — no new ignore rule).
#
# Exit: 0 wrote the mirror · 2 bad usage · 1 best-effort write failed (reported,
#   never a crash). Output: success path on stdout; `MIRROR`/`MIRROR-FAILED`
#   record on stderr.
#
# Dependency: none required. Detection leg 3 uses PowerShell's built-in
#   ConvertFrom-Json (no jq); legs 1, 2 and the fallback need nothing extra.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Prog = 'memory-mirror'
$TAB  = "`t"
function Err([string]$msg) { [Console]::Error.WriteLine($msg) }
function Fail([string]$reason) { Err "MIRROR-FAILED${TAB}$reason"; exit 1 }  # best-effort

function Usage {
  Err "usage: $Prog --slug <issue-or-pr-slug> [--repo-root <dir>] [--file <path>]"
  Err "       $Prog --slug <slug> [--repo-root <dir>] < write-up.md"
  exit 2
}

# ----------------------------------------------------------------------------
# Parse args (manual, to mirror the .sh's flag set exactly).
# ----------------------------------------------------------------------------
$slug = ''; $repoRoot = (Get-Location).Path; $contentFile = ''
$i = 0
while ($i -lt $args.Count) {
  switch ($args[$i]) {
    '--slug'      { if (($i + 1) -ge $args.Count) { Usage }; $slug = $args[$i+1]; $i += 2 }
    '--repo-root' { if (($i + 1) -ge $args.Count) { Usage }; $repoRoot = $args[$i+1]; $i += 2 }
    '--file'      { if (($i + 1) -ge $args.Count) { Usage }; $contentFile = $args[$i+1]; $i += 2 }
    '-h'          { Usage }
    '--help'      { Usage }
    'help'        { Usage }
    default       { Err "${Prog}: unexpected arg: $($args[$i])"; Usage }
  }
}
if ([string]::IsNullOrEmpty($slug)) { Err "${Prog}: --slug is required"; Usage }
$repoRoot = $repoRoot.TrimEnd('/','\')

# Sanitize the slug: keep word chars, dot and dash; collapse the rest to '-'.
$safeSlug = ($slug -replace '[^A-Za-z0-9._-]', '-')
if ([string]::IsNullOrEmpty($safeSlug)) { $safeSlug = 'coherence' }

# ----------------------------------------------------------------------------
# Read the write-up content (from --file or stdin). Best-effort: an unreadable
# file is a write failure, not a crash. -Raw preserves the content verbatim.
# ----------------------------------------------------------------------------
if (-not [string]::IsNullOrEmpty($contentFile)) {
  if (-not (Test-Path -LiteralPath $contentFile -PathType Leaf)) { Fail "content file not found: $contentFile" }
  try { $content = Get-Content -LiteralPath $contentFile -Raw -ErrorAction Stop } catch { Fail "could not read content file: $contentFile" }
} else {
  # Read all of stdin BYTE-EXACT. NOT `$input | Out-String` — that re-joins lines
  # with the platform newline, appends a trailing newline, and can hard-wrap long
  # lines at the host buffer width, which would diverge from the .sh's byte-exact
  # `$(cat; printf X)` capture. ReadToEnd() returns the raw stream verbatim.
  $content = [Console]::In.ReadToEnd()
}
if ($null -eq $content) { $content = '' }

# ----------------------------------------------------------------------------
# Detect-or-fallback target resolution -> returns @(tier, memFile).
# Conservative: each leg requires an already-configured opt-in signal.
# ----------------------------------------------------------------------------
function Resolve-Target {
  # Leg 1 — Obsidian vault via $env:NPM_CLAUDE_VAULT_ROOT. Opt-in: env set AND a
  # `Claude Memory/MEMORY.md` already exists under it.
  if (-not [string]::IsNullOrEmpty($env:NPM_CLAUDE_VAULT_ROOT)) {
    $f = Join-Path ($env:NPM_CLAUDE_VAULT_ROOT.TrimEnd('/','\')) 'Claude Memory/MEMORY.md'
    if (Test-Path -LiteralPath $f -PathType Leaf) { return @('vault-env', $f) }
  }

  # Leg 2 — a `.obsidian/` dir at the repo root is the opt-in for an in-repo vault.
  if (Test-Path -LiteralPath (Join-Path $repoRoot '.obsidian') -PathType Container) {
    return @('vault-repo', (Join-Path $repoRoot 'Claude Memory/coherence-memory.md'))
  }

  # Leg 3 — Claude Code project memory via `autoMemoryDirectory` in any
  # `.claude/settings*.json`. ConvertFrom-Json is built in (no jq).
  $claudeDir = Join-Path $repoRoot '.claude'
  if (Test-Path -LiteralPath $claudeDir -PathType Container) {
    $settings = @(Get-ChildItem -Path (Join-Path $claudeDir 'settings*.json') -File -ErrorAction SilentlyContinue)
    foreach ($s in $settings) {
      try {
        $cfg = Get-Content -LiteralPath $s.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
      } catch { continue }
      $dir = $null
      if ($cfg.PSObject.Properties.Name -contains 'autoMemoryDirectory') { $dir = $cfg.autoMemoryDirectory }
      if ([string]::IsNullOrEmpty($dir)) { continue }
      if (-not [System.IO.Path]::IsPathRooted($dir)) { $dir = Join-Path $repoRoot $dir }
      return @('claude-mem', (Join-Path ($dir.TrimEnd('/','\')) 'coherence-memory.md'))
    }
  }

  # Fallback — git-invisible `.md` under `.milestone-config/.runtime/` (already
  # ignored via the nested .gitignore `.runtime/` entry; no new ignore rule). A
  # top-level `.milestone-config/*.md` would NOT be ignored, so it lives here.
  return @('fallback', (Join-Path $repoRoot '.milestone-config/.runtime/coherence-memory.md'))
}

$target  = Resolve-Target
$tier    = $target[0]
$memFile = $target[1]

# ----------------------------------------------------------------------------
# Append the write-up as a dated, slug-headed entry. Create the parent on demand.
# Write BOM-less UTF-8 with LF — explicitly, NOT `>>`/Out-File (which default to
# UTF-16/ANSI on Windows PowerShell and would corrupt the audit trail). All ops
# are best-effort: any failure -> report and exit 1, never crash.
# ----------------------------------------------------------------------------
$memDir = Split-Path -Parent $memFile
try { if (-not (Test-Path -LiteralPath $memDir -PathType Container)) { New-Item -ItemType Directory -Path $memDir -Force -ErrorAction Stop | Out-Null } }
catch { Fail "could not create memory dir: $memDir" }

$stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

# Build the entry with LF line endings, then APPEND as BOM-less UTF-8 bytes so the
# growing file never accumulates a BOM and stays LF on every host. The content is
# written VERBATIM with exactly one LF terminator appended — byte-identical to the
# .sh's `printf '%s\n' "$CONTENT"`. Do NOT TrimEnd the content: the .sh preserves
# the content's own trailing newline(s), so stripping here would diverge (content
# ending in a newline would write one fewer byte than the .sh).
$entry = "`n## Coherence write-up — $safeSlug ($stamp)`n`n" + $content + "`n"
$entry = $entry -replace "`r`n", "`n"
try {
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  $bytes = $utf8NoBom.GetBytes($entry)
  $fs = [System.IO.File]::Open($memFile, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
  try { $fs.Write($bytes, 0, $bytes.Length) } finally { $fs.Dispose() }
} catch { Fail "could not write memory file: $memFile" }

# Success: path on stdout (for the caller to surface), record on stderr (log).
Err "MIRROR${TAB}$tier${TAB}$memFile"
[Console]::Out.Write($memFile + "`n")
exit 0
