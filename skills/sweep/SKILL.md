---
name: sweep
description: This skill should be used when the user invokes `/milestone-coherence-reviewer:sweep [pattern]`, or asks to "scan the app for consistency", "audit how X is done across the app", or "is this pattern done consistently app-wide?". Scans the app (broad by default, or narrowed to one named pattern) for standing inconsistency clusters and proposes governing conventions. Read-only on the merge; opens config-only PRs, never application-code PRs; never blocks the merge.
---

# sweep — the app-wide consistency scan

Scan the app for **standing inconsistency** — the "same thing done N inconsistent ways" the per-change `review` can never see, because `review` is diff-keyed and only catches inconsistency a *change* introduces. `sweep` is the opt-in, on-demand companion: it surveys `sourceGlobs` (broad by default, or narrowed to one named `<pattern>`), forms a **cluster** per repeated pattern, and — for each ungoverned cluster — proposes a governing `.project/conventions.md` convention; for each governed-but-undocumented deviation, it files a drift finding.

This skill is the **orchestrator**; the engine (`agents/coherence-reviewer.md`, dispatched in **sweep-mode**) is **read-only** — it returns `FINDINGS` **and** `PROPOSALS` and acts on nothing. Everything downstream — resolving config, the analyze-once dispatch, the write-up render, the config-only PR, the drift routing — is the **same machinery `review` uses**; this skill only swaps the per-change diff context for a seed/broad sweep context. It is **read-only on the merge**: it opens config-only PRs and follow-up issues, and **never blocks, gates, or touches any merge or the protected branch** (`BRIEF.md` §"It heals, it doesn't gate" l.42-52, l.126).

## Announce first

Say this to the user before doing any work:

> Standing by while I sweep the app for standing inconsistency — the same thing done several inconsistent ways. This is **read-only**: for each consistent-but-ungoverned pattern I propose a governing convention as a **config-only PR** (you merge to accept, close to reject); for each mixed cluster I recommend a grounded winner; for a documented convention that some code quietly deviates from, I file a follow-up issue. I **never block, gate, or touch any merge or your protected branch**, and I **open no application-code PRs**. You'll get a short write-up of every cluster, with a `file:line` for every site.

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

### Step 2 — Gather the SWEEP context ONCE and dispatch the engine in SWEEP-MODE (analyze-once, #4 → #3)

Build the sweep context a **single time**, then dispatch the engine **once** against it (`docs/analyze-once.md` Steps 1-2). The **only** difference from `review` Step 2 is the first context part — **there is no diff**; the seed is a broad or pattern-narrowed grep over `sourceGlobs`, run **on demand** (not diff-keyed):

| Part | Source |
|---|---|
| the **sweep seed** | broad (no arg → all `sourceGlobs`) or the named `<pattern>` — the patterns to cluster |
| the resolved `.project/` sections | from Step 1 (verbatim `SECTION-BEGIN … SECTION-END` slices) — read once |
| the `domainSkills` pointers | from Step 1's `KEY domainSkills …` records — read once |
| the **seed/broad grep results** | greps **within `sourceGlobs`** for the seed's repeated patterns and their sites — bounded to `sourceGlobs`, on demand, **never** on a per-change run |

