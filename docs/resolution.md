# Resolution layer — how coherence finds its grounding

Before the coherence reviewer can ask "does this change fit how the app is
already built?", it has to read two things the rest of the suite already knows:

1. **The shared mechanics** — what counts as source, which branch work merges
   into, what the stack's best-practice sources are. These live in the
   milestone-driver's profile, and coherence reads them *in place* rather than
   keeping its own copy.
2. **The project docs** (`.project/`) — your conventions, design system, library
   manifest, and design philosophy. These are the authoritative spine of every
   finding.

This layer does that reading **once per run** and hands the result to the rest of
the tool as ready-to-use slices, so no later step has to re-open the same file.
It's the "gather once, distribute slices" half of the suite's resolve-once
pattern (`BRIEF.md` §"Analyze once, then distribute", l.33-40).

Two small cross-platform scripts do the work:

| Script | Runs on |
| --- | --- |
| `scripts/resolve-config.sh` | macOS / Linux (and anywhere bash is the shell) |
| `scripts/resolve-config.ps1` | Windows / PowerShell 7+ |

They produce **identical output** byte-for-byte; pick whichever matches the host
(bash elsewhere, pwsh on Windows — the same host rule the rest of the suite uses).

## What you run

```
# Resolve the shared keys from the driver profile.
resolve-config.sh keys [REPO_ROOT]

# Resolve specific .project/ sections (one or more "<doc>#<heading>" specs).
resolve-config.sh docs [REPO_ROOT] [PROJECT_DOCS_ROOT] -- conventions.md#Service\ layer design-system.md#Buttons

# Resolve one anchor citation — "path (anchor)" — to the line the anchor sits on.
resolve-config.sh cite scripts/resolve-config.sh 'locate_driver_script() {'
```

