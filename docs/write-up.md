# The write-up — the coherence reviewer's primary deliverable

The verdict is not the product. The **write-up** is. After the reviewer checks
whether a change fits how the app is already built, the thing a human actually
reads is a short, plain-English note: *what it did, why, the citations, and a
one-click way to redo it differently if you disagree* (`BRIEF.md`
§"Communication is the actual product" l.63-74; §"Recorded decisions" l.115).

This doc is the **write-up contract** — the shape of that note, where it lands,
and how it degrades. It is implemented by the standalone `review` skill (#7) and
rendered from the [review engine](../agents/coherence-reviewer.md)'s (#3)
`FINDINGS` block, distributed through the
[analyze-once](analyze-once.md) (#4) slices. The write-up **renders** from that
single consolidated analysis — it never re-greps the repo, re-reads a doc, or
re-derives a finding (`BRIEF.md` l.35-40, l.114).

> Scope note. This doc **specifies** the write-up and its mirrors. It does not
> itself run `gh` or post comments — the `review` skill (#7) enacts the issue and
> PR mirrors via `gh ... comment`; this layer ships only the
> [memory-mirror helper](#the-memory-mirror-detect-or-fallback) the skill calls.

## What the write-up renders from (no re-derivation)

The write-up is built **entirely** from the engine's `FINDINGS` block, handed
across as the analyze-once analysis. Every field it shows is a field that block
already carries — the renderer transforms, it does not discover.

| Write-up element | Built from (engine `FINDINGS` field) |
| --- | --- |
| what it did / what diverges | each finding's `description` + `symbol` |
| why | the `lens` that fired (built-differently, fresh-vs-base, ignored-convention, duplicated-helper, hand-rolled-library, framework-best-practice) |
| the citations | each finding's single `grounding` ref (`.project/<doc>#<section>` \| `<path>:<line>` \| `domainSkills:<source>`) |
| how much drift | the `severity` hint (informs the redo one-liner's scope) |
| clean-fit headline | the `FINDINGS: none` sentinel + the `SOURCES` lines |

The renderer adds no claim that is not backed by a field above. A finding the
engine dropped for lack of grounding (the hard-grounding rule) never appears in
the write-up — the write-up cannot manufacture grounding the engine refused to
emit.

## The shape, per coherence call

Per coherence call, in layman's terms: **what it did, why, the citations, and a
ready `gh` one-liner** to spin up an issue if you'd rather do it differently.
Mirror the brief's worked example exactly (`BRIEF.md` l.72) — this is the
template, not an example to paraphrase:

> Implemented the responsive mobile nav as a hamburger menu. Instead of
> hand-rolling it, I used `<library>` — here's why and the docs I used:
> `<citations>`. Prefer a different approach?
> `gh issue create --repo <repo> --title "Revisit mobile nav implementation" --body "<scoped ask>"`

So each rendered item carries, in order:

1. **What it did** — one plain sentence naming the change, from the finding's
   `description` + `symbol`. ("Built `ContactsExportService` to open its own DB
   connection.")
2. **Why** — the reason, from the `lens`. ("…instead of the shared unit-of-work
   the other services inject.")
3. **The citations** — the finding's single `grounding` ref, shown verbatim as
   the engine emitted it. Never a paraphrase, never an added "feels off" claim.
4. **The redo one-liner** — a copy-paste-ready `gh issue create` scoped to *this*
   change (below).

### The `gh issue create` redo one-liner

Reuse the suite's established issue-create primitive — the same one the feeder
uses to write issues (convention: `milestone-feeder/skills/create/SKILL.md:182`,
`gh issue create --title … --body …`). Render it copy-paste-ready and scoped to
the specific change it would redo:

```
gh issue create --repo <repo> --title "<imperative revisit title>" --body "<scoped ask>"
```

| Part | Filled from |
| --- | --- |
| `--repo <repo>` | the repo under review (the `owner/name` slug the orchestrator already holds) |
| `--title "<imperative revisit title>"` | an imperative "Revisit …" title naming the change ("Revisit ContactsExportService DB connection") |
| `--body "<scoped ask>"` | a scoped ask: what to do differently + the finding's `grounding` ref, so the new issue starts grounded |

The one-liner is **per finding** — it redoes *that* divergence, not the whole
review. Quote the title and body so the line pastes and runs as-is.

## Four landing places, two tiers (not equal)

The same write-up content lands in four places, but they are **not** equal
(`BRIEF.md` l.65-68, l.115):

| Place | Tier | How it's written |
| --- | --- | --- |
| **Inline summary** | **PRIMARY** — the un-buried headline a human reads | returned inline by the `review` skill; always produced |
| Memory | supplemental — audit trail | the [memory-mirror helper](#the-memory-mirror-detect-or-fallback) |
| The relevant issue comment | supplemental — audit trail | `gh issue comment <n> --body "<write-up>"` |
| The related PR comment | supplemental — audit trail | `gh pr comment <pr> --body "<write-up>"` |

- **The inline summary is the deliverable.** It is laid out so it is obviously
  worth reading and *not buried* — the headline, never a footnote. This is the
  thing the human actually reads (`BRIEF.md` l.67).
- **Memory, the issue comment, and the PR comment are the supplemental audit
  trail** (CYA for later). They are *copies* of the same write-up — never its
  canonical home (`BRIEF.md` l.68, l.115 "Inline write-up is the deliverable;
  issue/PR/memory are the audit trail").

The hierarchy is an invariant: the inline summary is always rendered as the
primary copy, and the three mirrors are always rendered as supplemental copies of
*that same content* — never the other way round. (Convention for the comment
write surface: `milestone-driver/skills/triage/SKILL.md:292`
`gh issue comment <n> --body "…"`; `milestone-driver/skills/solve-issue/SKILL.md:234`
`gh pr comment <pr>`.)

## The empty / clean-fit state — never silence

A change that fits with **zero findings** (`FINDINGS: none`) still produces a
write-up. It reports the positive outcome explicitly — e.g. **"Fits cleanly —
nothing changed"** — and is never silence or an empty output (`BRIEF.md` l.23,
l.141 "what fits, what doesn't").

- The headline is produced exactly as in the finding case: the inline summary is
  primary, the three mirrors are supplemental copies of the clean-fit note.
- There are **no per-finding items and no redo one-liners** — there is nothing to
  redo. The clean-fit write-up states what was checked (read from the `SOURCES`
  lines: which of app-grep / project-docs / domain-skills were available) so the
  reader can tell a genuine clean fit from a thin-grounding run.
- Absence of findings is an **explicit statement**, never an absent output. The
  reviewer reports both halves — what fits and what doesn't.

## Tight and legible — over-explaining is rejected

The whole point of this tool is legible, un-buried communication, so the write-up
is held **tight** (`BRIEF.md` l.74, l.129-130):

- Concise and flat — no wall-of-text, no preamble, no congratulatory notes. It
  follows the suite's terse output norm (convention:
  `milestone-driver/docs/architecture.md:174-176` concise/tabular output;
  `milestone-feeder/agents/issue-author.md:113-115` "Terse, evidence-grounded,
  flat").
- One short item per finding — what / why / citation / one-liner — not an essay
  per finding. **Over-explaining defeats the tool** and is rejected.
- The output **does not balloon as findings fan out**. Each item's size is set by
  *its* finding, not by the total count — the same flat-cost property the
  analyze-once slices guarantee (`analyze-once.md` "Per-slice content does not
  grow with the total finding count"). Many findings means more short items, not
  longer ones.

## Graceful degradation — a missing mirror never blocks the headline

A supplemental mirror whose target is unavailable is **skipped, noted, and never
allowed to suppress the primary inline summary** (`BRIEF.md` l.89, l.96; the
suite's absent-means-skip convention — `milestone-driver/docs/profile-schema.md:103`,
`milestone-feeder/skills/plan/SKILL.md:166` "Degrade gracefully: a missing … is
not an error").

| Unavailable target | Behavior |
| --- | --- |
| No PR exists yet | skip the PR-comment mirror; note "PR mirror skipped — no PR"; continue |
| No resolvable issue context | skip the issue-comment mirror; note the skip; continue |
| A `gh ... comment` write fails (auth, network, permissions) | skip that one mirror; note the failure; continue |
| The memory write fails | skip the memory mirror; note the failure; continue (see the helper's best-effort rule) |

In every case **only the unavailable mirror is skipped** — the inline summary and
every other reachable mirror are still produced. A failed mirror is reported, not
raised; it never errors the run and never blocks the merge (coherence heals, it
does not gate).

## The memory mirror (detect-or-fallback)

The memory mirror is **supplemental and best-effort**, written by the helper this
layer ships — `scripts/memory-mirror.{sh,ps1}`. Its target is resolved by the
**detect-or-fallback** design (RESOLVED, user decision 2026-06-23; issue #5
Design):

### Conservative detection (never guess-and-write)

The helper makes a best-effort, **conservative** attempt to detect the user's
*already-configured* memory convention, checking in this order. It writes only
into a location the user has **opted into** — it never guesses-and-writes into a
location the user has not configured:

| Order | Detect | Opted-in signal required |
| --- | --- | --- |
| 1 | An Obsidian vault via `NPM_CLAUDE_VAULT_ROOT` | the env var is set **and** a `Claude Memory/MEMORY.md` already exists under it |
| 2 | An Obsidian vault in the repo | a `.obsidian/` directory exists at the repo root |
| 3 | Claude Code's project memory store | an `autoMemoryDirectory` setting in a `.claude/settings*.json` file |

The "already exists / already configured" requirement is the conservative guard:
the presence of a configured store is the user's opt-in. A bare env var with no
existing memory file, or no `.obsidian/`, or no `autoMemoryDirectory`, is **not**
treated as opt-in — the helper falls back instead of writing somewhere the user
never set up.

### Fallback (git-invisible, in-repo)

When **none** of the three is detected, the helper falls back to a
**git-invisible** `.md` file under `.milestone-config/.runtime/` (e.g.
`coherence-memory.md`):

- `.milestone-config/.runtime/` is **already** git-invisible — the nested
  `.milestone-config/.gitignore` lists `.runtime/`, so anything under it stays out
  of `git status` with zero user setup. The fallback relies on that existing
  rule; it adds **no** new ignore line.
- The fallback must live **under `.runtime/`**, not at `.milestone-config/*.md` —
  a top-level `.milestone-config/*.md` is **not** ignored (only the tracked
  config and the explicitly-listed scratch entries are), so it would show up in
  `git status`. The helper creates `.milestone-config/.runtime/` if it is absent.

### Best-effort — a write failure follows the mirror rule

The memory mirror stays supplemental: a write failure is **reported and never
crashes the caller** — it follows the same mirror-unavailable rule above and never
suppresses the inline summary. (`BRIEF.md` l.68; memory-as-audit-trail grounded in
`BRIEF.md` l.68, l.115.)

## Discovery — how a user first meets the write-up

On the first release a user encounters the write-up by running the standalone
entry and reading the inline summary it returns (`BRIEF.md` l.78; `README.md`
l.9-11):

```
/milestone-coherence-reviewer:review <branch-or-PR>
```

No prior setup beyond the suite is required. This is a greenfield first release —
there are no existing users to migrate. The inline summary is what they read; the
mirrors accrue quietly as the audit trail.

## Write-up contract (summary)

- The write-up is the **primary deliverable** — not the verdict (`BRIEF.md` l.23,
  l.115).
- It **renders** from the engine's single `FINDINGS` block via the analyze-once
  slices — it never re-greps, re-reads a doc, or re-derives a finding.
- **Per coherence call**, each item is: what it did · why · the citations · a
  copy-paste `gh issue create --repo … --title … --body …` redo one-liner —
  matching `BRIEF.md` l.72 verbatim.
- **Four landing places, two tiers**: the inline summary is PRIMARY; memory, the
  issue comment, and the PR comment are supplemental audit-trail copies of the
  same content.
- **Empty state**: zero findings still produces a "fits cleanly — nothing
  changed" headline — never silence.
- **Tight**: concise, flat, no wall-of-text; flat-cost as findings fan out.
- **Graceful degradation**: an unavailable mirror is skipped and noted; it never
  suppresses the primary inline summary.
- The **memory mirror** is detect-or-fallback (conservative detect of an
  opted-in store → else a git-invisible file under `.milestone-config/.runtime/`),
  supplemental and best-effort.
