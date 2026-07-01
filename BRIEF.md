# milestone-coherence-reviewer — feeder brief

> **How to use this doc.** This is a feature brief for `milestone-feeder`. Run `/milestone-feeder:plan BRIEF.md` in this repo; the feeder decomposes it into a milestone of small, well-formed issues, which `milestone-driver` builds. It records intent + decisions so the feeder grounds rather than parks; it is deliberately **not** pre-broken into issues.
>
> Suggested milestone line: `Milestone: milestone-coherence-reviewer v0.1.0`.
>
> **Status: reviewed against the original concept — ready for the feeder.**

## What it is

A **post-build reviewer that checks whether a change fits how the app is already built** — and then *heals* what it can rather than gating. It's the missing review layer: the driver's triage checks the design *before* build, `/code-review` checks the code is *correct*, and the visual gate checks UI *renders* — but nothing checks that the built code is *consistent with the rest of the app*. That's this.

It answers questions a senior dev would ask in review:

- Why is this controller built differently from the other ten?
- Why a fresh model instead of inheriting the base model with the shared fields?
- Why doesn't this view follow the control/style behavior of the other similar pages?
- Did you just rewrite a query or helper that already exists elsewhere?
- Did you hand-roll something an approved/industry-standard library already does?
- Are you following the language + framework's best practices?
- Did you ignore an established convention in this app — which, and why?

The most important output isn't the *verdict* — it's a **clear, plain-English explanation of what it did and why**, with citations and a one-click way to redo it differently if you disagree.

## What it checks against (three sources)

1. **The app itself** — bounded, diff-keyed greps for the specific symbols/patterns the change introduces ("does a helper like this already exist in `services/`?", "how do the other controllers do this?"). Not a whole-repo scan.
2. **The project docs** (`.project/`) — `conventions.md`, `design-system.md`, `library-manifest.md`, `design-philosophy.md`. The authoritative spine.
3. **The stack's best practices** — the framework idioms and approved libraries, pulled from the driver's `domainSkills` (which the bootstrapper already wired) the same way the implementer cites them.

**Hard-grounding rule (load-bearing):** every finding cites a project-doc section, a `file:line`, or a `domainSkills` source. No imagined patterns, no vibes — same rule the triage/design reviewers already follow. This is also what keeps it bounded and fast: it reads the resolved project-docs (free, already in the brief) and greps only for what the diff touches.

## Analyze once, then distribute (token efficiency)

The orchestrator does the expensive work **once** and hands pre-digested slices to any subagent — it never makes each subagent re-read the docs, re-grep the repo, or re-derive the findings. Concretely: the orchestrator assembles the review context a single time (the diff, the resolved `.project/` sections, the relevant `domainSkills` pointers, the bounded diff-keyed grep results), produces the consolidated analysis (findings + proposals + grounding + heal routing) once, then:

- an **inline-fix** re-dispatch to the implementer gets just that finding + its citation + the exact file scope — not the whole analysis;
- the **large-drift handoff** to the feeder gets a tight brief of the adjustments — not the raw repo dump.

Same DNA as the driver's resolve-once block. Gather once, distribute slices.

## It heals, it doesn't gate

It is **not a merge gate.** It fixes what it reasonably can and reports the rest. Route purely by **drift size**:

- **Trivial → fixed inline.** Re-dispatch the implementer to fix it before the PR merges, exactly like `/code-review`'s in-scope loop.
- **Small / medium → new issues on the current milestone.** Captured and built later in the same run.
- **Large → a follow-up milestone.** Hand the adjustments to **`milestone-feeder`** as a brief; it plans + creates the follow-up milestone (well-formed issues, its own triage gate) and **kicks off `milestone-driver`**, which runs **after the active milestone finishes** — so you come back to *both* the milestone you expected *and* the supplemental one(s), done. Coherence never hand-authors the milestone; feeding the feeder gives the follow-up the same quality bar as any other.

The active issue/PR still merges either way — coherence never blocks it. Big concerns become captured, auto-built follow-up work, never a silent stop.

**Run length is not a routing signal.** How long the run has gone is a *context/resource* concern, owned by the driver — handled by subagent isolation, the analyze-once design, and compaction between issues — never by spilling work into a milestone. Coherence routes on drift size alone, so a long run never distorts where a fix lands.

## The recursion rule (why it can't loop forever)

Re-review is tied to **milestone granularity, not a counter**:

- Same-milestone fixes (small/medium) are **not** re-coherence-reviewed.
- A new follow-up **milestone** **is** re-reviewed — and that happens *by construction*, because it runs through the normal `feeder → driver` pipeline, which includes coherence. That's where real drift hides.

It self-terminates: each pass the drift is smaller, so within a round or two the findings land in the small/medium bucket, stay in-milestone, and stop triggering re-review. The geometry ends it, no hard cap needed.

## Communication is the actual product

The write-up lands in four places, but they are not equal:

