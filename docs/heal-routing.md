# Heal routing — where each finding's fix lands (by drift size)

The [review engine](../agents/coherence-reviewer.md) (#3) returns grounded
findings; the [analyze-once](analyze-once.md) (#4) layer shapes each into a
minimal, self-contained slice. This doc is the third piece: it decides **where
each fix lands** — and it makes that decision on **one key only, the drift
size** — without ever blocking the active issue/PR from merging.

That single invariant is what makes the tool *heal* rather than *gate*: it fixes
what it reasonably can and reports the rest, and the change it just reviewed
merges regardless of what the router decides (`BRIEF.md` §"It heals, it doesn't
gate" l.42-52).

This doc specifies the **routing contract only**. It is the spec the standalone
`review` skill (#7) implements; #7 (or the driver in the embedded path)
*performs* the heal. The router itself decides the destination — it does not act
(see [Read-only engine, orchestrator acts](analyze-once.md#read-only-engine-orchestrator-acts)).

> Boundary with #4. The [analyze-once](analyze-once.md) doc defines the **slice
> shapes** — the inline-fix slice and the large-drift slice — and explicitly
> hands the routing *decision* to this doc (`analyze-once.md` "The routing
> decision (which finding takes which route, keyed off `severity`) belongs to
> #6"). This doc references those slice shapes; it does **not** redefine them.

## The single routing key — drift size, nothing else

Each finding carries a drift-size hint in the engine's `severity` field —
`drift-trivial` | `drift-small` | `drift-medium` | `drift-large`
(`agents/coherence-reviewer.md`, "Structured return block"; "Drift-size hint").
The router branches on **that one field** and nothing else.

No other input influences where a fix lands:

| Tempting input | Why it is **NOT** a routing signal |
| --- | --- |
| **Run length / time elapsed** | a driver-side *context/resource* concern, owned by the driver (compaction + subagent isolation), never a routing input — see [Run length is not a routing signal](#run-length-is-not-a-routing-signal) |
| **Finding count** | each finding routes on *its own* `severity`; ten trivial findings are ten inline fixes, not one escalation |
| **Token budget** | a resource concern, like run length — never spills work into a milestone |
| **Severity-as-verdict** | `severity` is a drift-*size* hint, never a Blocker/Advisory merge verdict (`agents/coherence-reviewer.md` l.105) — it routes, it does not gate |

This is the load-bearing invariant: **"Coherence routes on drift size alone, so
a long run never distorts where a fix lands."** (`BRIEF.md` l.52, l.109.)

## The route table (mutually exclusive, total over the severity enum)

Every value the engine can emit in `severity` has exactly one route, and the
four routes do not overlap. The table is **total** (it covers
`drift-trivial`/`drift-small`/`drift-medium`/`drift-large` — the complete enum
from `agents/coherence-reviewer.md` l.98) and **mutually exclusive** (each
`severity` maps to one and only one destination):

| `severity` | Route | Destination | Slice it receives (#4) |
| --- | --- | --- | --- |
| `drift-trivial` | **inline fix** *(embedded)* — re-dispatch the implementer to fix it before the PR merges | the implementer, mid-run | the [inline-fix slice](analyze-once.md#the-inline-fix-slice-to-the-implementer-re-dispatch): `{ finding + citation + file scope }` |
| `drift-trivial` | **degrades to a small issue** *(standalone)* — no build loop to re-dispatch into | a new issue on the **current** milestone | — (issue carries the finding + its grounding) |
| `drift-small` | **new issue** | a new issue on the **current** milestone | — (issue carries the finding + its grounding) |
| `drift-medium` | **new issue** | a new issue on the **current** milestone | — (issue carries the finding + its grounding) |
| `drift-large` | **feeder handoff** — `milestone-feeder` plans + creates the follow-up milestone (its own triage gate) | `milestone-feeder` as a brief | the [large-drift slice](analyze-once.md#the-large-drift-slice-handoff-to-milestone-feeder): a tight adjustments brief |

`drift-trivial` is the only value whose route depends on the run **mode** —
embedded vs. standalone — and the two are mutually exclusive per run (a run is
one or the other). The standalone degrade is described next; `small`/`medium`
and `large` route identically in either mode.

### `drift-trivial` → inline fix (embedded), or a small issue (standalone)

- **Embedded mode (driver present).** A trivial finding is fixed **inline**: the
  orchestrator re-dispatches the implementer to fix it before the PR merges,
  mirroring `/code-review`'s in-scope loop — the reviewer stays read-only; the
  orchestrator performs the heal (convention:
  `milestone-driver/skills/solve-issue/SKILL.md:183`, "In-scope … re-dispatch
  the implementer to fix it"; `BRIEF.md` l.46, l.113). The re-dispatch receives
  **only** the [inline-fix slice](analyze-once.md#the-inline-fix-slice-to-the-implementer-re-dispatch)
  for that one finding — the finding + its citation + the exact file scope — not
  the whole analysis (`analyze-once.md`; `BRIEF.md` l.37).
- **Standalone mode (no driver build loop).** There is **no build loop to
  re-dispatch the implementer into**, so the inline route is unavailable. A
  trivial finding **degrades to a small issue** on the current milestone — the
  same destination as `drift-small`, opened so the fix is captured rather than
  applied in place (`BRIEF.md` l.78). This degrade is the *only* difference
  between the two modes; it is not a re-classification of drift size (the finding
  is still trivial), only a different destination for the trivial route when the
  inline mechanism is absent.

### `drift-small` / `drift-medium` → a new issue on the current milestone

Both route to **a new issue opened on the current milestone** — captured and
built later in the same run (`BRIEF.md` l.47). They share a destination because
the route key is drift size and both are in-milestone-sized: self-contained
enough to be one (small) or a few (medium) issues alongside the active work, not
large enough to warrant a follow-up milestone. A small/medium fix built on the
current milestone is **not re-coherence-reviewed** — see
[Recursion and termination](#recursion-and-termination--milestone-granularity-not-a-counter).

### `drift-large` → a brief to `milestone-feeder`

A large finding is handed to **`milestone-feeder` as a brief** of the
adjustments — the [large-drift slice](analyze-once.md#the-large-drift-slice-handoff-to-milestone-feeder)
from #4 (a tight adjustments brief with citations, *not* a raw repo dump). The
feeder plans + creates the follow-up milestone with its own triage gate,
authoring well-formed issues exactly as it does for any other brief (convention:
`milestone-feeder/skills/create/SKILL.md:182`, "create-or-adopt the milestone …
open each issue"; `BRIEF.md` l.48, l.38). The router **authors no milestone by
hand** — feeding the feeder gives the follow-up the same quality bar as any
other milestone. What the feeder can and cannot do next (create the milestone,
but not auto-run the driver in standalone v1) is the
[deferred boundary](#the-deferred-boundary--feeder--driver-auto-handoff-not-built-here).

## Convention proposals are a separate lane (not drift-routed)

The engine also returns a `PROPOSALS` block, parallel to `FINDINGS`
(`agents/coherence-reviewer.md` §"Convention proposals"). A **proposal** is
**not** a drift fix — it carries no `severity` — so this router does **not**
route it. The drift-size router above (`drift-trivial` / `drift-small` /
`drift-medium` / `drift-large`) is **unchanged**: it routes **findings** only.

- **Findings route on drift size** (the route table above).
- **Proposals route to a config-only PR** — the `review` skill's Step 3
  (`skills/review/SKILL.md`) writes the entry into `.project/conventions.md` on a
  `chore/propose-<slug>` branch and opens a config-only PR to `integrationBranch`
  (human-gated), independent of the drift buckets.

The two lanes never cross: a proposal never becomes a drift-routed issue, and a
drift finding never becomes a config PR. Like every route here, the proposal lane
**never gates** — the config PR is opened for the human to accept or reject, and
the change under review merges either way.

## Never a gate — the merge proceeds regardless

The router runs **after the change is built**, and its output **never feeds a
merge decision**. Whatever the routing decision — trivial, small/medium, or
large — the active issue/PR still merges (`BRIEF.md` l.42-44, l.50):

- The router produces **no hard stop and no merge-blocking verdict**. It emits a
  destination for each fix; it never emits "do not merge".
- The `severity` it routes on is a drift-*size* hint, never a merge verdict
  (`agents/coherence-reviewer.md` l.105). A `drift-large` finding routes to a
  follow-up milestone *and the active PR merges anyway* — the large concern
  becomes captured, auto-built follow-up work, never a silent stop (`BRIEF.md`
  l.50).
- This is the distinction from the suite's *pre-build* reviewers (triage /
  design-reviewer), which gate a not-yet-built issue and can escalate to a
  Blocker. Coherence is post-build and **heals, never gates** (`BRIEF.md`
  l.109): it fixes what it reasonably can and reports the rest, and the merge is
  out of its hands by construction.

The never-gate property holds across **every** drift size and **every** mode —
there is no `severity` value, and no run mode, under which routing blocks the
merge. The table above has no "blocks merge" column because no row would ever
set it.

## Recursion and termination — milestone granularity, not a counter

The router introduces **no re-review counter and no hard cap**. It cannot loop
forever, and the reason is structural — tied to milestone granularity, not to a
tally (`BRIEF.md` §"The recursion rule" l.54-61; §"Recorded decisions" l.110).

### Same-milestone fixes are not re-reviewed

A fix routed onto the **current** milestone — `drift-small`, `drift-medium`, and
the **standalone-degraded** `drift-trivial` (which also lands as a
current-milestone issue) — is **not** re-coherence-reviewed when it is later
built. Re-review is gated at **new-milestone granularity**, so an in-milestone
fix does not re-enter coherence (`BRIEF.md` l.56-58, l.110). The router records
no re-review trigger for these; by routing them in-milestone it places them, by
construction, in the not-re-reviewed bucket.

### A follow-up milestone IS re-reviewed — by construction only

A `drift-large` follow-up milestone created via the feeder **is**
re-coherence-reviewed — but **automatically and only by construction**: it
re-enters the normal `feeder → driver` pipeline, and that pipeline includes
coherence. The router records **no separate re-review trigger** for it; the
re-review arises because the follow-up milestone is built the same way any
milestone is, and coherence runs on each (`BRIEF.md` l.59). The router's only
act is the feeder handoff; the re-review is a property of the pipeline the
handoff feeds, not a call the router makes.

### Why the loop self-terminates (the geometry)

Termination relies on the **geometry of drift, not a cap**. Each pass the drift
is smaller — a large structural divergence, once routed to a follow-up
milestone and built, leaves at most small/medium residue; the next pass routes
that residue **in-milestone**, where it is **not re-reviewed**. So within a round
or two, findings land in the small/medium (in-milestone, not-re-reviewed) bucket
and stop triggering re-review. The geometry ends it — no hard cap, no counter
needed (`BRIEF.md` l.61, l.110).

| Where re-review happens | Trigger |
| --- | --- |
| Same-milestone fix (small/medium, standalone-degraded trivial) | **never re-reviewed** — gated out at milestone granularity |
| Follow-up milestone (large) | re-reviewed **by construction** — re-enters `feeder → driver`, which includes coherence; the router adds no explicit trigger |

## Run length is not a routing signal

How long the review run has gone **never** changes where a fix lands. Two
findings of equal drift size route **identically** regardless of how long the
run has been going (`BRIEF.md` l.52, l.109):

- Run length, time elapsed, and token budget are **driver-side context/resource
  concerns** — handled by subagent isolation, the analyze-once design, and
  compaction between issues — **never** by spilling work into a milestone.
- The router reads only `severity`. It has no clock, no token meter, and no
  run-length input — there is structurally no path for run length to reach the
  routing decision.
- A long run does **not** promote a `drift-small` finding to a follow-up
  milestone, and does **not** demote a `drift-large` finding to an inline fix.
  The route is set by the finding's drift size and nothing else.

This is the same invariant stated from the routing side: *coherence routes on
drift size alone, so a long run never distorts where a fix lands.*

## Empty / zero-findings — nothing to route

When the review engine returns `FINDINGS: none` (the clean-fit sentinel —
`agents/coherence-reviewer.md` l.94, l.102), there is **nothing to route**:

- The router opens **no issue**, hands **nothing** to the feeder, and
  re-dispatches **no** implementer.
- It does **not block the merge** — consistent with the never-gate invariant
  above; a clean fit is the success case, not a stop.
- This mirrors the [analyze-once zero-findings
  terminal](analyze-once.md#zero-findings--a-clean-terminal): no slices are
  derived, so there is nothing for the router to act on. The write-up still
  reports the clean fit explicitly (the
  [write-up's empty state](write-up.md#the-empty--clean-fit-state--never-silence)) —
  the router's silence is the *routing* outcome, never the *communication*
  outcome (`BRIEF.md` l.42-50).

A degraded-grounding run (`FINDINGS: none` with thin `SOURCES` lines) routes
identically to a genuine clean fit — both have no findings, so both route
nothing. `SOURCES` only tells the caller how much grounding was available; it is
not a routing input.

## The deferred boundary — `feeder → driver` auto-handoff (NOT built here)

The router documents one boundary it does **not** cross. The automated
`feeder → driver` handoff — the driver **auto-running** a feeder-created
follow-up milestone after the active milestone finishes, with **no human in
between** — **does not exist today** (`BRIEF.md` l.83, l.109):

- In **standalone v1** (this repo's `review` skill), a `drift-large` route can
  **create the follow-up milestone via the feeder** and **stops there**. The
  feeder currently ends at `create`; a **human** runs the driver on the
  follow-up milestone.
- Standalone v1 **cannot auto-run the driver**. The fully-automated cycle (feeder
  creates → driver builds, unattended) is the **embedded path**, and the auto-run
  itself is a separate cross-plugin companion change in the feeder/driver — on
  the same footing as the step-6.2 driver embedding (`BRIEF.md` l.79, l.81,
  l.83).
- This boundary is **documented, not implemented**. The router records it (here,
  and the `review` skill surfaces it in its write-up) so a reader knows the large
  route's follow-up milestone is created but not yet auto-built — it must not be
  presented as if the driver will pick it up automatically.

## Why there is no routing script

Routing is **orchestrator judgment expressed as a single-key branch**, not a
mechanizable transform that earns its own script — and least-code says don't add
one:

- The branch itself is a four-way switch on one already-parsed field
  (`severity`). Wrapping a one-key branch in a script adds an indirection layer
  without removing any work — the orchestrator already reads the
  [engine's block](analyze-once.md#step-2--produce-the-consolidated-analysis-once)
  to act on it at all.
- The **mode** input (embedded vs. standalone, which is the only thing that bends
  the `drift-trivial` route) is a property of *how the router was invoked* — the
  driver embeds it, or the standalone skill runs it — not a value a script could
  read from the finding. A script would have to be told the mode, at which point
  it is just the branch the orchestrator already holds.
- The judgment-bearing work each route depends on — the inline-fix **file scope**
  and the large-drift **adjustments brief** — is already produced by the
  [analyze-once slices](analyze-once.md#step-3--distribute-minimal-self-contained-slices),
  which deliberately ship **no slice-extraction script** for the same reason
  (`analyze-once.md` "Why there is no slice-extraction script"). The route just
  selects which slice shape applies; it synthesizes nothing a script could.

So the contract is enforced by the orchestrator reading `severity`, knowing its
mode, and dispatching the matching route — validated against the route table
above — with no script in between. This matches the resolution and analyze-once
layers, which ship scripts only for the genuinely mechanizable gather step and
keep judgment in the orchestrator.

## Heal-routing contract (summary)

- **Single routing key — drift size.** The router branches on the engine's
  `severity` field (`drift-trivial`/`small`/`medium`/`large`) and **nothing
  else**. Run length, finding count, token budget, and time are never routing
  inputs (`BRIEF.md` l.52, l.109).
- **Route table — total and mutually exclusive.** trivial → inline fix
  (embedded) **or** small issue on the current milestone (standalone degrade);
  small/medium → a new issue on the current milestone; large → a brief to
  `milestone-feeder`, which plans + creates the follow-up milestone with its own
  triage gate. Each `severity` value has exactly one destination.
- **Convention proposals — a separate lane, not drift-routed.** The engine's
  `PROPOSALS` block does not route through this router; a proposal goes to a
  config-only PR (`skills/review/SKILL.md` Step 3) targeting
  `integrationBranch`, human-gated — never a drift bucket, and never a gate.
- **Each route receives its #4 slice, not the analysis.** inline = the
  `{ finding + citation + file scope }` slice; large = the adjustments brief. The
  slice **shapes** are defined in [analyze-once.md](analyze-once.md); this doc
  references them.
- **Never a gate.** The router runs after the change is built; its output never
  feeds a merge decision. The active issue/PR merges regardless of the route —
  for every drift size and every mode (`BRIEF.md` l.42-44, l.50).
- **Recursion / termination — milestone granularity, no counter.**
  Same-milestone fixes (small/medium, standalone-degraded trivial) are **not**
  re-reviewed; a follow-up milestone **is** re-reviewed only **by construction**
  (it re-enters `feeder → driver`, which includes coherence). The loop
  self-terminates because drift shrinks each pass until findings stay
  in-milestone (`BRIEF.md` l.54-61, l.110).
- **Empty state.** `FINDINGS: none` → route nothing, open nothing, hand nothing
  to the feeder, block no merge.
- **Deferred boundary, documented not built.** The `feeder → driver` auto-handoff
  does not exist today; standalone v1 creates the follow-up milestone via the
  feeder but cannot auto-run the driver (`BRIEF.md` l.83, l.109).

Same DNA as the rest of the layer: the [engine](../agents/coherence-reviewer.md)
hints the drift size, [analyze-once](analyze-once.md) shapes the slice, this doc
routes it by that one key, and the merge proceeds either way — coherence heals,
it does not gate.