- `REPO_ROOT` defaults to the current directory.
- `PROJECT_DOCS_ROOT` defaults to `<REPO_ROOT>/.project` (override it if the
  driver's `projectDocs` profile key points somewhere else).
- Everything after `--` is a `<doc>#<heading>` spec: the filename under the docs
  root, then `#`, then the **heading text without the leading `#`s** (e.g.
  `conventions.md#Service layer` matches the `## Service layer` heading).
- `cite` takes exactly two arguments and no options: the **file path**, written
  as the citation writes it (a relative path resolves against the current
  directory, so run it from the repo root), and the **anchor** — a literal
  string that appears somewhere in that file. See
  ["Resolving an anchor citation"](#resolving-an-anchor-citation-cite) below.

## Where the shared keys come from (resolution order)

The keys are read from the milestone-driver's profile, **in place** — coherence
never copies them into a config file of its own (`BRIEF.md` l.90; §Constraints
l.131). The order is fixed and mirrors the feeder and `milestone-driver`'s own
`ci-preflight-steps` script:

1. `<REPO_ROOT>/.milestone-config/driver.json` — used if present.
2. `<REPO_ROOT>/milestone-driver.json` (the legacy root location) — fallback.

> Note: `.milestone-config/feeder.json` is the **feeder's** config. It is **not**
> a source of these shared keys.

The keys read are exactly these five (`BRIEF.md` l.90):

| Key | What it tells coherence |
| --- | --- |
| `sourceGlobs` | which paths count as source code |
| `uiSurfaceGlobs` | which paths are UI surfaces |
| `integrationBranch` | the branch work merges into |
| `nonNegotiables` | framework/platform constraints to honor |
| `domainSkills` | the stack's best-practice sources to cite |

A key that simply isn't in the profile is **skipped**, not invented — coherence
never fabricates a default.

## How `.project/` sections are read

Coherence does **not** re-read whole docs and does **not** re-implement a
Markdown parser. It locates the **installed milestone-driver's** `read-doc-section`
primitive and calls it once per section. That primitive prints only the one
section you asked for (the matched heading down to the next heading of the same or
higher level).

The driver primitive is **fail-closed**: a missing file or a renamed/absent
heading exits non-zero with no output. This layer **catches** that and turns it
into the suite's "absence means skip" rule — a section that can't be found is
quietly omitted, and the others still resolve.

A resolved section is also skipped when it carries no real grounding:

- **Empty** — the body (everything below the heading) is blank → `SKIP … empty-section`.
- **`[TBD]` placeholder** — the body is *solely* a `[TBD]` marker: once blank
  lines are ignored, the only content is a single line equal to `[TBD]` →
  `SKIP … tbd-placeholder`. A substantive section that merely **mentions**
  `[TBD]` in one sub-bullet still has real content, so it **resolves** — it is
  not dropped.

### Finding the driver primitive

The driver is a separate installed plugin, so this layer locates the primitive it
needs — `read-doc-section` for `docs`, `resolve-citation` for `cite` — robustly,
most-reliable-first, and degrades cleanly if it can't. It is **one** ladder,
asked for a different script name; both walk these steps in this order:

1. If `CLAUDE_PLUGIN_ROOT` is set (it is *this* plugin's own versioned install
   dir), look for the driver as a sibling under the same marketplace cache dir —
   `<marketplace>/milestone-driver/<version>/…` — and pick the highest version.
2. Read the installed-plugins manifest
   (`<plugins>/installed_plugins.json`) and follow the recorded `installPath`
   for `milestone-driver@milestone-suite` (version-independent — the canonical
   path).
3. Glob the plugin cache for any installed driver version, picking the highest.

For paths 1 and 3, "highest version" means the genuinely highest **SemVer**
(compared numerically by major / minor / patch), so `1.10.0` correctly ranks
above `1.9.0` — never a plain text sort.

If none of these finds the primitive, every requested section is skipped and the
"no doc grounding" signal is raised (see below) — never a crash. When it's `cite`
that came up empty, the same exhausted ladder exits `1` with the reason on stderr
— the same answer as an anchor that didn't resolve, so nothing downstream needs a
special case for a degraded install.

## Resolving an anchor citation (`cite`)

A citation can point at a **literal string** instead of a line number —
`path (anchor)`, the form defined in `milestone-driver`'s
`skills/citation-format.md § The four forms`. It exists because a line number
goes stale the moment anything above it is edited, silently, while an anchor
keeps naming the region it was written for.

`cite` answers one question: **is this anchor still in this file, and where?**
The coherence orchestrator asks it once per anchor-carrying finding, in the
grounding check that runs before a finding is rendered or routed
(`docs/analyze-once.md` §"Tier 2 — one bounded live re-check (only on a tier-1
miss)").

As with the section read, coherence does **not** implement the search. It locates
the installed milestone-driver's `resolve-citation` primitive — the **same
ladder**, same order, same clean degradation, described under
["Finding the driver primitive"](#finding-the-driver-primitive) — and hands it the
work. That primitive ships in milestone-driver **v1.19.0** and later; an older
driver simply doesn't have it, which the ladder reports as not found.

**`cite` is a pass-through.** Unlike `keys` and `docs`, it emits **no** record
stream and **no** `SUMMARY` line: the primitive's stdout, its stderr, and its exit
code are relayed **unchanged** — nothing reformatted, nothing filtered, nothing
re-interpreted. What the caller reads is the primitive's own answer.

On success that answer is one TAB-separated record per occurrence, in file order:

| Record | Meaning |
| --- | --- |
| `PRIMARY <line> <text>` | the **first** occurrence in the file — the resolved location |
| `MATCH <line> <text>` | every further occurrence, when the anchor isn't unique |

`<line>` is 1-based; `<text>` is the whole matched line, verbatim. `PRIMARY` is a
**label, not a filter**: a non-unique anchor still resolves on its first match,
and the extra `MATCH` rows are informational — they tell the citation's author the
anchor was less unique than intended, and they never change the outcome.

A miss is **fail-closed**, exactly like the section read: nothing on stdout, the
anchor and the file named on stderr, and a non-zero exit.

### Exit codes for `cite`

| Code | Meaning |
| --- | --- |
| `0` | at least one match — the anchor resolved |
| `1` | the anchor wasn't found, **or** the file is missing/unreadable, **or** the `resolve-citation` primitive couldn't be located |
| `2` | bad usage — not exactly two arguments, or an empty anchor (an empty string matches every line, so it's a usage error rather than a whole-file answer) |

`0`–`2` are the primitive's own codes, relayed. The **unlocatable-primitive** case
is folded into `1` deliberately: a caller asking "did this anchor resolve?" gets
the same answer either way, so a degraded install needs no special handling
anywhere downstream — the grounding is reported as unresolved and the run
continues (`.project/design-philosophy.md#Error & failure philosophy`).

## The output: one record per line

For `keys` and `docs`, both scripts emit a deterministic, TAB-separated record
stream — the same shape `milestone-driver`'s own scripts use. The caller parses it
once and distributes slices. (`cite` is the exception: it relays its primitive
verbatim and emits no records — see
["Resolving an anchor citation"](#resolving-an-anchor-citation-cite).) Records:

| Record | Meaning |
| --- | --- |
| `KEY <name> <value>` | one resolved shared-key value. An **array** key emits one `KEY` record per element, so arrays and scalars parse the same way. Each value is **exactly one record**, even when the underlying JSON value spans multiple lines or contains a TAB (see "Record-value encoding" below). |
| `SKIP key <name> <reason>` | a shared key that wasn't in the (valid) profile. |
| `SKIP section <doc>#<anchor> <reason>` | a section that was absent/unreadable, a lone-`[TBD]` placeholder, or empty. |
| `SECTION-BEGIN <doc> <anchor>` … body … `SECTION-END <doc> <anchor>` | a resolved doc section and its **verbatim** content — every line between the markers round-trips exactly as the driver primitive returned it, **including blank lines inside the body and any trailing blank lines** (see "Section-body trailing blank lines" below). |
| `SIGNAL no-config` | neither profile file exists — the caller should fall back to bounded repo greps. |
| `SIGNAL no-doc-grounding` | no docs root, no driver primitive, or nothing resolved — fall back to bounded greps and (per `BRIEF.md` l.96 / D17) nudge toward `milestone-bootstrapper`. |
| `ERROR malformed-config <file> <detail>` | a profile that exists but is invalid JSON. Surfaced (also to stderr), never silently skipped, never replaced with made-up values. |
| `SUMMARY keys=N sections=M skipped=K signals=S errors=E` | always the last line. |

### Record-value encoding (one value = one record)

A `KEY` value is always **exactly one record**, even when the source value
contains newlines **or tabs** — for example a multi-line `nonNegotiables` entry,
or a value that holds a literal TAB. Records are TAB-separated
(`KEY<TAB>name<TAB>value`), so a raw TAB or newline inside a value would
otherwise add spurious columns or split the value across lines. To prevent that,
the value is encoded with three substitutions, **in this exact order**:

| Step | Replace | With |
| --- | --- | --- |
| 1 | each backslash `\` | `\\` |
| 2 | each newline | the two characters `\n` |
| 3 | each TAB | the two characters `\t` |

Backslash is escaped **first** so the backslashes introduced in steps 2 and 3
are not themselves re-escaped. This extends `milestone-driver`'s
`ci-preflight-steps` encoding (which escaped only backslash and newline) with the
TAB case the TAB-separated record stream requires.

So a `nonNegotiables` element written in the config as:

```
must support:
  - macOS
  - Linux
```

is emitted as the single record `KEY<TAB>nonNegotiables<TAB>must support:\n  - macOS\n  - Linux`.

**The caller reverses the encoding in the opposite order**: first replace `\t`
with a real TAB, then `\n` with a real newline, then `\\` with a single `\`. (A
single left-to-right scan that consumes two characters per recognized escape is
equivalent and never re-interprets an escaped backslash.) This guarantees the
record count matches the real key/element count and that every value — including
one containing a TAB or ending in a newline — round-trips exactly.

This encoding applies only to `KEY` **values**. A resolved section body (between
`SECTION-BEGIN` and `SECTION-END`) is **not** encoded — it is streamed verbatim,
one source line per output line (see the section-body policy just below).

### Section-body trailing blank lines (verbatim policy)

A resolved section body is the **grounding payload**, so its content is preserved
**verbatim**: every line the `read-doc-section` primitive returns is emitted
unchanged — the heading, every interior blank line, **and every trailing blank
line**. A section body that ends in two blank lines emits two trailing blank
lines; one that ends in three emits three. Both scripts apply this identical
policy: the primitive ends its output with a single line-terminator, which each
script strips once before splitting into lines, so the two produce the same body
line set on every platform.

**Line endings are normalized to LF.** Every emitted body line ends in a single
`\n` (the line ending is LF, never CRLF), so a `.project/` doc authored on Windows
with CRLF (`\r\n`) line endings produces exactly the same bytes as the same doc
authored with LF — and the bash and PowerShell scripts agree byte-for-byte. The
content of each line is unchanged; only the trailing carriage return of a CRLF
line is dropped. (This matches how `KEY` values are read CR-free, so the whole
record stream is CR-free regardless of how the config or docs were authored.)

### Exit codes

These are the `keys` and `docs` codes; `cite` relays its primitive's instead (see
[Exit codes for `cite`](#exit-codes-for-cite)).

| Code | Meaning |
| --- | --- |
| `0` | ran successfully, **including** every clean-degradation case |
| `2` | bad usage (no/unknown subcommand, missing specs) |
| `3` | a malformed config was surfaced (the run continues; this lets the caller notice the `ERROR` record without parsing) |

## Degradation matrix (what happens when grounding is thin)

Absence is expected and handled; only a present-but-broken config is an error.

| Situation | Behavior |
| --- | --- |
| `.milestone-config/driver.json` present (happy path) | resolve the five keys from it, in place |
| `.milestone-config/driver.json` absent, root `milestone-driver.json` present | resolve the same keys from the root file (fallback) |
| both config files absent | no keys; `SIGNAL no-config`; exit 0 (caller greps) |
| a shared key not in the (valid) profile | `SKIP key …`; the other keys still resolve |
| malformed config JSON (present but invalid) | `ERROR malformed-config …` to stderr + record; exit 3; **no crash, no fabricated values** |
| `.project/` (or the docs root) absent entirely | no sections; `SIGNAL no-doc-grounding`; exit 0 |
| a cited section absent, empty, or a lone-`[TBD]` placeholder | `SKIP section …`; every other cited section still resolves (a section that only *mentions* `[TBD]` is real grounding and resolves) |
| the driver `read-doc-section` primitive can't be found | each section `SKIP …`; `SIGNAL no-doc-grounding`; exit 0 |
| `cite`: the anchor isn't in the file, or the file is missing/unreadable | nothing on stdout; the failing anchor and/or file named on stderr; exit 1 (fail-closed, relayed from the primitive) |
| `cite`: the driver `resolve-citation` primitive can't be found (no driver, or one older than v1.19.0) | nothing on stdout; the reason on stderr; exit 1 — the same answer as an anchor that didn't resolve, so the caller reports the grounding unresolved and continues; **no crash** |

## Resolve-once contract

Each key and each section is resolved a **single time per run**. These scripts do
the read; the orchestrator caches the result and hands downstream subagents only
their slice (an inline-fix re-dispatch gets one finding + its citation; a
large-drift handoff gets a tight brief) — no subagent re-reads the same
file/section (`BRIEF.md` l.35-40, l.114). Same DNA as the driver's resolve-once
block.

`cite` sits outside that count. It isn't a gather — it's a **verification** call
the orchestrator makes later, at most once per anchor-carrying finding, during
the grounding check (`docs/analyze-once.md` §"Tier 2 — one bounded live re-check
(only on a tier-1 miss)"). It caches nothing and resolves nothing for anyone
else.

## Dependency note

The config read uses `jq` (bash) or PowerShell's built-in `ConvertFrom-Json`
(pwsh). `jq` is the suite's already-permitted JSON tool — no new dependency is
introduced. The doc-section read and the anchor read both reuse the driver's
existing dependency-free primitives unchanged — `read-doc-section` and
`resolve-citation`, two scripts from the same already-required plugin, neither
copied and neither reimplemented.
