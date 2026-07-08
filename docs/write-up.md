# The write-up — the coherence reviewer's primary deliverable

The verdict is not the product. The **write-up** is. After the reviewer checks
whether a change fits how the app is already built, the thing a human actually
reads is a short, plain-English note: *what it did, why, the citations, and a
one-click way to redo it differently if you disagree* (`BRIEF.md`
§"Communication is the actual product" l.63-74; §"Recorded decisions" l.115).

This doc is the **write-up contract** — the shape of that note, where it lands,
and how it degrades. It is implemented by the standalone `review` skill (#7) and
rendered from the [review engine](../agents/coherence-reviewer.md)'s (#3)
`FINDINGS` **and** `PROPOSALS` blocks, distributed through the
[analyze-once](analyze-once.md) (#4) slices. The write-up **renders** from that
single consolidated analysis — it never re-greps the repo, re-reads a doc, or
re-derives a finding or a proposal (`BRIEF.md` l.35-40, l.114).

> Scope note. This doc **specifies** the write-up and its mirrors. It does not
> itself run `gh` or post comments — the `review` skill (#7) enacts the issue and
> PR mirrors via `gh ... comment`; this layer ships only the
> [memory-mirror helper](#the-memory-mirror-detect-or-fallback) the skill calls.

## What the write-up renders from (no re-derivation)

The write-up is built **entirely** from the engine's `FINDINGS` **and**
`PROPOSALS` blocks, handed across as the analyze-once analysis, refined by the
Step 2.5 verify pass (`docs/analyze-once.md` §"Verify grounding, drop what
fails"; issue #38) before either block reaches the renderer. Every per-finding
and per-proposal **content** field it shows — the fields in the table below —
is a field one of those blocks already carries; the renderer transforms, it
does not discover. Two elements describing the reviewed change are **not**
engine fields, each labeled as such wherever it appears — so the headline
invariant is honest, not contradicted below:

1. the orchestrator-created **config-only PR link** for a proposal — not an
   engine field but a live **orchestrator artifact** (the PR the orchestrator
   opened at `skills/review/SKILL.md` Step 3);
2. the **dropped-grounding count** — not an engine field either, but the Step
   2.5 verify pass's own tally of findings that failed both tiers (see
   [Dropped-grounding count](#dropped-grounding-count-from-the-step-25-verify-pass)
   below).

(This "content" scope excludes procedural status notes the write-up carries —
a skipped mirror note (covered below in [Graceful
degradation](#graceful-degradation--a-missing-mirror-never-blocks-the-headline)),
plus the D17 `milestone-bootstrapper` nudge, a closed-duplicate note, the
**recall status note** (the reference to matched prior write-ups, or the
explicit "no related prior write-ups found" — see [Recall
(read-back)](#recall-read-back--prior-write-ups-before-re-analysis) below), and
the deferred-boundary statement (each specified where the rendering skill emits
it — `skills/review/SKILL.md` Step 1, Step 3, Step 4, and Step 5,
respectively). These describe the run's own mechanics, not the reviewed change,
so they are outside this "content elements" scope, not additional
non-engine-field content claims.)

| Write-up element | Built from (engine `FINDINGS` field) |
| --- | --- |
| what it did / what diverges | each finding's `description` + `symbol` |
| why | the `lens` that fired (built-differently, fresh-vs-base, ignored-convention, duplicated-helper, hand-rolled-library, framework-best-practice) |
| the citations | each finding's single `grounding` ref (`.project/<doc>#<section>` \| `<path>:<line>` \| `domainSkills:<source>`) |
| how much drift | the `severity` hint (informs the redo one-liner's scope) |
| clean-fit headline | the `FINDINGS: none` sentinel + the `SOURCES` lines |
| the swept scope (sweep runs) | the top-level `REVIEWED` / `SOURCES.app-grep` **sweep** values → "scanned: broad" \| "scanned: pattern `<pattern>`" (`agents/coherence-reviewer.md` §"Sweep-mode") |

(The dropped-grounding count is deliberately **not** in this table — it is not
an engine `FINDINGS` field; see [Dropped-grounding count](#dropped-grounding-count-from-the-step-25-verify-pass)
below for what it renders from instead.)

The renderer adds no claim that is not backed by a field above. A finding the
engine dropped for lack of grounding (the hard-grounding rule) never appears in
the write-up — the write-up cannot manufacture grounding the engine refused to
emit. The same discipline governs the `PROPOSALS` block: the
[Proposed convention](#proposed-convention--rendered-from-the-proposals-block)
section renders **only** from that block's fields (plus the live PR link the
orchestrator opened for that proposal — a real artifact, not a fabricated
claim), and `PROPOSALS: none` renders **nothing** — never a false proposal.

For a **sweep** run the write-up also renders the **swept scope** — read from the
two sweep-valued top-level header fields (`REVIEWED: sweep:broad | sweep:<pattern>`
and/or `SOURCES.app-grep: swept-broad | swept-pattern:<pattern>`,
`agents/coherence-reviewer.md` §"Sweep-mode") — surfaced as **"scanned: broad"**
or **"scanned: pattern `<pattern>`"**. This is a **parallel case**, not a change
to the per-change render path: a per-change run carries the per-change
`REVIEWED` / `SOURCES.app-grep` values and renders no scanned-scope line. These
are engine fields, so the "renders only from engine fields" contract still holds —
the sweep header values now have a real documented consumer here (so the scope is
read, never invented).

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

## Proposed convention — rendered from the `PROPOSALS` block

Where the per-finding items above render the drift (`FINDINGS`), the write-up
**also** renders a **Proposed convention** section — one item per entry in the
engine's `PROPOSALS` block (`agents/coherence-reviewer.md` §"Convention
proposals"). It reports the rule the orchestrator opened as a config-only PR for
the human to accept (merge) or reject (close). A proposal is **not** a drift fix
and carries **no** redo one-liner — its "redo" is merging or closing the PR.

Per proposal, in order:

1. **The proposed heading** — the entry's `## <heading>`, shown verbatim (a
   stable citation anchor).
2. **The rule** — the one-line `rule` that becomes the `>` blockquote.
3. **The exemplar** — the `exemplar` `path:line` the entry cites.
4. **The diverging sites** — shown **only when `disagree: yes`**: the `diverging`
   `file:line` list (the sites differing from the recommended winner, surfaced,
   not auto-changed). Omitted entirely when `disagree: no`.
5. **The config-PR link** — a link to the config-only PR the orchestrator opened
   for this proposal (`skills/review/SKILL.md` Step 3), targeting
   `integrationBranch`. **Merge to accept, close to reject.**

| Write-up element | Built from (engine `PROPOSALS` field) |
| --- | --- |
| the proposed heading | each proposal's `heading` |
| the rule | the `rule` line |
| the exemplar | the `exemplar` `path:line` |
| the diverging sites (only when `disagree: yes`) | the `diverging` `file:line` list |
| the config-PR link | the PR the orchestrator opened for this proposal (not an engine field — a live artifact) |

`PROPOSALS: none` renders **no Proposed convention section at all** — no false
proposal, exactly as `FINDINGS: none` renders no per-finding items. The renderer
never manufactures a proposal the engine did not emit, and a proposal the engine
dropped for lack of grounding never appears here.

## Dropped-grounding count (from the Step 2.5 verify pass)

Where the sections above render **from** the engine's blocks, this one renders
from the orchestrator's own **Step 2.5 verify pass** (`docs/analyze-once.md`
§"Verify grounding, drop what fails"; issue #38) — the mechanical check, run in
both `skills/review/SKILL.md` and `skills/sweep/SKILL.md` immediately after
their engine dispatch, that drops any finding whose `grounding` fails both the
cache-only tier-1 check and the one bounded tier-2 live re-check.

- **When the run's tally is greater than zero**, the write-up states it
  verbatim, exactly once, as:

  ```
  N findings dropped: grounding did not resolve
  ```

  — `N` is the run's total drop count (summed across every sub-path on a
  checkpointed broad `sweep`, via `accumulated.droppedCount`). This line is a
  **caught-hallucination signal**, not a defect report — it means the verify
  pass worked, not that something is wrong with the run.
- **When the tally is zero** (including the `FINDINGS: none` clean-fit case,
  which skips the verify pass entirely — `docs/analyze-once.md` §"Empty
  state"), the write-up renders **no** drop-count line at all — never "0
  findings dropped".
- A dropped finding never appears anywhere else in the write-up — not as a
  per-finding item, not in a mirror. It is counted, not described; describing a
  dropped finding would mean citing the very grounding that failed to resolve.

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
- For a **sweep** run the clean-fit headline additionally states **what was
  scanned** — the swept scope, "scanned: broad" or "scanned: pattern
  `<pattern>`", read from the sweep-valued `REVIEWED` / `SOURCES.app-grep` header
  fields (`agents/coherence-reviewer.md` §"Sweep-mode"). This is the render
  contract the sweep's empty-state reuses to surface "what was scanned"
  (`skills/sweep/SKILL.md` §"Empty state") — a parallel case; the per-change
  clean-fit headline is unchanged.
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

## Recall (read-back) — prior write-ups before re-analysis

Symmetric to the write path above, the `review` flow also **reads back** prior
write-ups before re-analysis — so a re-review of a change that touches the same
code sees what an earlier run already said about it. Recall is the read half of
the memory mirror, reading back from that same supplemental audit-trail store
(`BRIEF.md` §"Communication is the actual product" l.68; §"Recorded decisions"
l.115 — the inline write-up is the deliverable, memory is the audit trail); this
section is its contract.

### Where recall attaches, and how it matches

**Recall runs orchestrator-side**, at the start of the `review` skill's flow —
the `review` path **only** (see [the deferred
boundary](#the-deferred-boundary--sweep-recall-not-built-here) below) — gathered
**once** as part of the review context the orchestrator assembles, never
re-derived downstream (`BRIEF.md` §"Analyze once, then distribute (token
efficiency)" l.33; §"Recorded decisions" l.114). Its results are **handed to**
the read-only [coherence-reviewer](../agents/coherence-reviewer.md) engine as
additional **advisory context**; the engine itself runs no recall script and
keeps its read-only contract (`.project/design-philosophy.md#Layering &
boundaries` l.18 — the read-only-engine ↔ orchestrator-acts split;
`agents/coherence-reviewer.md` §"Read-only — what you produce and what you never
do" l.72).

Recall reads from the **same detect-or-fallback target the write path resolves** —
`scripts/memory-mirror.sh` `resolve_target()` (l.102-139: the four legs —
vault-env → vault-repo → claude-mem → the git-invisible fallback under
`.milestone-config/.runtime/`). Read and write resolve **identically**, so recall
always reads where the mirror wrote. It parses each prior entry's recorded
`grounding` citation in the `<path>:<line>` form (the [What the write-up renders
from](#what-the-write-up-renders-from-no-re-derivation) table, l.56) — from entry
**bodies**, not headers — and surfaces any entry whose cited path intersects the
**current diff's touched paths**. This is a **diff-keyed match**: flat cost, keyed
only to what the change touches — the same bound the per-change review's own greps
use (`.project/design-philosophy.md#What we optimize for` l.22).

### The empty-match and fail-soft cases — never silence

A resolvable, readable store that holds **no** entry touching the diff's paths
renders an explicit **"no related prior write-ups found"** note — never silence
(mirroring [The empty / clean-fit state — never
silence](#the-empty--clean-fit-state--never-silence) l.219-224: absence is an
explicit statement, never an absent output).

Every thin-store failure degrades to that **same** note — the [resolution
degradation-matrix](resolution.md#degradation-matrix-what-happens-when-grounding-is-thin)
pattern (l.200-213): never a crash, never a block on the review or the merge
(`.project/design-philosophy.md#Error & failure philosophy` l.35 — fail-soft /
absence-means-skip; "Coherence heals; it never gates").

| Situation | Behavior |
| --- | --- |
| **Absent store** — no resolvable or readable target file | render "no prior write-ups found"; continue |
| **Empty store** — target resolves but holds no entries | render "no prior write-ups found"; continue |
| **Unreadable or corrupt store** — target resolves but does not parse | render "no prior write-ups found"; continue |

All three rows are #69's `--recall` **exit-0 empty-state** — the `NONE` sentinel
plus `SUMMARY entries=0` on stdout (`scripts/memory-mirror.sh:61-64`) — a
store that is absent/empty/unreadable is **not** a failure. A **genuine
invocation failure** (a *nonzero* exit — a missing script/binary, a
host-detection failure, or the exit-2 bad-usage case) is the separate fail-soft
case: the orchestrator notes recall is unavailable and proceeds from scratch,
also never a crash and never a merge block (`skills/review/SKILL.md` Step 2,
item 2's failure state).

### Advisory, never gates — stated both ways

A matched prior write-up is **context only**, never a verdict input:

- **It never alters the review.** It does not change the engine's `FINDINGS` /
  `PROPOSALS` blocks and never blocks the merge (`BRIEF.md` §"It heals, it
  doesn't gate" l.42-52; `.project/design-philosophy.md#Error & failure
  philosophy` "Coherence heals; it never gates"; `docs/heal-routing.md` l.9-12).
- **It is never fed to the router.** A recall match is **not** an input to the
  `severity`-keyed heal-routing decision — it joins the same excluded class as
  heal-routing's "Tempting input" table (`BRIEF.md` §"Recorded decisions" l.109 —
  heals, never gates, routes by drift size only; `docs/heal-routing.md` §"The
  single routing key — drift size, nothing else" l.25-39). Recall informs the
  reader; it never moves where a fix lands.

### The deferred boundary — sweep recall (NOT built here)

This contract covers the **`review` flow's** recall only. **Sweep-mode recall is
NOT built in this milestone** (mirroring `docs/heal-routing.md` §"The deferred
boundary" l.266-292). A sweep run receives a **sweep context, not a diff**
(`agents/coherence-reviewer.md` l.130), so the diff-keyed match above is
**undefined** there — a future sweep hookup would need its own match-key
decision. Documented, not implemented.

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
- It **renders** from the engine's `FINDINGS` **and** `PROPOSALS` blocks via the
  analyze-once slices — it never re-greps, re-reads a doc, or re-derives a
  finding or a proposal.
- **Dropped-grounding count**: when the Step 2.5 verify pass's tally
  (`docs/analyze-once.md` §"Verify grounding, drop what fails") is greater than
  zero, states "N findings dropped: grounding did not resolve" verbatim;
  renders nothing when the tally is zero (including `FINDINGS: none`, which
  skips the pass entirely).
- **Proposed convention**: one item per `PROPOSALS` entry — heading · rule ·
  exemplar · diverging sites (only when `disagree: yes`) · a link to the
  config-only PR the orchestrator opened. `PROPOSALS: none` renders nothing —
  never a false proposal.
- **Per coherence call**, each item is: what it did · why · the citations · a
  copy-paste `gh issue create --repo … --title … --body …` redo one-liner —
  matching `BRIEF.md` l.72 verbatim.
- **Four landing places, two tiers**: the inline summary is PRIMARY; memory, the
  issue comment, and the PR comment are supplemental audit-trail copies of the
  same content.
- **Empty state**: zero findings still produces a "fits cleanly — nothing
  changed" headline — never silence; a **sweep** run's headline additionally
  states the swept scope ("scanned: broad" \| "scanned: pattern `<pattern>`", read
  from the sweep-valued `REVIEWED` / `SOURCES.app-grep` header fields).
- **Tight**: concise, flat, no wall-of-text; flat-cost as findings fan out.
- **Graceful degradation**: an unavailable mirror is skipped and noted; it never
  suppresses the primary inline summary.
- The **memory mirror** is detect-or-fallback (conservative detect of an
  opted-in store → else a git-invisible file under `.milestone-config/.runtime/`),
  supplemental and best-effort.
- **Recall (read-back)**: the `review` flow reads back prior write-ups from that
  same detect-or-fallback target before re-analysis, **diff-keyed** to the touched
  paths, and hands matches to the engine as **advisory context** — never a
  `FINDINGS`/`PROPOSALS` or routing input, never a merge block; an absent, empty,
  or unreadable store degrades to an explicit "no prior write-ups found".
  Sweep-mode recall is not built here.
