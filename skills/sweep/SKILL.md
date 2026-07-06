---
name: sweep
description: This skill should be used when the user invokes `/milestone-coherence-reviewer:sweep [pattern]`, or asks to "scan the app for consistency", "audit how X is done across the app", or "is this pattern done consistently app-wide?". Scans the app (broad by default, or narrowed to one named pattern) for standing inconsistency clusters and proposes governing conventions; a broad scan checkpoints its progress per top-level sub-path, so an interruption resumes instead of restarting from zero. Read-only on the merge; opens config-only PRs, never application-code PRs; never blocks the merge.
---

# sweep — the app-wide consistency scan

Scan the app for **standing inconsistency** — the "same thing done N inconsistent ways" the per-change `review` can never see, because `review` is diff-keyed and only catches inconsistency a *change* introduces. `sweep` is the opt-in, on-demand companion: it surveys `sourceGlobs` (broad by default, or narrowed to one named `<pattern>`), forms a **cluster** per repeated pattern, and — for each ungoverned cluster — proposes a governing `.project/conventions.md` convention; for each governed-but-undocumented deviation, it files a drift finding.

This skill is the **orchestrator**; the engine (`agents/coherence-reviewer.md`, dispatched in **sweep-mode**) is **read-only** — it returns `FINDINGS` **and** `PROPOSALS` and acts on nothing. Everything downstream — resolving config, the analyze-once dispatch, the write-up render, the config-only PR, the drift routing — is the **same machinery `review` uses**; this skill only swaps the per-change diff context for a seed/broad sweep context. It is **read-only on the merge**: it opens config-only PRs and follow-up issues, and **never blocks, gates, or touches any merge or the protected branch** (`BRIEF.md` §"It heals, it doesn't gate" l.42-52, l.126).

## Announce first

Say this to the user before doing any work:

> Standing by while I sweep the app for standing inconsistency — the same thing done several inconsistent ways. This is **read-only**: for each consistent-but-ungoverned pattern I propose a governing convention as a **config-only PR** (you merge to accept, close to reject); for each mixed cluster I recommend a grounded winner; for a documented convention that some code quietly deviates from, I file a follow-up issue. I **never block, gate, or touch any merge or your protected branch**, and I **open no application-code PRs**. A broad scan checkpoints its progress, so if I'm interrupted, re-running picks up where I left off instead of starting over. You'll get a short write-up of every cluster, with a `file:line` for every site.

## Argument handling — one OPTIONAL positional argument

`sweep` takes a **single optional positional argument** — a `<pattern>` to narrow the scan — passed as `$ARGUMENTS`. It is **string-substituted, not CLI-parsed** (the same detection style as `review`'s argument and the feeder's brief-form detection, `milestone-feeder/skills/plan/SKILL.md:182-188`):

| `$ARGUMENTS` | Mode | Scan |
|---|---|---|
| **empty** | **broad** (the default) | every `sourceGlobs` path — surface *every* standing inconsistency cluster |
| **a `<pattern>`** | **narrowed** | one named seed — cluster only that pattern's sites |

**A missing argument is NOT an error.** This is the deliberate contrast with `review`, whose missing/unresolvable branch-or-PR is a 🔴 error-and-stop (`skills/review/SKILL.md` §"Missing or unresolvable argument"): here, **absent means broad** — the valid default mode, never a stop and never a usage error. There is no error-and-stop path in `sweep`; the scan always runs.

## Procedure

### Step 1 — Resolve config + project docs (drive #2; degrade cleanly)

Resolve config + `.project/` **reusing `skills/review/SKILL.md` Step 1's resolve-config machinery** — drive `scripts/resolve-config.{sh,ps1}` (pwsh on Windows, bash elsewhere); same consumed keys, same TAB-parse + encoding-reversal order, same degradation table + one-time D17 `milestone-bootstrapper` nudge (see `docs/resolution.md`). That machinery — host selection, keys/docs, decode order, degradation, D17 nudge — is reused **exactly**, with **one sweep-specific delta**: the `.project/` **section-selection**. `review` Step 1 collects the cited anchors *from the change under review* (`skills/review/SKILL.md` Step 1.2 — "from the change under review … collect the cited `.project/<doc>#<section>` anchors"); a sweep has **no change under review**, so the anchors are selected **broadly**, or by the `<pattern>` when narrowed — per the section-selection blockquote below. Absence reduces grounding; it never aborts the sweep.