Dispatch the read-only engine once **in sweep-mode** (`agents/coherence-reviewer.md` §"Sweep-mode") against that context. It forms a **cluster** per repeated pattern and classifies each **agree / disagree / governed(conform | deviate-documented | deviate-undocumented)**, then returns the **same** structured blocks it always returns: `PROPOSALS` (agree/disagree ungoverned clusters, `source: sweep`) **and** `FINDINGS` (governed-deviate-undocumented drift). Every cluster site is hard-grounded (`file:line`); ungroundable clusters/sites are dropped. Do **not** make the engine re-resolve keys or re-read whole docs (`docs/analyze-once.md` Step 2). `PROPOSALS: none` **and** `FINDINGS: none` is the clean, valid "nothing inconsistent" outcome (Step 4's empty state).

### Step 3 — Author each convention proposal as a config-only PR (the PROPOSALS lane)

Author each proposal as a config-only PR **exactly as `skills/review/SKILL.md` Step 3 does** — this is a genuine reference to that step's machinery, not a re-implementation. For each surviving `PROPOSALS` entry, do what `review` Step 3 does:

- the **SAME dedupe** — skip when an open `chore/propose-<slug>` PR already exists (`gh pr list --state open --head "chore/propose-<slug>" --json number`, or the `git ls-remote --heads origin "chore/propose-<slug>"` fallback) **or** `.project/conventions.md` already carries that `## heading` (an exact-heading scan) — matching the exact head branch and the exact heading, **never** a fuzzy `--search`;
- the **SAME suppress-on-degraded-repo step, decided BEFORE any render** — if `.project/conventions.md` is absent (`SIGNAL no-doc-grounding`), suppress every proposal and raise the one-time D17 nudge instead, never proposing against inferred conventions (`BRIEF.md` l.96, l.119); decided here at Step 3 so Step 4 never renders a proposal that then gets suppressed;
- the **SAME `chore/propose-<slug>` branch** cut off `integrationBranch` (**never** the protected branch), the `## <heading>` + `> <rule>` + `exemplar` entry (a `disagree: yes` entry recommends the grounded winner and notes the `diverging` sites), the **SAME `.project/conventions.md#"Commits & PRs"`** commit convention (Conventional Commits + the PR-number suffix), and `gh pr create --base <integrationBranch>` — a config-only PR to `integrationBranch`, **never** `protectedBranch`. The human **merges to accept, closes to reject**.

The **ONLY** sweep delta: in sweep-mode these proposals carry `source: sweep` (where `review` Step 3 handles `source: per-change`) — everything else is `review` Step 3's machinery, unchanged. A branch-cut / PR-open failure is **skipped-and-noted**, never a crash or a gate. This step runs **before** Step 4 so each PR link is live when the write-up renders. `PROPOSALS: none` → skip this step entirely.

### Step 4 — Render the write-up (#5): the cluster report

Render the write-up **entirely** from the engine's `FINDINGS` **and** `PROPOSALS` blocks, **reusing `docs/write-up.md`** — never re-grep, re-read a doc, or re-derive a cluster. The sweep's "cluster report" **is** the existing renderer's two sections, framed as clusters under a sweep headline:

1. **Proposed conventions** (from `PROPOSALS`, `docs/write-up.md` §"Proposed convention") — one item per agree/disagree cluster: the `## heading` · the one-line `rule` · the `exemplar` `path:line` · the `diverging` sites (**only** when `disagree: yes`) · the **live config-only PR link** opened at Step 3 (or the skipped-and-noted failure from Step 3). A proposal carries **no** redo one-liner — its redo is merging or closing that PR.
2. **Undocumented-deviation drift** (from `FINDINGS`, `docs/write-up.md` per-finding shape) — one tight item per governed-deviate-undocumented cluster: what deviates + `symbol` · why (the `ignored-convention` lens) · the single `grounding` ref verbatim (the governing `.project/conventions.md#<section>` + the deviating `file:line`) · a copy-paste `gh issue create --repo … --title … --body …` redo one-liner.

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

No clusters found, or every cluster **governed + conforming** (or a defensible documented deviation) → `FINDINGS: none` **and** `PROPOSALS: none`. Render a positive **"No standing inconsistency — nothing to propose"** headline that states **what was scanned** (broad vs the `<pattern>`) and **what was checked** (read from the engine's `SOURCES` lines — app-grep / project-docs / domain-skills availability, so a genuine clean sweep reads distinct from a thin-grounding run). Mirror `review`'s clean-fit terminal (`docs/write-up.md` §"The empty / clean-fit state") — never silence, never an empty output. Nothing is opened.

## Invariants (always true, every path)

- **Read-only engine, orchestrator acts.** The engine returns `FINDINGS` **and** `PROPOSALS` in sweep-mode and acts on nothing; this skill performs the heal and opens any config-only PR (`agents/coherence-reviewer.md` §"Sweep-mode", §"Read-only").
- **Opens no application-code PR.** It may open a **config-only PR** for a proposed `.project/conventions.md` entry (a `chore/propose-<slug>` branch off `integrationBranch`) and follow-up issues for drift — it edits **no** application code and creates **no** application-code branch.
- **Never blocks, gates, or touches a merge or the protected branch.** The sweep is on-demand and post-hoc; it has no merge to gate and never writes to or force-pushes the protected branch (`BRIEF.md` l.50, l.126).
- **Hard-grounding carries through.** Every cluster site — every proposal `site` / `exemplar` / `diverging` and every drift `grounding` — cites a real `file:line` (or `.project/` section / `domainSkills` source); the engine dropped any ungroundable cluster (`agents/coherence-reviewer.md` §"The hard-grounding rule").
- **Bounded, on demand.** The broad scan greps **within `sourceGlobs`** and runs **only on demand** — never on a per-change run, never a per-change substitute (`agents/coherence-reviewer.md` §"Sweep-mode"; the per-change path stays diff-keyed).
- **Analyze once, distribute slices.** The sweep context is gathered once and the engine dispatched once; each downstream route gets its minimal self-contained slice — never a re-gather, re-analyze, or re-resolve (`docs/analyze-once.md`).
- **Degraded environment still runs.** Thin/absent `.project/` or `.milestone-config/` reduces grounding and (on `conventions.md` absence) suppresses proposals + raises the one-time D17 nudge — never an error, never a stop.

## Output style

Concise and flat — status and outcomes, not a wall of text. Present clusters, routes, and options as **tables**. Mark anything needing a human with 🔴. The inline write-up is the un-buried headline; keep it tight — over-explaining defeats the tool (mirrors the siblings' communication-style contract; `BRIEF.md` l.63-74, l.129-130).

## Non-negotiables

- **Never a merge gate.** The sweep is read-only and post-hoc; it proposes and files follow-ups and blocks nothing (`BRIEF.md` l.42-44, l.50).
- **Never touches the protected branch.** Its writes are config-only PRs to `integrationBranch`, follow-up issues, a feeder brief, and comment/memory mirrors — never the protected branch (`BRIEF.md` l.126).
- **Read-only engine; the orchestrator acts.** The sweep-mode engine returns findings **and** proposals and acts on nothing; this skill performs the heal and opens any config-only PR (`agents/coherence-reviewer.md`).
- **Reuse, not duplication.** resolve-config (#2), the engine (#3), analyze-once (#4), the write-up renderer (#5), the config-PR proposal machinery (`review` Step 3), and heal-routing (#6) are **reused** — the sweep adds only the seed/broad context and the cluster framing. No new script, no new config key, no new dependency.
- **Hard-grounding.** Every cluster site cites a real `file:line`; ungroundable clusters are dropped by the engine, never rendered.
- **Bounded and on demand.** The scan is scoped to `sourceGlobs` and runs only when invoked — never on a per-change run.
