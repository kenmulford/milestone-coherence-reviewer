# The proposal PR — authoring a `.project/conventions.md` entry as a config-only PR

This is the **single copy** of the convention-proposal authoring machinery: the suppress rule, the dedupe rule, the act→verify→retry→post-create-verify→dedupe-recheck sequence, and the skipped-and-noted fallback. `skills/review/SKILL.md` §"Step 3" and `skills/sweep/SKILL.md` §"Step 3" both carry a pointer here and **no copy** — the same single-source discipline `docs/heal-routing.md` holds for the route table.

**Scope.** This document owns *how a proposal becomes a PR*. It does not own what the engine proposes (`agents/coherence-reviewer.md` §"Convention proposals"), how the proposal renders in the write-up (`docs/write-up.md` §"Proposed convention"), or drift routing — a proposal is **not** a drift fix and never enters the severity buckets (`docs/heal-routing.md` §"Convention proposals are a separate lane").

## Who acts

The **orchestrator** authors the entry and opens the PR. The engine is read-only: it returns the `PROPOSALS` block and acts on nothing (`agents/coherence-reviewer.md`; `BRIEF.md` l.113).

## Ordering

This runs **before** the write-up renders, by design, so each proposal's PR is already live when the write-up names it — the numbered order matches the data dependency, and no step renders an artifact a later step produces.

`PROPOSALS: none` → skip entirely; there is nothing to author.

## 1. Suppress on a degraded repo — decided BEFORE any render

If `.project/conventions.md` is absent (`SIGNAL no-doc-grounding`), **suppress every proposal** and surface the one-time **D17** `milestone-bootstrapper` nudge instead. Never flood proposals against conventions the tool merely inferred — a proposal needs a real `conventions.md` to extend (`BRIEF.md` l.96, l.119).

Decided here, before the write-up renders, so the write-up never renders a proposal that then gets suppressed.

## 2. Dedupe — match deterministically, never fuzzily

Skip the proposal when **either** holds:

- an open PR already exists on the **exact** head branch `chore/propose-<slug>` — `gh pr list --state open --head "chore/propose-<slug>" --json number`, or the `git ls-remote --heads origin "chore/propose-<slug>"` fallback; **or**
- `.project/conventions.md` **already carries that `## heading`** — an exact-heading scan.

Match on the exact head branch and the exact heading. **Never** a fuzzy full-text `--search`: it false-positives on an unrelated PR that merely mentions the slug, and misses a reworded duplicate.

The engine may hint at a likely duplicate; the orchestrator enforces the dedupe (`agents/coherence-reviewer.md` §"Convention proposals" — Suppress).

## 3. Write the entry and open the PR

Act → verify → retry once → post-create verify → dedupe re-check. For each surviving proposal:

| Step | How |
|---|---|
| cut the branch | `chore/propose-<slug>` off `integrationBranch` — `<slug>` is the kebab-cased `heading`; **never** off `protectedBranch` |
| write the entry | append to `.project/conventions.md`, mirroring the existing shape (`.project/conventions.md` header comment): a stable `## <heading>` + a `> <rule>` blockquote + the `exemplar` `path:line`; optionally a row in the "Canonical exemplars" table. When `disagree: yes`, the `rule` recommends the grounded winner and the entry notes the `diverging` sites |
| commit | Conventional Commits with the PR-number suffix — e.g. `chore: propose conventions.md#<heading> (#<pr>)` (`.project/conventions.md#"Commits & PRs"`) |
| open the PR — **attempt** | `gh pr create --base <integrationBranch> …` — a **config-only PR to `integrationBranch`**, **NEVER** `protectedBranch` |
| **verify** the attempt | `gh pr view <branch> --json number` — confirm the PR now exists |
| on a **failed** attempt | run `gh auth status` (surfaces an auth problem rather than masking it), then **retry the create exactly once**, then verify again. The retry budget is exactly one extra attempt — **never** an unbounded loop |

### Post-create content verify

On a verified-successful create (first attempt or retry), confirm before treating the PR as live that its diff touches **exactly** `.project/conventions.md` and carries the expected `## <heading>`.

| Outcome | What happens |
|---|---|
| verified, no duplicate | treat this PR as the proposal's **live link** — the happy path |
| verified, but a **duplicate** now exists (a second open PR on the exact head branch, or `conventions.md` already carries that exact `## heading`) | re-run the **same** dedupe match from §2 — never a new or fuzzy rule. The **earlier-existing** PR is authoritative: close this run's just-created PR (`gh pr close <this-run's-PR>` with a short comment noting the duplication) and render a note about the closed duplicate in place of a second link. **Never** two rendered links |
| content verify fails for a **non-duplicate** reason (diff doesn't touch exactly `.project/conventions.md`, or lacks the expected heading) | fall through to §4 — surface it, never crash, and never silently treat a malformed PR as the live link (`.project/design-philosophy.md#Error & failure philosophy`) |

If the retry **also** fails (verify still finds no PR) → fall through to §4.

The human **merges to accept**, **closes to reject** the surviving, verified PR.

## 4. Failure is skipped-and-noted — never a crash, never a gate

The shared terminal fallback for all three failure classes:

| Class | Example |
|---|---|
| pre-create | branch-cut, write-the-entry, or commit failure — auth, network, a protected `.project/` path. No retry applies to these |
| create | `gh pr create` fails on both the initial attempt and the retry |
| post-create | a non-duplicate content-verify failure |

Each is **skipped and noted**, exactly like the write-up's mirror-degradation pattern (`docs/write-up.md` §"Graceful degradation"). It never crashes the run and never gates the merge (`BRIEF.md` l.89). The write-up then renders the skipped-and-noted failure in place of that proposal's PR link. **The change under review merges regardless.**

## The sweep delta

`skills/sweep/SKILL.md` §"Step 3" uses this machinery **unchanged** but for one field: in sweep-mode a proposal carries `source: sweep`, where the `review` path carries `source: per-change`. Everything above — suppress, dedupe, the create sequence, the fallback — is identical on both paths.

## Invariants

- **Config-only.** The PR touches `.project/conventions.md` and nothing else. It never edits application code and never creates an application-code branch.
- **Never the protected branch.** The branch is cut off `integrationBranch` and the PR targets `integrationBranch`. `protectedBranch` is never a base and never a push target.
- **Human-gated.** The orchestrator opens the PR; a human merges or closes it. Nothing here self-merges.
- **Never a gate.** No failure in this lane blocks the change under review from merging.
- **Read-only engine preserved.** The engine returns the proposal; the orchestrator opens the PR. The `gh` writes are the skill's, so the read-only-**engine** invariant holds.
