# Analyze once, then distribute — the orchestration contract

The [resolution layer](resolution.md) gathers the *inputs* once: the shared keys
and the cited `.project/` sections, read a single time and handed downstream as
ready-to-use slices. This doc is the other half of the same pattern — it gathers
the *analysis* once and distributes it the same way.

Concretely: the orchestrator runs the expensive review work **exactly once per
review call**, then hands each downstream subagent only the small, self-contained
slice it needs — never the whole analysis, never the raw `.project/` sections,
never a raw repo dump, and never a "go re-read it yourself". Same DNA as the
driver's resolve-once block (`BRIEF.md` §"Analyze once, then distribute (token
efficiency)", l.33-40; §"Recorded decisions" l.114). Gather once, distribute
slices.

This doc specifies the **distribution mechanism only**. It is the contract the
standalone `review` skill (#7) implements, and that the write-up format (#5) and
the heal routing (#6) consume. It does not itself act — see
[Read-only engine, orchestrator acts](#read-only-engine-orchestrator-acts).

## The two halves of "once"

| Half | Who does it | Where it's specified |
| --- | --- | --- |
| Gather the **inputs** once (shared keys + `.project/` sections) | `scripts/resolve-config.{sh,ps1}` | [resolution.md](resolution.md) |
| Produce the **analysis** once, then distribute slices | the orchestrator (the `review` skill, #7) | this doc |

The first half feeds the second: the resolved keys and sections are part of the
review context the orchestrator assembles before it runs the analysis.

## Step 1 — Gather the review context (once)

The orchestrator assembles the review context a **single time** per review call.
It has four parts, and none of them is re-read, re-resolved, or re-derived after
this point (`BRIEF.md` l.35):

| Part | Source | Resolved by |
| --- | --- | --- |
| **The built diff** | the branch / PR under review, against `integrationBranch` | the orchestrator |
| **The resolved `.project/` sections** | the cited `conventions.md` / `design-system.md` / `library-manifest.md` / `design-philosophy.md` sections, verbatim | `resolve-config.{sh,ps1} docs …` (issue #2) — read once |
| **The `domainSkills` pointers** | the stack's best-practice sources from the driver profile | `resolve-config.{sh,ps1} keys …` (issue #2) — read once |
| **The bounded, diff-keyed grep results** | greps within `sourceGlobs` for the specific symbols the diff introduces — never a whole-repo scan | the orchestrator (diff-keyed) |

This is the **same** review context the #3 engine documents under "What you
receive" — the orchestrator builds it and hands it to the engine; the engine does
not re-read whole docs or re-resolve the shared keys.

## Step 2 — Produce the consolidated analysis (once)

The orchestrator dispatches the read-only review engine (#3,
`agents/coherence-reviewer.md`) **once** against that context. The engine returns
its structured `FINDINGS` block — that block **is** the consolidated analysis.
Nothing in this layer re-runs it, augments it from raw sources, or asks a second
subagent to re-derive any part of it.

The consolidated analysis is exactly the engine's return block. Its fields (from
`agents/coherence-reviewer.md`, "Structured return block") are the only material
the slices below are built from:

| Field | Scope | Meaning |
| --- | --- | --- |
| `REVIEWED` | top-level | the branch / PR / diff-ref that was reviewed |
| `SOURCES.app-grep` | top-level | `ran` or `skipped-no-source-paths` |
| `SOURCES.project-docs` | top-level | `<N sections>` or `none` |
| `SOURCES.domain-skills` | top-level | `<N sources>` or `none` |
| `symbol` | per finding | the diff symbol/pattern the finding is keyed to |
| `lens` | per finding | which senior-review lens fired (`built-differently`, `fresh-vs-base`, `ignored-convention`, `duplicated-helper`, `hand-rolled-library`, `framework-best-practice`) |
| `grounding` | per finding | **exactly one** ref — `.project/<doc>#<section>` \| `<path>:<line>` \| `domainSkills:<source>` |
| `severity` | per finding | the drift-size hint — `drift-trivial` \| `drift-small` \| `drift-medium` \| `drift-large` |
| `description` | per finding | one plain-English line: what diverges and from what |

The `FINDINGS: none` sentinel (the literal inline scalar) is the engine's
clean-fit outcome and is handled as the [zero-findings terminal](#zero-findings--a-clean-terminal)
below.

## Step 3 — Distribute minimal, self-contained slices

From that single analysis the orchestrator derives one slice per downstream
dispatch. A slice is **route-specific and minimal**: it carries only what its
consumer needs, and it must be **self-contained** — the consumer never re-reads a
doc, re-greps the repo, or re-derives a finding (`BRIEF.md` l.35-38). The slice
shape is fixed per route.

### The inline-fix slice (to the implementer re-dispatch)

When a finding routes inline (the trivial bucket — re-dispatch the implementer to
fix it before the PR merges), the slice is exactly:

```
{ the one finding, its grounding citation, the exact file scope }
```

— and **nothing else**. Not the whole analysis, not the other findings, not the
raw `.project/` sections, not the grep dump.

Field by field, derived from the consolidated analysis:

| Slice element | Built from | Notes |
| --- | --- | --- |
| **the one finding** | that finding's `symbol` + `lens` + `description` (+ its `severity` for the route decision) | one finding, not the list |
| **its grounding citation** | that finding's `grounding` (the single ref) | carried verbatim — the implementer cites it, never re-derives it |
| **the exact file scope** | derived by the orchestrator from the finding's `symbol` and `grounding` against the diff | the precise path(s)/region the fix may touch — see [file scope is orchestrator-derived](#file-scope-is-orchestrator-derived) |

This mirrors `/code-review`'s in-scope loop: one scoped, grounded ask to the
implementer, who already has the citation in hand.

### The large-drift slice (handoff to `milestone-feeder`)

When drift is large (handed to `milestone-feeder`, which plans + builds the
follow-up milestone), the slice is a **tight adjustments brief** — the synthesis
of the relevant finding(s) into a short statement of *what to adjust and why,
with citations*. Not the raw repo dump, not the raw `.project/` sections, not the
full analysis.

| Slice element | Built from | Notes |
| --- | --- | --- |
| **the adjustments** | the relevant finding(s)' `description` + `symbol`, synthesized into a short brief | the *what to change*, in the feeder's brief shape (a brief, like `BRIEF.md` itself) — never the diff or repo contents |
| **the grounding** | those finding(s)' `grounding` refs | so the follow-up issues stay hard-grounded without re-deriving |
| **the scope of the drift** | the `lens` + `severity` of the contributing finding(s) | tells the feeder this is a structural/multi-file adjustment, not a one-liner |

The feeder receives a brief on the same footing as any other brief it plans from
— it runs its own triage gate and authors well-formed issues. Coherence never
hand-authors the milestone (`BRIEF.md` §"It heals, it doesn't gate" l.48); it
hands the feeder a brief and the feeder does the rest.

> The small/medium bucket (current-milestone issues) is the heal-routing layer's
> concern (#6). This doc defines the two slice **shapes** the brief calls out
> explicitly — the inline-fix slice and the large-drift slice. The routing
> decision (which finding takes which route, keyed off `severity`) belongs to #6;
> this doc guarantees that **whatever** route a finding takes, the slice handed
> across is the minimal, self-contained one for that route.

## Self-contained or it doesn't ship

A slice that would require its consumer to re-read a doc, re-grep the repo, or
re-derive a finding from raw sources is **under-specified** — and an
under-specified slice is an **orchestration error**, not something shipped
(`BRIEF.md` l.35; issue #4 acceptance criteria, "Error/failure path").

Before a slice is dispatched, it must satisfy the route's shape:

| Route | A complete slice carries | Reject and treat as an orchestration error when |
| --- | --- | --- |
| inline-fix | the one finding **+** its single grounding citation **+** the exact file scope | the grounding ref is missing, or the file scope is empty/unknown — anything that would force the implementer to re-grep or re-derive |
| large-drift | the adjustments brief **+** the grounding refs **+** the drift scope | the brief is just a pointer back to "the analysis", or it carries no citation, or it inlines the raw repo/diff instead of a brief |

The check is mechanical against the slice shape: every required element is present
and concrete, or the slice does not go out. The orchestrator does **not** quietly
dispatch a thin slice that pushes re-derivation onto the subagent — it surfaces
the gap as its own error. (This is the distribution-side mirror of the engine's
own hard-grounding rule: the engine drops a finding it can't ground; the
orchestrator refuses to ship a slice it can't make self-contained.)

## Build-once invariant under fan-out

The consolidated analysis is produced **exactly once per review call**, no matter
how many findings it contains or how many downstream dispatches are derived from
it (`BRIEF.md` l.114, "keeps token cost flat as findings fan out").

- **N findings, M dispatches, one analysis.** The engine (#3) is dispatched once.
  Whether it returns zero findings or twenty, and whether those route into one
  inline fix or several inline fixes plus a feeder handoff, the analysis is built
  a single time. M slices are *derived from* that one artifact — they never
  re-run it.
- **Per-slice content does not grow with the total finding count.** An inline-fix
  slice is always `{ one finding + one citation + one file scope }` — its size is
  set by *its* finding, not by how many other findings exist. A large-drift slice
  is a brief of *its* adjustments, not a concatenation of every finding. So the
  cost of each slice is flat as the finding count rises; only the *number* of
  slices tracks the number of routed findings, and each stays minimal.
- **No re-gather, no re-analyze, no re-resolve.** No downstream dispatch triggers
  another context build, another engine run, or another `.project/` resolution.
  The resolve-once inputs (resolution.md) and the analyze-once output (this doc)
  are each read/produced one time and then only sliced.

This is what keeps token cost flat as findings fan out — the whole point of the
pattern.

## Zero-findings — a clean terminal

When the analysis yields `FINDINGS: none` (the engine's clean-fit sentinel),
there is **nothing to distribute**:

- No slices are derived.
- No downstream subagent is dispatched.
- The review call ends.

This is a **valid, non-error terminal outcome** — the change fits how the app is
already built, so there is no drift to route (`BRIEF.md` §"degrade cleanly" l.89;
issue #4 acceptance criteria, "Empty state — zero findings"). It is never an
error and never a failure; it is the success case where nothing needs healing.
Consistent with the suite's absent-means-skip / clean-degradation convention and
with the engine's own `FINDINGS: none` being a positive check, not a gap.

Note the distinction from a thin-grounding run: `FINDINGS: none` with degraded
`SOURCES` lines (e.g. `project-docs: none`) is still a clean terminal — the
orchestrator distributes nothing either way. `SOURCES` only tells the caller
*how much grounding was available*, so it can read the empty result correctly; it
does not change the terminal outcome.

## Read-only engine, orchestrator acts

The consolidated analysis is produced by the **read-only review engine** (#3): it
returns findings + grounding and does nothing else — it heals nothing, writes no
files, opens no issues, runs no `gh` (`BRIEF.md` §"Recorded decisions" l.113).

The **heal action** — re-dispatching the implementer for an inline fix, opening
issues, handing the feeder a brief — is performed by the **orchestrator** (the
`review` skill, #7, or the driver in the embedded path), *not* by a read-only
subagent. This doc specifies the **distribution mechanism** that sits between the
two: how the one analysis becomes the minimal slices the orchestrator's heal
actions consume. The mechanism itself does not act — it shapes and validates
slices; #6 routes them and #7 dispatches the heal.

This keeps the same read-only-agent / orchestrator-acts split the rest of the
suite uses (triage / design-reviewer / implementer stay read-only; the driver
acts).

## Notes on the derivations

### File scope is orchestrator-derived

The inline-fix slice's **exact file scope** is *not* a field in the #3 `FINDINGS`
block. The engine returns the finding's `symbol` (the diff symbol it's keyed to)
and its `grounding` ref; the orchestrator derives the precise file scope from
those two against the diff it already holds — the path(s) and region the
implementer may touch to fix *this* finding. This derivation is the orchestrator's
judgment, made once when the slice is built, from material already in hand (the
diff + the finding) — never by re-grepping or re-reading at the consumer.

### Why there is no slice-extraction script

Slicing is **orchestrator judgment, not a mechanizable text transform**, so this
layer ships **no `make-slice` script** (and least-code says don't add one):

- The two judgment-bearing slice elements — the inline-fix **file scope** and the
  large-drift **adjustments brief** — are *synthesized* from the finding against
  the diff and the feeder's brief shape, not extracted verbatim from a field. A
  script can't make those calls; it would either do nothing useful (pass the
  already-structured fields through) or attempt the judgment and get it wrong.
- The mechanical part — selecting a finding's fields out of the engine's block —
  is a trivial parse the orchestrator already does to read the block at all;
  wrapping it in a script adds an indirection layer without removing any
  duplication.

So the contract is enforced by the orchestrator reading the block and shaping each
slice to the route's fixed shape, validated against the
[self-contained check](#self-contained-or-it-doesnt-ship) — no script in between.

## Analyze-once contract (summary)

- The review **context** (diff + resolved `.project/` sections + `domainSkills`
  pointers + diff-keyed greps) is assembled **once** per review call.
- The consolidated **analysis** (the #3 engine's `FINDINGS` block) is produced
  **once** per review call — regardless of N findings or M dispatches.
- Each downstream dispatch gets a **minimal, self-contained slice** derived from
  that single analysis: inline-fix = `{ finding + citation + file scope }`;
  large-drift = a tight adjustments brief. Never the whole analysis, the raw
  `.project/` sections, or a raw repo dump.
- An **under-specified slice** (one that would force the consumer to re-read,
  re-grep, or re-derive) is an **orchestration error**, not shipped.
- **`FINDINGS: none`** → nothing to distribute → no slices, no dispatch → a valid
  clean terminal.
- The analysis is produced by the **read-only engine**; the **orchestrator** acts
  on the slices. This doc defines the distribution mechanism; it does not act.

Same DNA as the driver's resolve-once block, and as this repo's own
[resolution layer](resolution.md): gather once, distribute slices, keep token
cost flat under fan-out.
