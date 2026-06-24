# Design philosophy

<!--
Part of your project docs (.project/). Tools read and cite this file as
`.project/design-philosophy.md#<section>`. Fill every [TBD]. A section left as
[TBD] is treated as "not specified" — tools fall back to inferred repo
convention rather than ground on a placeholder. Humans own this file; tools may
*propose* changes but never rewrite it. Keep the ## headings stable — they are
citation anchors. Add new sections by appending, not renaming.
-->

## Architectural stance
What kind of system is this, and what does it fundamentally optimize for?
> A read-only, post-build **coherence** reviewer: after a change is built, it checks whether the change fits how the app is already built and *heals* what it safely can rather than gating. It is the missing review layer between triage (pre-build design), `/code-review` (correctness), and the visual gate (UI renders). Optimizes for legible, un-buried communication and hard-grounded findings over verdicts. (BRIEF.md §"What it is" l.9-23, §"Communication is the actual product" l.63-74.)

## Layering & boundaries
The layers and the allowed dependency directions — what may depend on what, and what must never.
> **Read-only engine ↔ orchestrator split.** The `coherence-reviewer` agent RETURNS findings only — it writes no files, opens no issues, runs no `gh`, never edits the repo, and never touches the protected branch. The `review` skill (the orchestrator) performs the heal. Coherence reads the suite's shared mechanics from `.milestone-config/driver.json` **in place** (never duplicating them) and reads `.project/` sections via the installed driver's `read-doc-section` primitive (wired, not reimplemented). (BRIEF.md §"Recorded decisions" l.113, §"Integration" l.89-90; agents/coherence-reviewer.md "Read-only"; skills/review/SKILL.md "Invariants".)

## What we optimize for
Ranked priorities, and the explicit non-goals that follow from them.
> 1) **Hard-grounded findings** — every finding cites a `.project/` section, a repo `file:line`, or a `domainSkills` source; an ungroundable finding is dropped, never a vibe. 2) **Legible, tight, un-buried communication** — the inline write-up is the deliverable, not the verdict. 3) **Bounded and fast** — project docs are the spine, repo greps are diff-keyed, analyze-once distributes slices to keep token cost flat under fan-out.
>
> Non-goals: correctness (`/code-review`), pre-build design (triage), visual/UX (design-reviewer + visual gate), being a merge gate, whole-repo scans, and rewriting project docs or app code beyond the size-routed heal. (BRIEF.md §"Hard-grounding rule" l.31, §"Non-goals" l.121-126, §"Constraints" l.128-132.)

## One-way doors
Decisions that require human sign-off *before* they're made — irreversible or expensive-to-reverse choices.
> - **Adding a dependency** — the suite stays dependency-light (`jq` on bash, PowerShell `ConvertFrom-Json` on pwsh; no new dependency introduced).
> - **Changing `.claude-plugin/plugin.json` `version`** — the single source of version truth.
> - **Altering the read-only-engine / orchestrator-acts boundary.**
> - The cross-plugin companion changes (the driver step-6.2 embedding, the feeder→driver auto-handoff) are out-of-repo and **tracked, not built here**. (BRIEF.md §"How it runs" l.79-83, §"Plugin packaging" l.102-105; docs/resolution.md §"Dependency note".)

## Error & failure philosophy
How the system handles and surfaces failure: fail-open vs fail-closed, the user-facing error policy, logging expectations.
> **Fail-soft / absence-means-skip.** Thin or absent `.project/`, an absent driver profile, a missing `domainSkills`, or an unavailable write-up mirror all degrade grounding and are reported — never a crash and never a merge block. The one surfaced-not-skipped condition is a present-but-invalid config (`ERROR malformed-config`, exit 3): surfaced to stderr and as a record, never replaced with fabricated values, and the run still continues. A missing/unresolvable `review` argument is the only error-and-stop — it writes nothing, opens nothing, and leaves the merge untouched. Coherence heals; it never gates. (docs/resolution.md §"Degradation matrix" + "Exit codes"; agents/coherence-reviewer.md §"Graceful degradation"; skills/review/SKILL.md §"Missing or unresolvable argument".)

## Testing philosophy
What we test, at what level, and what "verified" means before a change is done.
> Built via the `feeder → driver` dogfood loop with `/code-review` per PR. The cross-platform script twins are verified **byte-for-byte identical** between the bash and PowerShell hosts (`resolve-config`, `memory-mirror`). The "verified" bar is documented-contract conformance plus bash/pwsh parity — not a unit-test suite, because this is a markdown + shell plugin, not compiled code. (CHANGELOG.md v0.1.0 table + "Post-run audit trail"; docs/resolution.md §"Section-body trailing blank lines".)
