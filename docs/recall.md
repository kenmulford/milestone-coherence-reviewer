# Recall (read-back) — prior write-ups before re-analysis

Symmetric to the [write-up](write-up.md), the `review` flow **reads back** prior
coherence write-ups before re-analysis — so a re-review of a change that touches
the same code sees what an earlier run already said about it. Recall is the read
half of the memory mirror, reading back from that same supplemental audit-trail
store (`BRIEF.md` §"Communication is the actual product" l.68; §"Recorded
decisions" l.115 — the inline write-up is the deliverable, memory is the audit
trail).

This doc is the **single source of truth for recall** — its Step-2 gather
mechanics, its Step-4 render mechanics, and the contract that binds them. It
mirrors how [heal-routing](heal-routing.md) owns the routing contract and
[analyze-once](analyze-once.md) owns the analyze-once contract: the rendering
skill (`skills/review/SKILL.md`) carries only lean pointers here, never a second
copy. Recall lives in **one** place — this one.

> Scope note. Recall is the **`review` path only** — see [the deferred
> boundary](#the-deferred-boundary--sweep-recall-not-built-here) below. This doc
> **specifies** the mechanics and the contract; it does not itself run the
> `--recall` script or render the write-up. `skills/review/SKILL.md` enacts it —
> Step 2 gathers (item 2 below), Step 4 renders the status note.

## Step 2 — gather the recall read-back (once)

Recall is the **fifth** part of the review context the orchestrator assembles
**once** at `skills/review/SKILL.md` Step 2 (`docs/analyze-once.md` Step 1 — the
five-part table). After the diff makes the touched paths known and **before** the
single engine dispatch, the orchestrator reads back prior write-ups **once**,
orchestrator-side — the engine runs no recall itself (`agents/coherence-reviewer.md`
§"Recalled prior write-ups (advisory only)"). Pick the host exactly as the rest
of the suite does — **pwsh on Windows, bash elsewhere** (the host rule mirrored
across `scripts/resolve-config.{sh,ps1}` and the suite's mirror row):

| Step | How |
|---|---|
| invoke | `scripts/memory-mirror.<sh\|ps1> --recall --repo-root <REPO_ROOT> -- <the diff's touched paths>` — the touched paths from `git diff <integrationBranch>...<head> --name-only` |
| parse ONCE | read #69's documented TAB record stream a **single** time: `ENTRY-BEGIN<TAB>slug<TAB>ts`, `MATCH<TAB>path<TAB>line`, the verbatim entry-body lines, `ENTRY-END<TAB>slug<TAB>ts`, the `NONE<TAB>…` sentinel, and `SUMMARY<TAB>entries=<N><TAB>matches=<M>` **last**. Read `entries=<N>` from SUMMARY. Nothing re-reads recall after this point (the analyze-once invariant) |
| hand off | for each matched entry, wrap its **verbatim body lines** as a `SECTION-BEGIN … SECTION-END`-style payload — the **same** verbatim-payload shape the resolved `.project/` sections use (`skills/review/SKILL.md` Step 1 item 2) — as the engine's fifth advisory context part. **Never** hand the engine the raw TAB stream |
| empty state | `entries=0`, or the `NONE` sentinel, with **exit 0** → the recall part is empty/absent; the engine analyzes exactly as today (Step 4 renders the "no related prior write-ups found" note). A store that is **absent / empty / unreadable is this exit-0 empty-state — NOT a failure** (`scripts/memory-mirror.sh:61-64`; the `.ps1` twin) |
| failure state | ONLY a genuine invocation failure — a **nonzero exit** from a missing script/binary, a host-detection failure, or the **exit-2** bad-usage case — is a recall failure: note recall is unavailable and proceed exactly as if recall did not exist (analyze from scratch), fail-soft, never crash, never block the merge (`.project/design-philosophy.md#Error & failure philosophy`). Model the note on the Step 4 mirror table's `MIRROR-FAILED …` skip-and-note, scoped per this row |

The matched entries are handed to the read-only
[coherence-reviewer](../agents/coherence-reviewer.md) engine as the fifth,
**advisory** context part — never re-read after this single gather (the
analyze-once invariant; `docs/analyze-once.md` Step 1).

## Step 4 — render the recall status note (never silence)

The write-up **always** carries a recall status note — never silence
(`docs/write-up.md` §"The empty / clean-fit state — never silence": absence is an
explicit statement, never an absent output). It is rendered at
`skills/review/SKILL.md` Step 4, keyed off the `entries=<N>` count from the Step
2 single SUMMARY parse above — two branches, always exactly one:

| Branch | Render |
|---|---|
| `entries=<N>`, N > 0 | a short note **referencing the matched prior write-up(s)** that informed the analysis |
| N = 0, the `NONE` sentinel, or recall **unavailable** (the failure state above) | the explicit **"no related prior write-ups found"** note |

This is a **procedural status note** — like the D17 `milestone-bootstrapper`
nudge and the deferred-boundary statement — **not** an engine-field content
claim, so it is exempt from the write-up's "renders only from engine
`FINDINGS`/`PROPOSALS` fields" rule the same way those are (`docs/write-up.md`
§"What the write-up renders from" — the procedural-status-note exception list).
It is part of the inline write-up content the three supplemental mirrors copy.

## The contract

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
`scripts/memory-mirror.sh` `resolve_target()` (l.135-172: the four legs —
vault-env → vault-repo → claude-mem → the git-invisible fallback under
`.milestone-config/.runtime/`). Read and write resolve **identically**, so recall
always reads where the mirror wrote. It parses each prior entry's recorded
`grounding` citation in the `<path>:<line>` form (`docs/write-up.md` §"What the
write-up renders from" — the citations row) — from entry **bodies**, not headers —
and surfaces any entry whose cited path intersects the **current diff's touched
paths**. This is a **diff-keyed match**: flat cost, keyed only to what the change
touches — the same bound the per-change review's own greps use
(`.project/design-philosophy.md#What we optimize for` l.22).

### The empty-match and fail-soft cases — never silence

A resolvable, readable store that holds **no** entry touching the diff's paths
renders an explicit **"no related prior write-ups found"** note — never silence
(mirroring `docs/write-up.md` §"The empty / clean-fit state — never silence":
absence is an explicit statement, never an absent output).

Every thin-store failure degrades to that **same** note — the [resolution
degradation-matrix](resolution.md#degradation-matrix-what-happens-when-grounding-is-thin)
pattern (l.200-213): never a crash, never a block on the review or the merge
(`.project/design-philosophy.md#Error & failure philosophy` l.35 — fail-soft /
absence-means-skip; "Coherence heals; it never gates").

| Situation | Behavior |
|---|---|
| **Absent store** — no resolvable or readable target file | render "no prior write-ups found"; continue |
| **Empty store** — target resolves but holds no entries | render "no prior write-ups found"; continue |
| **Unreadable or corrupt store** — target resolves but does not parse | render "no prior write-ups found"; continue |

All three rows are #69's `--recall` **exit-0 empty-state** — the `NONE` sentinel
plus `SUMMARY entries=0` on stdout (`scripts/memory-mirror.sh:61-64`) — a
store that is absent/empty/unreadable is **not** a failure. A **genuine
invocation failure** (a *nonzero* exit — a missing script/binary, a
host-detection failure, or the exit-2 bad-usage case) is the separate fail-soft
case: the orchestrator notes recall is unavailable and proceeds from scratch,
also never a crash and never a merge block ([Step 2](#step-2--gather-the-recall-read-back-once)'s
failure state above).

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
(`agents/coherence-reviewer.md` §"Sweep-mode" l.141-143), so the diff-keyed
match above is **undefined** there — a future sweep hookup would need its own
match-key decision. Documented, not implemented.

## Recall contract (summary)

- **Single source.** This doc owns recall — the Step-2 gather mechanics, the
  Step-4 render mechanics, and the contract. `skills/review/SKILL.md`,
  `docs/write-up.md`, and `docs/analyze-once.md` carry lean pointers here, never
  a second copy.
- **`review` path only.** Recall is the fifth review-context part on the
  per-change `review` path; sweep-mode recall is **not** built (a sweep receives
  no diff, so the diff-keyed match is undefined).
- **Gathered once (Step 2).** Read back via `scripts/memory-mirror.{sh,ps1}
  --recall` after the diff is known and before the single engine dispatch; #69's
  TAB record stream is parsed **once**, `entries=<N>` read from SUMMARY, matched
  bodies handed to the engine as verbatim `SECTION-BEGIN … SECTION-END`-style
  advisory payloads — never the raw stream, never re-read.
- **Diff-keyed match.** Reads the **same** detect-or-fallback target the write
  path resolves (`scripts/memory-mirror.sh` `resolve_target()` l.135-172) and
  surfaces any prior entry whose recorded `<path>:<line>` grounding intersects
  the diff's touched paths — flat cost, keyed to what the change touches.
- **Empty / fail-soft — never silence (Step 4).** An absent/empty/unreadable
  store is #69's exit-0 empty-state (`NONE` + `SUMMARY entries=0`,
  `scripts/memory-mirror.sh:61-64`), **not** a failure; only a genuine nonzero
  invocation failure is the separate fail-soft case. Both render the explicit
  "no related prior write-ups found" note.
- **Advisory, never gates, never routes.** A matched prior write-up is context
  for the reader and the engine's derivation only — never a `FINDINGS`/`PROPOSALS`
  input, never a `severity` routing input, never a merge block (`docs/heal-routing.md`
  §"The single routing key"; `docs/write-up.md`).
