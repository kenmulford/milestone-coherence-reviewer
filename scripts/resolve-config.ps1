#!/usr/bin/env pwsh
# milestone-coherence-reviewer — config + project-docs resolution layer (issue #2).
# PowerShell 7+ twin of resolve-config.sh — byte-parity record stream, same exit
# codes, same degradation matrix. (Cross-platform: bash-first, pwsh fallback —
# BRIEF.md §Constraints l.130; host selection mirrors ci-preflight-steps.{sh,ps1}.)
#
# See resolve-config.sh for the full contract. Summary:
#   resolve-config.ps1 keys [REPO_ROOT]
#   resolve-config.ps1 docs [REPO_ROOT] [PROJECT_DOCS_ROOT] -- DOC#ANCHOR [DOC#ANCHOR ...]
#
# Records (TAB-separated): KEY · SKIP · SIGNAL · SECTION-BEGIN/END · ERROR · SUMMARY.
# Exit: 0 ran (incl. clean degradation) · 2 bad usage · 3 malformed config surfaced.
#
# Config reads use PowerShell's built-in ConvertFrom-Json (no new dependency); the
# doc-section read invokes the installed milestone-driver's read-doc-section.ps1
# primitive (located, not reimplemented), which is fail-CLOSED and translated here
# into absence-means-skip.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Prog = 'resolve-config'
$TAB  = "`t"
function Err([string]$msg) { [Console]::Error.WriteLine($msg) }

# Buffered emission so SUMMARY comes last (mirrors the .sh emit/flush).
$script:nKeys = 0; $script:nSections = 0; $script:nSkipped = 0
$script:nSignals = 0; $script:nErrors = 0
$script:OutLines = [System.Collections.Generic.List[string]]::new()
function Emit([string]$line) { $script:OutLines.Add($line) }
function Flush {
  foreach ($l in $script:OutLines) { if ($l -ne $null -and $l.Length -ge 0) { [Console]::Out.Write($l + "`n") } }
  [Console]::Out.Write("SUMMARY${TAB}keys=$($script:nKeys)${TAB}sections=$($script:nSections)${TAB}skipped=$($script:nSkipped)${TAB}signals=$($script:nSignals)${TAB}errors=$($script:nErrors)`n")
}
function RecKey([string]$n,[string]$v)            { Emit "KEY${TAB}$n${TAB}$v"; $script:nKeys++ }
function RecSkip([string]$k,[string]$n,[string]$r) { Emit "SKIP${TAB}$k${TAB}$n${TAB}$r"; $script:nSkipped++ }
function RecSignal([string]$n)                     { Emit "SIGNAL${TAB}$n"; $script:nSignals++ }
function RecError([string]$k,[string]$f,[string]$d) { Emit "ERROR${TAB}$k${TAB}$f${TAB}$d"; $script:nErrors++; Err "${Prog}: ${k}: ${f}: ${d}" }