- **Inline summary (primary).** Laid out so it's obviously worth reading and *not buried* — the headline, not a footnote. This is the thing the human actually reads.
- **Memory, the relevant issue comment, and the related PR comment (supplemental).** CYA / audit trail for later.

Per coherence call, in layman's terms: **what it did, why, the citations, and a ready `gh` one-liner** to spin up an issue if you'd rather do it differently. Shape:

> Implemented the responsive mobile nav as a hamburger menu. Instead of hand-rolling it, I used `<library>` — here's why and the docs I used: `<citations>`. Prefer a different approach? `gh issue create --repo <repo> --title "Revisit mobile nav implementation" --body "<scoped ask>"`

Keep it tight. The whole point of this tool is legible, un-buried communication — over-explaining defeats it.

## How it runs (and the driver companion change)

- **Standalone (v1, this repo).** `/milestone-coherence-reviewer:review <branch|PR>` — reviews the change, writes the report, and opens follow-up issues/milestone for fixes. Works with no driver changes. (Without the driver's build loop it can't re-dispatch the implementer, so "inline fix" degrades to "small issue.")
- **Embedded in the driver (v2, companion change in `milestone-driver`).** The full loop: dispatched at a new `solve-issue` step ~6.2 (after `/code-review` converges, before commit), read-only, returning findings + heal-route + the write-up. The **driver orchestrates the heal** (re-dispatch implementer for small / open current-milestone issues for medium / hand large adjustments to `milestone-feeder`, which builds the follow-up milestone and kicks the driver) — mirroring how triage/design-reviewer/implementer stay read-only while the orchestrator acts. Wired via a default-filled `coherenceReviewAgent` profile key, exactly like `triageAgent` / `designReviewAgent` / `implementerAgent`.