> Which `.project/` sections to cite: for a **narrowed** sweep, the sections a human would consult for that `<pattern>` (e.g. `conventions.md#"Service layer"`); for a **broad** sweep, resolve `conventions.md` (the governing spine — every cluster is classified against it) plus any `design-system.md` / `library-manifest.md` sections the seed patterns touch.

### Step 2 — Gather the SWEEP context and dispatch the engine in SWEEP-MODE — once per sub-path when broad, resumable via a checkpoint (analyze-once, #4 → #3)

Build the sweep context, then dispatch the engine **in sweep-mode** (`docs/analyze-once.md` Steps 1-2). Step 1's config + `.project/` section resolution still runs **once** per skill invocation, exactly as today — it is **not** re-resolved per sub-path; only the dispatch loop below iterates. The **only** change from the prior one-shot dispatch is **how many times** the engine is dispatched on the **broad** path, and that loop is now resumable via a checkpoint file. The **narrowed** path (a `<pattern>` given) is completely unaffected — one dispatch, exactly as before — and the checkpoint file is **neither read nor written** on that path:

| Mode | Dispatch | Checkpoint |
|---|---|---|
| **narrowed** (`<pattern>` given) | **one** engine dispatch against the whole named pattern, exactly as before | not read, not written — untouched |
| **broad** (no `$ARGUMENTS`) | **one dispatch per top-level sub-path** not yet marked done, in turn | read at the start of the run; written after every sub-path completes |

#### Narrowed sweep — one dispatch, unchanged

Assemble the four context parts once, scoped to the `<pattern>`, and dispatch the engine once — byte-for-byte the prior behavior (Step 2.5, below, adds a new pass immediately after this dispatch; the dispatch itself — context assembly + the single engine call — is what stays unchanged):

| Part | Source |
|---|---|
| the **sweep seed** | the named `<pattern>` |
| the resolved `.project/` sections | from Step 1 (verbatim `SECTION-BEGIN … SECTION-END` slices) — read once |
| the `domainSkills` pointers | from Step 1's `KEY domainSkills …` records — read once |
| the **pattern-keyed grep results** | greps within `sourceGlobs` for the pattern's sites |

#### Broad sweep — per-sub-path dispatch, checkpointed

1. **Resolve the checkpoint path.** `.milestone-config/.runtime/sweep-progress.json`, relative to the repo root — the same git-invisible `.runtime/` location the memory mirror already uses (`scripts/memory-mirror.sh:134-138`; `.milestone-config/.gitignore` already lists `.runtime/` — no new ignore rule needed).