# Encode-Value: make a single value EXACTLY one record, never corrupting the
# TAB-separated stream, regardless of internal newlines OR tabs. Canonical escape
# order (identical in the .sh twin): backslash -> "\\" FIRST, then newline ->
# "\n", then TAB -> "\t". Backslash must be escaped first so the backslashes we
# introduce are not double-escaped. A literal TAB in a value would otherwise add
# spurious columns to a KEY<TAB>name<TAB>value record (re-review finding 1).
# Extends ci-preflight-steps.ps1:68-71's Encode-Cmd, which escaped only
# backslash+newline, with the TAB case the record stream requires. Normalize CR
# first so a CRLF value encodes to one "\n", matching the .sh twin (which runs
# under LC_ALL=C and reads CR-stripped values). .Replace() preserves a trailing
# newline, so a value ending in "\n" round-trips identically to the .sh twin
# (re-review finding 2).
function Encode-Value([string]$s) {
  $s = $s -replace "`r", ''
  $s = $s.Replace('\', '\\')   # 1) backslash -> \\   (FIRST)
  $s = $s.Replace("`n", '\n')  # 2) newline   -> \n
  return $s.Replace("`t", '\t') # 3) TAB       -> \t
}

function Usage {
  Err "usage: $Prog keys [REPO_ROOT]"
  Err "       $Prog docs [REPO_ROOT] [PROJECT_DOCS_ROOT] -- DOC#ANCHOR [DOC#ANCHOR ...]"
  exit 2
}

# The shared keys read in place from the driver/root config — never duplicated
# into a coherence-owned file (BRIEF.md l.90).
$SharedKeys = @('sourceGlobs','uiSurfaceGlobs','integrationBranch','nonNegotiables','domainSkills')

# Resolve the config file: `.milestone-config/driver.json` first, root fallback.
function Resolve-ProfilePath([string]$root) {
  $p = Join-Path $root '.milestone-config/driver.json'
  if (Test-Path -LiteralPath $p -PathType Leaf) { return $p }
  $p = Join-Path $root 'milestone-driver.json'
  if (Test-Path -LiteralPath $p -PathType Leaf) { return $p }
  return ''
}

function Cmd-Keys([string[]]$rest) {
  $root = if ($rest.Count -ge 1) { $rest[0] } else { (Get-Location).Path }
  $root = $root.TrimEnd('/','\')

  # NB: not $profile — that is a PowerShell automatic variable (the host profile
  # path); shadowing it is a footgun. Use an explicit local.
  $profilePath = Resolve-ProfilePath $root
  if ([string]::IsNullOrEmpty($profilePath)) {
    # Degraded: neither config file. Signal so the caller falls back to greps.
    RecSignal 'no-config'; Flush; return 0
  }

  # Parse ONCE. A parse failure is a present-but-invalid file: surface it, never
  # silently skip, never fabricate, never crash (BRIEF.md l.96).
  $cfg = $null
  try {
    $raw = Get-Content -LiteralPath $profilePath -Raw -ErrorAction Stop
    $cfg = $raw | ConvertFrom-Json -ErrorAction Stop
  } catch {
    $detail = ($_.Exception.Message -split "`n")[0]
    RecError 'malformed-config' $profilePath $detail
    Flush; return 3
  }

  foreach ($k in $SharedKeys) {
    $has = $false; $val = $null
    if ($cfg.PSObject.Properties.Name -contains $k) {
      $val = $cfg.$k
      if ($null -ne $val) { $has = $true }
    }
    if (-not $has) { RecSkip 'key' $k 'absent-from-config'; continue }
    # Emit one record per array element; a scalar emits one record. Encode-Value
    # collapses any embedded newline to a literal "\n" so each element is exactly
    # one record (finding 1).
    if ($val -is [System.Array]) {
      foreach ($e in $val) { RecKey $k (Encode-Value ([string]$e)) }
    } else {
      RecKey $k (Encode-Value ([string]$val))
    }
  }

  Flush; return 0
}

# Select-HighestVersionPath: from candidate '.../<ver>/scripts/read-doc-section.ps1'
# paths, return the one whose VERSION DIR (two levels above the file) is the
# genuinely-highest SemVer — numeric major/minor/patch, NOT lexical. Lexical sort
# mis-orders 1.9.0 above 1.10.0/1.12.0 (finding 5); this matches the .sh's
# `sort -V`. The version dir is $_.Directory.Parent.Name (…/<ver>/scripts/<file>).
function Select-HighestVersionPath {
  param([System.IO.FileInfo[]]$Candidates)
  if (-not $Candidates -or $Candidates.Count -eq 0) { return '' }
  $best = $null; $bestVer = $null
  foreach ($c in $Candidates) {
    $verDir = $c.Directory.Parent.Name
    $v = $null
    # Parse the leading numeric major.minor.patch; ignore any pre-release suffix.
    $m = [regex]::Match($verDir, '^(\d+)\.(\d+)\.(\d+)')
    if ($m.Success) {
      $v = [version]::new([int]$m.Groups[1].Value, [int]$m.Groups[2].Value, [int]$m.Groups[3].Value)
    } else {
      # Unparseable version dir: rank it lowest so a valid SemVer always wins.
      $v = [version]::new(0,0,0)
    }
    if (($null -eq $bestVer) -or ($v -gt $bestVer)) { $bestVer = $v; $best = $c }
  }
  if ($best) { return $best.FullName }
  return ''
}

# Locate the installed milestone-driver read-doc-section.ps1 primitive.
# Most-robust-first; degrades to '' (caller treats sections as unresolvable).
function Locate-ReadDocSection {
  # (1) Co-installed sibling via CLAUDE_PLUGIN_ROOT. That var is THIS plugin's own
  #     versioned install dir: <plugins>/cache/<marketplace>/<plugin>/<ver>. Two
  #     Split-Parents strip <plugin>/<ver>, leaving the marketplace dir under which
  #     the driver is a sibling: <marketplace>/milestone-driver/<ver>/scripts/...
  #     Glob that exact shape (no broad -Recurse, which could match an unrelated
  #     path containing 'milestone-driver'; finding 2) and pick the highest SemVer
  #     (finding 5).
  if (-not [string]::IsNullOrEmpty($env:CLAUDE_PLUGIN_ROOT)) {
    $marketDir = Split-Path -Parent (Split-Path -Parent $env:CLAUDE_PLUGIN_ROOT)
    $siblingGlob = Join-Path $marketDir 'milestone-driver'
    if (Test-Path -LiteralPath $siblingGlob -PathType Container) {
      $cands = @(Get-ChildItem -Path (Join-Path $siblingGlob '*/scripts/read-doc-section.ps1') -File -ErrorAction SilentlyContinue)
      $pick = Select-HighestVersionPath $cands
      if (-not [string]::IsNullOrEmpty($pick)) { return $pick }
    }
  }

  $pluginsRoot = if (-not [string]::IsNullOrEmpty($env:CLAUDE_CONFIG_DIR)) {
    Join-Path $env:CLAUDE_CONFIG_DIR 'plugins'
  } else {
    Join-Path $HOME '.claude/plugins'
  }

  # (2) Canonical: installed_plugins.json -> installPath.
  $manifest = Join-Path $pluginsRoot 'installed_plugins.json'
  if (Test-Path -LiteralPath $manifest -PathType Leaf) {
    try {
      $m = Get-Content -LiteralPath $manifest -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
      $entry = $m.plugins.'milestone-driver@milestone-suite'
      if ($entry) {
        $ip = @($entry)[0].installPath
        $readerPath = Join-Path $ip 'scripts/read-doc-section.ps1'
        if ((-not [string]::IsNullOrEmpty($ip)) -and (Test-Path -LiteralPath $readerPath -PathType Leaf)) { return $readerPath }
      }
    } catch { }
  }

  # (3) Glob the cache, highest SemVer wins (numeric, matching .sh's sort -V;
  #     finding 5).
  $cacheGlob = Join-Path $pluginsRoot 'cache/milestone-suite/milestone-driver'
  if (Test-Path -LiteralPath $cacheGlob -PathType Container) {
    $cands = @(Get-ChildItem -Path (Join-Path $cacheGlob '*/scripts/read-doc-section.ps1') -File -ErrorAction SilentlyContinue)
    $pick = Select-HighestVersionPath $cands
    if (-not [string]::IsNullOrEmpty($pick)) { return $pick }
  }

  return ''
}

function Cmd-Docs([string[]]$rest) {
  # Parse: [REPO_ROOT] [PROJECT_DOCS_ROOT] -- DOC#ANCHOR ...
  $root = (Get-Location).Path; $docsRoot = ''; $sawRoot = $false
  # @() forces an array even for 0 or 1 spec — avoids PowerShell's scalar-from-
  # single-element-slice and its reverse-range when `--` is the last token.
  $specs = @(); $i = 0
  while ($i -lt $rest.Count) {
    $a = $rest[$i]
    if ($a -eq '--') {
      if (($i + 1) -lt $rest.Count) { $specs = @($rest[($i+1)..($rest.Count-1)]) }
      break
    }
    if (-not $sawRoot) { $root = $a; $sawRoot = $true }
    elseif ([string]::IsNullOrEmpty($docsRoot)) { $docsRoot = $a }
    else { Err "${Prog}: docs: unexpected positional arg before --: $a"; Usage }
    $i++
  }
  $root = $root.TrimEnd('/','\')
  if ([string]::IsNullOrEmpty($docsRoot)) { $docsRoot = Join-Path $root '.project' }
  if (-not [System.IO.Path]::IsPathRooted($docsRoot)) { $docsRoot = Join-Path $root $docsRoot }
  $docsRoot = $docsRoot.TrimEnd('/','\')

  if (($null -eq $specs) -or ($specs.Count -eq 0)) {
    Err "${Prog}: docs: no DOC#ANCHOR specs given (after --)"; Usage
  }

  # No docs root at all -> empty result + signal (BRIEF.md l.89, l.96).
  if (-not (Test-Path -LiteralPath $docsRoot -PathType Container)) {
    RecSignal 'no-doc-grounding'; Flush; return 0
  }

  $reader = Locate-ReadDocSection
  if ([string]::IsNullOrEmpty($reader)) {
    foreach ($spec in $specs) { RecSkip 'section' $spec 'primitive-unavailable' }
    RecSignal 'no-doc-grounding'; Flush; return 0
  }

  # Find a pwsh to run the primitive with. Prefer a 'pwsh' on PATH (the install's
  # own launcher/shim), then the running PowerShell's $PSHOME binary, then the
  # host process path. NOT (Get-Process -Id $PID).Path alone — that returns the
  # dotnet host, not pwsh, when PowerShell is a dotnet global tool. On a standard
  # PS7 install all candidates agree; the list just covers edge installs.
  $pwshExe = $null
  $onPath = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($onPath) { $pwshExe = $onPath.Source }
  if ([string]::IsNullOrEmpty($pwshExe)) {
    foreach ($cand in @((Join-Path $PSHOME 'pwsh'), (Join-Path $PSHOME 'pwsh.exe'))) {
      if (Test-Path -LiteralPath $cand -PathType Leaf) { $pwshExe = $cand; break }
    }
  }
  if ([string]::IsNullOrEmpty($pwshExe)) { $pwshExe = 'pwsh' }

  $resolved = 0
  foreach ($spec in $specs) {
    $hash = $spec.IndexOf('#')
    if ($hash -le 0 -or $hash -ge ($spec.Length - 1)) {
      RecSkip 'section' $spec 'malformed-spec-expected-DOC#ANCHOR'; continue
    }
    $doc    = $spec.Substring(0, $hash)
    $anchor = $spec.Substring($hash + 1)
    $docpath = Join-Path $docsRoot $doc

    # Invoke the fail-CLOSED primitive; catch nonzero -> absence-means-skip. Wrap
    # in try/catch so a spawn failure (bad pwsh path, etc.) also degrades to skip
    # rather than crashing the run.
    $body = $null
    try { $body = & $pwshExe -NoProfile -File $reader $docpath $anchor 2>$null }
    catch { RecSkip 'section' $spec 'absent-or-unreadable'; continue }
    if ($LASTEXITCODE -ne 0) { RecSkip 'section' $spec 'absent-or-unreadable'; continue }

    # Normalize to a line array. & pwsh returns stdout already split on newlines
    # with the single final line-terminator consumed — so @($body) IS the verbatim
    # body: heading + content + every interior AND trailing blank line. Do NOT drop
    # a further trailing element: that ate one of the section's real trailing blank
    # lines and diverged from the .sh twin (re-review finding 3). The .sh twin
    # mirrors this exactly by stripping its primitive's single trailing newline
    # before splitting, so both carry the identical line set.
    $lines = @($body)

    # Classify on the NON-heading body only (drop line 1, the matched heading).
    # Blank lines inside the body are PRESERVED in $lines and emitted verbatim, so
    # a real Markdown section round-trips byte-for-byte with the .sh twin
    # (finding 4).
    $belowLines = @($lines | Select-Object -Skip 1)
    # Body with only the heading line (rest whitespace) is empty grounding.
    if ((($belowLines -join '') -replace '\s','') -eq '') { RecSkip 'section' $spec 'empty-section'; continue }
    # A section is a [TBD] PLACEHOLDER only when its non-heading body is SOLELY a
    # [TBD] marker — once blank lines are dropped, the only content is a lone line
    # equal to "[TBD]" (trimmed). A substantive section that merely MENTIONS [TBD]
    # in one sub-bullet is real grounding and is NOT dropped (finding 3). -ceq:
    # case-sensitive, matching the .sh's literal "[TBD]" compare.
    $nonBlank = @($belowLines | Where-Object { ($_ -replace '\s','') -ne '' } | ForEach-Object { $_.Trim() })
    if ($nonBlank.Count -eq 1 -and ($nonBlank[0] -ceq '[TBD]')) { RecSkip 'section' $spec 'tbd-placeholder'; continue }

    Emit "SECTION-BEGIN${TAB}$doc${TAB}$anchor"
    foreach ($line in $lines) { Emit $line }
    Emit "SECTION-END${TAB}$doc${TAB}$anchor"
    $script:nSections++; $resolved++
  }

  if ($resolved -eq 0) { RecSignal 'no-doc-grounding' }
  Flush; return 0
}

# dispatch
if ($args.Count -lt 1) { Usage }
$sub = $args[0]
$rest = if ($args.Count -gt 1) { @($args[1..($args.Count-1)]) } else { @() }
switch ($sub) {
  'keys'   { exit (Cmd-Keys $rest) }
  'docs'   { exit (Cmd-Docs $rest) }
  '-h'     { Usage }
  '--help' { Usage }
  'help'   { Usage }
  default  { Err "${Prog}: unknown subcommand: $sub"; Usage }
}