This repo ships the reviewer; the step-6.2 dispatch, the `coherenceReviewAgent` key, and the heal-orchestration are a **separate milestone-driver milestone** (flag it, don't try to build it here).

**New cross-plugin capability to flag (not yet built):** the automated `feeder → driver` handoff — the feeder creating a milestone and the driver then running it, after the active milestone completes, with no human in between — **does not exist today**. The feeder currently stops at `create`; a human runs the driver. That auto-run is its own companion change in the feeder/driver, on the same footing as the step-6.2 embedding. Standalone v1 can create the follow-up milestone via the feeder but **cannot auto-run the driver**; the fully-automated cycle is the embedded path.

## Integration — what it reads and which siblings it uses (from day one)

This plugin is useless without the suite's shared knowledge, so it wires in immediately rather than as an afterthought:

- **`.project/` (the project docs).** Reads `design-philosophy.md`, `conventions.md`, `design-system.md`, `library-manifest.md`, `environment.md` — the authoritative spine of every finding. It pulls cited sections through the driver's **resolve-once** mechanism (the `read-doc-section` primitive + the `projectDocs` key, default `.project/`) rather than re-reading whole files. Absent/`[TBD]` docs degrade cleanly (less grounding, not a crash) — same absent-means-skip convention as everywhere else.
- **`.milestone-config/` (the mechanics).** Reads the shared keys from `driver.json` — `sourceGlobs` (what counts as source), `uiSurfaceGlobs`, `integrationBranch`, `nonNegotiables`, and especially **`domainSkills`** (the stack's best-practice sources the bootstrapper wired) — resolving `.milestone-config/driver.json` first, root `milestone-driver.json` as fallback, exactly like the feeder. It does **not** duplicate these into its own config.
- **Sibling plugins.**
  - **`milestone-driver`** — orchestrates and dispatches it (embedded path), and supplies `domainSkills` for best-practice grounding. Coherence stays read-only; the driver acts.
  - **`milestone-feeder`** — the large-drift handoff target: coherence hands it a brief, the feeder builds the follow-up milestone and kicks the driver.
  - **`milestone-bootstrapper`** — indirect but load-bearing: it's what populated `.project/` and `domainSkills` in the first place, so coherence is only as sharp as the bootstrapper made the docs. Richer project docs → sharper coherence.
  - **`superpowers`** — a documented prerequisite installed separately, like the rest of the suite.
- **Graceful degradation + nudge.** Full power needs the driver + feeder present; standalone still works with whatever `.project/` / `.milestone-config/` it finds, falling back to bounded repo greps when the docs are thin. But when project docs are absent, it **says so and points to `milestone-bootstrapper`** rather than silently running on inferred conventions — suite principle D17: detect missing upstream setup and nudge (one-time, non-blocking), never silently proceed.

## Plugin packaging & distribution (follow suite conventions)

It's built autonomously, so the build must produce the standard scaffolding the siblings use — don't leave it implicit:

- **`.claude-plugin/plugin.json`** — the manifest and the **single source of version truth** (start at `0.1.0`). Mirror the siblings' shape: `name`, `version`, `description`, `author` (Ken Mulford / ken@kenmulford.com), `license` MIT, `repository`, `homepage`, and `keywords` (no `dependencies` field — `superpowers` is a documented prerequisite installed separately, not declared here). Register any hooks via `hooks/hooks.json` (likely none — it's read-only).
- **`.claude-plugin/marketplace.json`** — its **own individual marketplace**, so it stays installable on its own like every sibling: `name: milestone-coherence-reviewer`, `owner`, `metadata.description`, `allowCrossMarketplaceDependenciesOn: ["claude-plugins-official"]`, and a `plugins` entry `{ "name", "source": "./", "description", "category": "development", "tags" }`.
- **Versioning lives in `plugin.json` only.** `marketplace.json` carries **no `version` field** — Claude Code resolves `plugin.json` first, and setting both silently masks the marketplace value. (Suite convention, same as the driver.)
- **Companion change — list it in the suite catalog.** Add an entry to `kenmulford/milestone-suite`'s `marketplace.json` using the HTTPS `url` source (dev-tools decision D15): `{ "name": "milestone-coherence-reviewer", "source": { "source": "url", "url": "https://github.com/kenmulford/milestone-coherence-reviewer.git" } }`. That edit lands in the milestone-suite repo, so it's a companion change — not built here. The per-repo marketplace and the suite catalog coexist; both install paths stay valid.

## Recorded decisions (grounding)

- **Heals, never gates.** No merge-blocking. Routes the fix by **drift size only**: trivial → inline; small/medium → current-milestone issue; large → handed to `milestone-feeder`, which builds the follow-up milestone and kicks the driver after the active milestone completes (full cycle, automated). **Run length is a driver-side context concern (compaction / subagent isolation), not a coherence routing signal.** The `feeder → driver` auto-handoff is a new capability (companion change), not existing behavior.
- **Re-review only at new-milestone granularity.** Same-milestone fixes aren't re-reviewed; the loop self-terminates as drift shrinks.
- **Hard-grounding:** every finding cites a project-doc section, `file:line`, or `domainSkills` source — never an imagined pattern.
- **Bounded, not whole-repo:** project-docs are the spine; repo greps are diff-keyed.
- **Read-only agent, orchestrator acts** — the reviewer returns findings + proposals + write-up; the driver (or the standalone skill) performs the heal.
- **Analyze once, distribute slices.** The orchestrator builds the review context + findings a single time, then hands each subagent only its relevant slice — no subagent re-reads docs, re-greps, or re-derives. Mirrors the driver's resolve-once pattern; keeps token cost flat as findings fan out.
- **Inline write-up is the deliverable**; issue/PR/memory are the audit trail.
- **Ship standalone first**, embed in the driver second (companion driver change).
- **Packaging follows suite conventions.** Own `plugin.json` (version source of truth, start `0.1.0`) + own `marketplace.json` (**no `version` field**); also cataloged in `milestone-suite` via an HTTPS `url` source (companion change). Both install paths kept.
- It may **propose** a new entry for `conventions.md` when it spots a deliberate repeated pattern (≥3 consistent ungoverned sites, or a disagreeing ungoverned cluster with a recommended winner). The tool proposes the entry via a **human-gated, config-only PR** to the integration branch — never the protected branch, never application code. *Propose, never rewrite* still holds in spirit: it never force-writes `conventions.md`; the human gates the PR, and `.project/` is config the tool may author via that gated PR. (The branch-name and gate mechanics are owned by `skills/review/SKILL.md`.)
- **Nudge on missing upstream (D17).** If project docs / config are absent, surface a one-time, non-blocking notice to run `milestone-bootstrapper` (and that the feeder produces its input) rather than silently degrading.

## Non-goals

- Not correctness (`/code-review`), not pre-build design (triage), not visual/UX (design-reviewer + visual gate).
- Not a merge gate / hard stop.
- Doesn't scan the whole repo every run.
- Doesn't rewrite app code on its own beyond the size-routed heal, and doesn't force-write project **prose** docs — but it **may open a config-only PR** proposing a `.project/conventions.md` entry (human-gated, targeting `integrationBranch`; `.project/` is config the tool may author via a gated PR). It still never rewrites application code, never force-pushes, and never touches the protected branch.

## Constraints

- Honor the suite DNA and the concise output style; the write-up especially must be legible and un-buried.
- Cross-platform hooks/scripts if any (bash-first / PowerShell-7 fallback).
- Reads project-docs via the driver's resolve-once mechanism and `domainSkills`; doesn't duplicate the driver's shared keys.

## Sequencing hints

- The review engine (sources + hard-grounding + the write-up format) is the spine; everything else depends on it.
- Standalone `review` entry first (shippable alone), then the driver-embedded path.
- Heal routing (size buckets) and the follow-up-milestone authoring come after the review engine produces findings.

## Definition of done

Running it on a built change produces a **grounded, legible report** — what fits, what doesn't, why, with citations and copy-paste `gh` one-liners — and routes fixes by drift size (trivial inline / small-medium current-milestone issue / large fed to the feeder, which builds the follow-up milestone and the driver runs it after the active milestone completes) without ever blocking the merge. Standalone works on its own; the driver-embedded path and the `feeder → driver` auto-handoff are specified for their companion milestones.