2. **Seed, resume, merge, or discard — in this decision order:**

   | Checkpoint state | Treatment |
   |---|---|
   | **File absent** (first run) | Seed a **fresh** worklist: one entry per top-level directory derived from Step 1's **currently-resolved** `sourceGlobs` KEY records (never a hardcoded list) — the directory prefix of each glob (`skills/**` → `skills/`, `agents/**` → `agents/`, …). Every entry starts `"done": false`; `accumulated.findings` / `accumulated.proposals` start `[]`. |
   | **File present but fails to parse** (`jq -e .` / `ConvertFrom-Json` errors) | **Malformed → stale.** Discard the file entirely and seed fresh, exactly as the absent case. Never crash, never hard-fail (`.project/design-philosophy.md#Error & failure philosophy` — fail-soft / absence-means-skip). |
   | **File present, parses, but `accumulated` lacks the `droppedCount` key** (a checkpoint written before issue #38 added it) | **Schema-stale → discard.** Treat exactly like the malformed case — discard the file entirely and seed fresh, never backfill a bare `0` into an old checkpoint. This also guarantees every finding in the resumed run passes through the Step 2.5 verify pass: an old checkpoint could otherwise carry findings appended before that pass existed, and resuming it "as-is" would ship them unverified and would crash the first `droppedCount` increment against a missing key. Never crash. |
   | **File present, parses, but any `worklist[].subPath` is NOT among the current `sourceGlobs`-derived top-level dirs** | **Stale → discard.** A referenced sub-path that no longer exists (a dir removed/renamed in `sourceGlobs`) means the checkpoint no longer matches reality — discard it entirely and seed fresh. Never crash. |
   | **File present, parses, every `worklist[].subPath` still valid, but the current `sourceGlobs`-derived dirs include one or more NOT in the worklist** (`sourceGlobs` **grew** since the checkpoint was written — e.g. a sibling issue broadened it mid-run) | **Merge, not reseed.** Append the newly-added sub-path(s) with `"done": false`. Keep every existing `done: true` mark and everything already in `accumulated` untouched — never discard, never re-scan a sub-path already marked done. |
   | **File present, parses, every `subPath` still valid, some done, some not** (the ordinary interrupted-then-resumed case) | **Resume as-is** — no worklist edit needed. |

3. **Dispatch once per not-yet-done sub-path, in worklist order.** For each `worklist[]` entry with `done: false`:
   - Assemble that sub-path's context — the same four-part shape as the narrowed path above, with the sweep seed narrowed to that one sub-path — gathered **once** for that sub-path (`docs/analyze-once.md` Step 1).
   - Dispatch the read-only engine **once**, in sweep-mode, against that context (`agents/coherence-reviewer.md` §"Sweep-mode") — the identical engine contract, just a narrower per-call scope. No change to the engine itself.
   - **Verify grounding, drop what fails — nested here, not deferred** (Step 2.5, below; `docs/analyze-once.md` §"Verify grounding, drop what fails"; issue #38). Because the checkpoint persists only `accumulated.findings` / `accumulated.proposals` — never a per-sub-path grep cache — a later-resumed invocation would have no tier-1 cache to check an earlier sub-path's findings against. So apply the two-tier verify pass to this sub-path's just-returned `FINDINGS` **now**: tier 1 against this sub-path's own just-produced grep cache (plus Step 1's `.project`/`domainSkills` cache), tier 2 a bounded live re-check on a tier-1 miss — **before** anything from this dispatch is appended, marked done, or persisted. A finding failing both tiers is dropped here and is never appended to `accumulated.findings`; tally it into `accumulated.droppedCount`.
   - Append the survivors — the post-verify `FINDINGS` and the `PROPOSALS` entries — to `accumulated.findings` / `accumulated.proposals`.
   - Mark that entry `"done": true`.
   - **Persist immediately** — write the updated checkpoint (worklist + accumulated + `updatedAt`) back to disk **before** moving to the next sub-path. This is the durability point: an interruption after this write loses at most the *next* sub-path's work, never a completed one.

4. **Full completion — clear the checkpoint.** Once every `worklist[]` entry is `done: true` and Step 6 is reached, delete `.milestone-config/.runtime/sweep-progress.json` (best-effort — a delete failure is reported, never fatal). A finished run leaves no stale "all done" state behind to confuse the next invocation; the next broad sweep with no checkpoint present seeds fresh, exactly like a genuine first run.

5. **What Steps 3-6 consume.** By the time dispatching ends — whether in one pass or resumed across several invocations — `accumulated.findings` / `accumulated.proposals` **is** the run's `FINDINGS` / `PROPOSALS` block: the same shape Steps 3-6 below already consume from a single dispatch. They do not need to know whether it came from one engine call or several. The top-level `REVIEWED: sweep:broad` / `SOURCES.app-grep: swept-broad` values Step 4 renders describe the overall run **mode** (broad vs. narrowed), unaffected by whether the broad dispatch loop took one call or several. A broad sweep with this checkpoint is a **sequence of per-sub-path analyze-once cycles**, each individually honoring "once per review call" (`docs/analyze-once.md`) — it does not alter the per-change `review` path at all. `accumulated.droppedCount` (see "Checkpoint schema" below) rides the same accumulation and feeds Step 4 identically.

#### Checkpoint schema

```json
{
  "worklist": [
    { "subPath": "skills/", "done": true },
    { "subPath": "agents/", "done": true },
    { "subPath": "hooks/", "done": false },
    { "subPath": ".claude-plugin/", "done": false }
  ],
  "accumulated": {
    "findings": [],
    "proposals": [],
    "droppedCount": 0
  },
  "updatedAt": "2026-07-05T20:14:03Z"
}
```

Read and write it with the suite's already-approved JSON tooling — `jq` (bash) / `ConvertFrom-Json` + `ConvertTo-Json` (pwsh) — no new dependency, no new script (`.project/library-manifest.md#Approved libraries (by purpose)`). Reading/writing one small JSON scratch file is exactly the kind of mechanical, non-judgment operation the suite already does inline with `jq` (e.g. `resolve-config.sh`'s own `jq -e .` validation) rather than wrapping in a dedicated script; the sibling git-invisible-scratch-file convention is `scripts/memory-mirror.sh:134-138`, applied here to a resumability checkpoint instead of a memory mirror. `accumulated.droppedCount` is the running tally of findings the Step 2.5 verify pass dropped, incremented per sub-path (`docs/analyze-once.md` §"Verify grounding, drop what fails"; issue #38). It survives a resume exactly like `findings`/`proposals` do **provided the checkpoint already carries the key** — a checkpoint written before this field existed is schema-stale and discarded rather than backfilled (the decision table above), so `droppedCount` is never missing on a checkpoint this pass actually resumes.

`PROPOSALS: none` **and** `FINDINGS: none` (i.e. `accumulated.findings`/`accumulated.proposals` both empty once the loop above completes) is the clean, valid "nothing inconsistent" outcome (Step 4's empty state; that section's "what was checked" line reads Step 1's project-docs/domain-skills counts — resolved once, shared across every sub-path dispatch — plus the constant `swept-broad` app-grep descriptor from bullet 5 above, never a per-sub-path `SOURCES` set). A nonzero `accumulated.droppedCount` does not change this empty-state classification — the sweep still found no *surviving* inconsistency — but Step 4 still renders the drop-count line per `docs/write-up.md` §"Dropped-grounding count"; only a `droppedCount` of exactly zero renders no drop-count line at all.

#### Known trade-off — clustering narrows to the sub-path

Each per-sub-path dispatch clusters only **within that sub-path's own grep results** — `agents/coherence-reviewer.md` §"Sweep-mode" has the engine "gather its sites **across `sourceGlobs`**", and here the seed handed to any one dispatch **is** just that one sub-path, not the whole tree. A real standing-inconsistency pattern whose sites split across two or more top-level directories (e.g. 2 sites in `skills/` + 2 in `agents/` — 4 total, clearing the engine's ≥3-site cluster floor) can fall **under** that floor in *each* dispatch alone, even though a single whole-tree dispatch would have clustered all 4 sites together and cleared it. This is the deliberate cost of resumability at **directory granularity** — bounding every dispatch to one sub-path's cost so an interruption never re-derives more than one sub-path's context — traded against full cross-directory clustering fidelity in one pass. It does not affect any of this issue's acceptance criteria (all are checkpoint/worklist mechanics, not clustering fidelity); it is flagged here, not silently absorbed, as a known limitation worth weighing against a possible follow-up (e.g. a final cross-sub-path reconciliation pass) — out of scope for this issue.

#### No concurrency-collision guard — low blast radius, not an oversight

Two overlapping broad sweeps racing to write the same checkpoint is out of scope for this issue, deliberately: this is a **local, per-clone scratch file** (git-invisible, single developer's own working copy), not a shared or multi-writer store. The worst case of a race is a lost update to one sub-path's `done` mark, causing at most a **redundant re-dispatch** of that one sub-path on the next invocation — already covered by the malformed/stale-checkpoint fallback above (discard-and-reseed, or at worst one duplicate dispatch; never data loss, never a crash). A lock file or other mutual-exclusion guard would defend against a scenario whose downside is already bounded and self-healing, so it is not added here (least-code).

### Step 2.5 — Verify grounding, drop what fails

Apply the two-tier verify pass specified once, in full, at
`docs/analyze-once.md` §"Verify grounding, drop what fails" (issue #38) to
every returned finding, before Step 3 (proposal-PR authoring), Step 4
(write-up render), or Step 5 (drift routing) consume `FINDINGS`. `PROPOSALS` is
out of scope for this pass — findings only. `FINDINGS: none` skips it
entirely — no drop-count line.

- **Narrowed sweep** (a `<pattern>` given) — one engine dispatch, so this step
  runs **once**, immediately after that single Step 2 dispatch returns, exactly
  like `review`'s Step 2.5: tier 1 checks each finding's `grounding` against
  Step 1's `.project`/`domainSkills` cache and Step 2's pattern-keyed grep
  cache; a tier-1 miss gets one bounded tier-2 re-check before being dropped.
- **Broad sweep** (no `$ARGUMENTS`) — this step does **not** wait for the whole
  Step 2 loop to finish. It is already applied **nested inside** Step 2's
  per-sub-path dispatch loop (see Step 2 item 3, "Verify grounding, drop what
  fails — nested here, not deferred") — immediately after each sub-path's
  dispatch and before that sub-path's survivors are appended to `accumulated`,
  marked `done`, or persisted, because the checkpoint carries no per-sub-path
  grep cache for a later-resumed invocation to check against. By the time the
  whole broad loop completes, every finding in `accumulated.findings` has
  already cleared this pass; the running tally is `accumulated.droppedCount`
  (see "Checkpoint schema" above).

### Step 3 — Author each convention proposal as a config-only PR (the PROPOSALS lane)

Author each proposal as a config-only PR **exactly as `skills/review/SKILL.md` Step 3 does** — this is a genuine reference to that step's machinery, not a re-implementation. For each surviving `PROPOSALS` entry, do what `review` Step 3 does:

- the **SAME dedupe** — skip when an open `chore/propose-<slug>` PR already exists (`gh pr list --state open --head "chore/propose-<slug>" --json number`, or the `git ls-remote --heads origin "chore/propose-<slug>"` fallback) **or** `.project/conventions.md` already carries that `## heading` (an exact-heading scan) — matching the exact head branch and the exact heading, **never** a fuzzy `--search`;
- the **SAME suppress-on-degraded-repo step, decided BEFORE any render** — if `.project/conventions.md` is absent (`SIGNAL no-doc-grounding`), suppress every proposal and raise the one-time D17 nudge instead, never proposing against inferred conventions (`BRIEF.md` l.96, l.119); decided here at Step 3 so Step 4 never renders a proposal that then gets suppressed;
- the **SAME `chore/propose-<slug>` branch** cut off `integrationBranch` (**never** the protected branch), the `## <heading>` + `> <rule>` + `exemplar` entry (a `disagree: yes` entry recommends the grounded winner and notes the `diverging` sites), the **SAME `.project/conventions.md#"Commits & PRs"`** commit convention (Conventional Commits + the PR-number suffix), and `gh pr create --base <integrationBranch>` — a config-only PR to `integrationBranch`, **never** `protectedBranch`. The human **merges to accept, closes to reject**.

The **ONLY** sweep delta: in sweep-mode these proposals carry `source: sweep` (where `review` Step 3 handles `source: per-change`) — everything else is `review` Step 3's machinery, unchanged. A branch-cut / PR-open failure is **skipped-and-noted**, never a crash or a gate. This step runs **before** Step 4 so each PR link is live when the write-up renders. `PROPOSALS: none` → skip this step entirely.

### Step 4 — Render the write-up (#5): the cluster report

Render the write-up **entirely** from the engine's `FINDINGS` **and** `PROPOSALS` blocks, refined by the Step 2.5 verify pass above, **reusing `docs/write-up.md`** — never re-grep, re-read a doc, or re-derive a cluster. The sweep's "cluster report" **is** the existing renderer's sections, framed as clusters under a sweep headline:

1. **Proposed conventions** (from `PROPOSALS`, `docs/write-up.md` §"Proposed convention") — one item per agree/disagree cluster: the `## heading` · the one-line `rule` · the `exemplar` `path:line` · the `diverging` sites (**only** when `disagree: yes`) · the **live config-only PR link** opened at Step 3 (or the skipped-and-noted failure from Step 3). A proposal carries **no** redo one-liner — its redo is merging or closing that PR.
2. **Undocumented-deviation drift** (from `FINDINGS`, `docs/write-up.md` per-finding shape) — one tight item per governed-deviate-undocumented cluster: what deviates + `symbol` · why (the `ignored-convention` lens) · the single `grounding` ref verbatim (the governing `.project/conventions.md#<section>` + the deviating `file:line`) · a copy-paste `gh issue create --repo … --title … --body …` redo one-liner.
3. **Dropped-grounding count** (from the Step 2.5 verify pass, not an engine field — `docs/write-up.md` §"Dropped-grounding count") — when the run's tally (`accumulated.droppedCount` on a broad sweep) is greater than zero, states "N findings dropped: grounding did not resolve" verbatim; renders nothing when it is zero.

Then **mirror** the same write-up to the three supplemental audit-trail copies, each best-effort, exactly as `review` Step 4 (`docs/write-up.md` §"Graceful degradation"): memory via `scripts/memory-mirror.{sh,ps1}` (detect-or-fallback); the issue/PR comments **only when a resolvable issue/PR context exists** — for an ad-hoc broad sweep there is often none, so those mirrors are **skipped-and-noted**, never forced. The inline write-up is the PRIMARY deliverable and is always produced.

### Step 5 — Route drift findings by drift size (enact #6, standalone mode)

Route **only** the `FINDINGS` drift (the governed-deviate-undocumented clusters) by each finding's `severity` and nothing else, **reusing `docs/heal-routing.md`** exactly as `review` Step 5 does in **standalone mode** (no driver build loop):

| `severity` | Route (standalone) |
|---|---|
| `drift-trivial` | **degrades to a new issue** — no build loop to re-dispatch the implementer |
| `drift-small` / `drift-medium` | **a new issue** carrying the finding + its `grounding` |
| `drift-large` | **a brief to `milestone-feeder`** — the large-drift slice (a tight adjustments brief with citations, never a raw dump); the feeder plans + creates the follow-up milestone with its own triage gate |

**Reconcile the "current milestone" assumption — an ad-hoc sweep may have none.** `review` Step 5 opens the `drift-small` / `drift-medium` (and standalone-degraded `drift-trivial`) issue **on the current milestone** (`docs/heal-routing.md` §"`drift-small` / `drift-medium`"). A sweep, however, is on-demand and may run with **no active milestone** — do not silently imply a "current milestone" always exists. Reconcile it explicitly:

- **A milestone IS contextually active** (the sweep was invoked inside a milestone run) → attach the new issue to it, exactly as `review` does.
- **No current-milestone context** (an ad-hoc sweep) → open the new issue **without a milestone** — a **backlog issue** carrying the finding + its `grounding`. Never invent or assume a "current" milestone.

The `severity`-keyed routing is otherwise **identical to `review`** — only the milestone attachment is conditional on context.

State the **deferred boundary** in the write-up: standalone cannot auto-run `milestone-driver`; a human runs it on any follow-up milestone (`docs/heal-routing.md` §"The deferred boundary"). **`PROPOSALS` are NOT routed here** — they are the separate config-PR lane (Step 3; `docs/heal-routing.md` §"Convention proposals are a separate lane"). `FINDINGS: none` → route nothing.

### Step 6 — End cleanly

Surface the inline write-up as the run's deliverable, with a flat summary of what was found and routed where (which clusters became proposals + their PR links, which became drift issues, which mirrors landed vs were skipped-and-noted, and — when a large-drift milestone was created — the deferred-boundary note). The sweep is **read-only on the merge** — there is no merge to gate; nothing was blocked and the protected branch was never touched.

## Empty state — a positive result, never silence

No clusters found, or every cluster **governed + conforming** (or a defensible documented deviation) → `FINDINGS: none` **and** `PROPOSALS: none` (for a broad sweep, `accumulated.findings` / `accumulated.proposals` both empty once every sub-path is done). Render a positive **"No standing inconsistency — nothing to propose"** headline that states **what was scanned** (broad vs the `<pattern>`) and **what was checked** (read from the engine's `SOURCES` lines — app-grep / project-docs / domain-skills availability, so a genuine clean sweep reads distinct from a thin-grounding run). Mirror `review`'s clean-fit terminal (`docs/write-up.md` §"The empty / clean-fit state") — never silence, never an empty output. Nothing is opened, and a fully-clean broad sweep still clears its checkpoint (Step 2) exactly as any other completed broad sweep does.

## Invariants (always true, every path)

- **Read-only engine, orchestrator acts.** The engine returns `FINDINGS` **and** `PROPOSALS` in sweep-mode and acts on nothing; this skill performs the heal and opens any config-only PR (`agents/coherence-reviewer.md` §"Sweep-mode", §"Read-only").
- **Opens no application-code PR.** It may open a **config-only PR** for a proposed `.project/conventions.md` entry (a `chore/propose-<slug>` branch off `integrationBranch`) and follow-up issues for drift — it edits **no** application code and creates **no** application-code branch.
- **Never blocks, gates, or touches a merge or the protected branch.** The sweep is on-demand and post-hoc; it has no merge to gate and never writes to or force-pushes the protected branch (`BRIEF.md` l.50, l.126).
- **Hard-grounding carries through.** Every cluster site — every proposal `site` / `exemplar` / `diverging` and every drift `grounding` — cites a real `file:line` (or `.project/` section / `domainSkills` source); the engine dropped any ungroundable cluster (`agents/coherence-reviewer.md` §"The hard-grounding rule"). Step 2.5 is a second, orchestrator-side check on top of that emit-time rule — it mechanically re-verifies each `FINDINGS` grounding and drops any that fail both tiers (`docs/analyze-once.md` §"Verify grounding, drop what fails"; issue #38).
- **Bounded, on demand.** The broad scan greps **within `sourceGlobs`** and runs **only on demand** — never on a per-change run, never a per-change substitute (`agents/coherence-reviewer.md` §"Sweep-mode"; the per-change path stays diff-keyed).
- **Analyze once (per sub-path), distribute slices.** Step 1's config + `.project/` resolution is gathered once per skill invocation. The engine dispatch is once **per not-yet-done sub-path** on the broad path (once, total, on the narrowed path) — each individual dispatch still honors "once per review call" (`docs/analyze-once.md`); downstream routes get their minimal self-contained slice from the accumulated result — never a re-gather, re-analyze, or re-resolve.
- **Broad sweep is resumable; narrowed sweep is untouched.** A broad sweep seeds/resumes a per-sub-path worklist checkpoint (`.milestone-config/.runtime/sweep-progress.json` — git-invisible, no new dependency, no new script); an interruption picks up at the next not-yet-done sub-path instead of re-scanning from zero, and a malformed/stale checkpoint discards and re-seeds rather than crashing. A narrowed (`<pattern>`) sweep keeps its original one-shot dispatch — the checkpoint file is never read or written on that path.
- **Degraded environment still runs.** Thin/absent `.project/` or `.milestone-config/` reduces grounding and (on `conventions.md` absence) suppresses proposals + raises the one-time D17 nudge — never an error, never a stop.

## Output style

Concise and flat — status and outcomes, not a wall of text. Present clusters, routes, and options as **tables**. Mark anything needing a human with 🔴. The inline write-up is the un-buried headline; keep it tight — over-explaining defeats the tool (mirrors the siblings' communication-style contract; `BRIEF.md` l.63-74, l.129-130).

## Non-negotiables

- **Never a merge gate.** The sweep is read-only and post-hoc; it proposes and files follow-ups and blocks nothing (`BRIEF.md` l.42-44, l.50).
- **Never touches the protected branch.** Its writes are config-only PRs to `integrationBranch`, follow-up issues, a feeder brief, and comment/memory mirrors — never the protected branch (`BRIEF.md` l.126).
- **Read-only engine; the orchestrator acts.** The sweep-mode engine returns findings **and** proposals and acts on nothing; this skill performs the heal and opens any config-only PR (`agents/coherence-reviewer.md`).
- **Reuse, not duplication.** resolve-config (#2), the engine (#3), analyze-once (#4), the write-up renderer (#5), the config-PR proposal machinery (`review` Step 3), and heal-routing (#6) are **reused** — the sweep adds only the seed/broad context, the cluster framing, and (for the broad path) the per-sub-path worklist checkpoint. No new script, no new config key, no new dependency — the checkpoint is a git-invisible scratch JSON file read/written with the suite's already-approved `jq` / `ConvertFrom-Json`, exactly like the memory mirror's own fallback file.
- **Hard-grounding.** Every cluster site cites a real `file:line`; ungroundable clusters are dropped by the engine, never rendered.
- **Bounded and on demand.** The scan is scoped to `sourceGlobs` and runs only when invoked — never on a per-change run.
