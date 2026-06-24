---
name: review
description: This skill should be used when the user invokes "/milestone-coherence-reviewer:review <branch-or-PR>", or asks to "review this change for coherence", "check whether this branch fits the app", or "coherence-review this PR". Reviews one built change for fit with how the rest of the app is already built — resolves the shared config + project docs, runs the read-only review engine through the analyze-once orchestration, writes a legible inline write-up (mirrored to memory + the issue/PR), and routes fixes by drift size (trivial → a small-issue note, small/medium → current-milestone issues, large → a brief to milestone-feeder). Read-only on the merge: it heals via follow-ups and NEVER blocks, gates, or touches the merge or the protected branch. Authors no application code; opens no PRs.
---

# review — the standalone coherence reviewer

Review one built change — a branch or a PR — for whether it **fits how the app is already built**: existing helpers and patterns, your conventions, the stack's idioms. Resolve the shared config + `.project/` docs once (#2), gather the review context once and dispatch the read-only review engine (#3) through the analyze-once orchestration (#4), render the legible write-up (#5) inline and to its mirrors, then route each fix by drift size (#6). This is the **standalone v1 entry** — it works with no `milestone-driver` changes.

This skill is the **orchestrator**. The review engine (`agents/coherence-reviewer.md`) is **read-only** — it returns findings; this skill performs the heal. The heal is healing, never gating: it fixes what it reasonably can and reports the rest, and **the change it reviewed merges either way** (`BRIEF.md` §"It heals, it doesn't gate" l.42-52). It opens follow-up issues / a follow-up milestone for the fixes it cannot apply; it never blocks, gates, or touches the merge, and it never writes to or force-pushes the protected branch (`BRIEF.md` l.50, l.125-126).

## Announce first

Say this to the user before doing any work:

> Standing by while I review the built change for coherence — does it fit how the rest of the app is already built? This is **read-only on the merge**: I heal small drift by filing follow-up issues (or handing large drift to `milestone-feeder` for a follow-up milestone), and I **never block, gate, or touch the merge or your protected branch** — the change merges either way. You'll get a short inline write-up of what fits, what doesn't, why, with citations and a copy-paste `gh` one-liner to redo anything differently.

## Argument handling — one positional argument, detected by form

The skill takes a **single positional argument** — a branch name or a PR — passed as `$ARGUMENTS`. It is **string-substituted, not CLI-parsed**: do **not** treat it as a validated flag (`--branch` / `--pr`). **Detect its form** the same way the feeder detects its brief's form (`milestone-feeder/skills/plan/SKILL.md:182-188`):

| Form | Detection | Resolve the change via |
|---|---|---|
| **PR** | `$ARGUMENTS` is `#<n>`, a bare integer, or a PR URL | `gh pr view <n> --json number,title,headRefName,headRefOid,state` — its head branch is the change under review |
| **Branch** | otherwise — a ref name that resolves | `git rev-parse --verify <ref>` (local), else `git rev-parse --verify origin/<ref>` (remote) |

The branch/PR resolves the **change under review**; the diff is taken against `integrationBranch` (from #2, default `develop`) at Step 2.

### Missing or unresolvable argument — a 🔴 error-and-stop (no crash, no report)

A **missing** argument (`$ARGUMENTS` empty), or one that does **not resolve** (no such branch locally or on the remote, no such PR), is a **🔴 error-and-stop**: name the input and give the correct invocation, then **end the run** — do **not** crash, do **not** write a report, do **not** open anything. Model this on the feeder `update`'s 🔴 error-and-stop for a not-found target (`milestone-feeder/skills/update/SKILL.md:10` — "milestone-not-found is a 🔴 error-and-stop directing the user to ..."); there is no "print usage" idiom in the siblings.

Print this verbatim (substitute the offending input):

```
🔴 review — cannot resolve the change to review

| What | <"No branch or PR was given." | "The branch or PR `<input>` does not exist.">
| Fix  | Invoke with one branch or PR to review:
|      |   /milestone-coherence-reviewer:review <branch-or-PR>
|      | e.g. /milestone-coherence-reviewer:review feature/mobile-nav
|      |   or /milestone-coherence-reviewer:review #42
| Note | Nothing was written — no report, no issue, no comment. Your merge is untouched.
```

Then **STOP**. This is the only condition under which the run produces no write-up.

## Procedure

### Step 1 — Resolve config + project docs (drive #2; degrade cleanly)

Resolve the suite's shared mechanics and the cited `.project/` sections by **driving the resolution layer** (`scripts/resolve-config.{sh,ps1}`, #2) — do **not** re-implement it, and do **not** read whole docs (`docs/resolution.md`; `BRIEF.md` l.89-90). Pick the host the same way the rest of the suite does: **pwsh on Windows, bash elsewhere** (the host selection mirrored across `scripts/resolve-config.{sh,ps1}` and the suite's `ci-preflight-steps.{sh,ps1}`).

1. **Resolve the shared keys** (the driver.json → root `milestone-driver.json` fallback is *inside* #2 — you do not re-implement it):

   ```
   scripts/resolve-config.<sh|ps1> keys <REPO_ROOT>
   ```

   Parse the TAB-separated record stream once and cache it (resolve-once — `docs/resolution.md` §"Resolve-once contract"). Reverse the `KEY`-value encoding in the documented order — `\t`→TAB, then `\n`→newline, then `\\`→`\` (`docs/resolution.md` §"Record-value encoding"). You consume these keys: `sourceGlobs` (the only paths the engine greps for app grounding), `uiSurfaceGlobs`, `integrationBranch` (the diff base), `nonNegotiables`, and **`domainSkills`** (the stack's best-practice sources). A key absent from a present config arrives as `SKIP key …` — it is skipped, never invented.

2. **Resolve the cited `.project/` sections.** From the change under review (its issue/PR body and the surfaces it touches), collect the cited `.project/<doc>#<section>` anchors, then resolve them in one call (everything after `--` is a `<doc>#<heading>` spec; `<heading>` is the heading text **without** leading `#`s):

   ```
   scripts/resolve-config.<sh|ps1> docs <REPO_ROOT> -- conventions.md#"Service layer" design-system.md#Buttons …
   ```

   Each resolved section arrives as a verbatim `SECTION-BEGIN … SECTION-END` payload; cache them as the engine's project-docs slices. Absent / `[TBD]` / empty sections arrive as `SKIP section …` and are simply omitted.

3. **Degrade cleanly — never error on absent docs/config** (`BRIEF.md` l.89, l.96; AC: degraded environment). The records #2 emits drive the fallback:

   | Signal from #2 | What it means | What this skill does |
   |---|---|---|
   | `SIGNAL no-config` | neither `.milestone-config/driver.json` nor root `milestone-driver.json` | the engine grounds on bounded diff-keyed greps only; `sourceGlobs` is unknown, so default the grep scope conservatively to the diff's own paths |
   | `SIGNAL no-doc-grounding` | no `.project/`, no driver primitive, or nothing resolved | run with **no** project-docs grounding (reduced grounding, not an error); the engine falls back to bounded greps + `domainSkills` |
   | `ERROR malformed-config …` (exit 3) | a present-but-invalid config | surface the `ERROR` record in the write-up's grounding note; continue best-effort (it is reported, never fatal) |

   In **every** degraded case the run still proceeds (`BRIEF.md` l.89). Absence reduces grounding; it never aborts the review.

4. **Nudge on missing upstream (D17, one-time, non-blocking).** When `SIGNAL no-doc-grounding` (or `no-config`) is raised, note once in the write-up's grounding section that the project docs/config are thin and point to `milestone-bootstrapper` (it populates `.project/` and `domainSkills`) — a one-time, non-blocking notice, never a silent degrade and never a stop (`BRIEF.md` l.96, l.119). This nudge belongs to this skill, not to the read-only engine (`agents/coherence-reviewer.md` "Read-only — what you produce and what you never do").

### Step 2 — Gather the review context ONCE and dispatch the engine (analyze-once, #4 → #3)

Build the review context a **single time** per review call, then dispatch the engine **once** against it (`docs/analyze-once.md` Steps 1-2; `BRIEF.md` l.35-40). Nothing below is re-read, re-resolved, or re-derived after this point.

1. **Assemble the review context (once)** — its four parts (`docs/analyze-once.md` Step 1):

   | Part | Source |
   |---|---|
   | the built diff | the resolved branch/PR head **against `integrationBranch`** (`git diff <integrationBranch>...<head>`) — and the symbols/patterns it introduces |
   | the resolved `.project/` sections | from Step 1 (verbatim `SECTION-BEGIN … SECTION-END` slices) — read once |
   | the `domainSkills` pointers | from Step 1's `KEY domainSkills …` records — read once |
   | the bounded, diff-keyed grep results | greps within `sourceGlobs` for the specific symbols the diff introduces — **never** a whole-repo scan (`BRIEF.md` l.27, l.112) |

2. **Dispatch the read-only engine once** (`agents/coherence-reviewer.md`, #3) against that context — it is the consolidated analysis. Brief it with exactly the four context parts above (its "What you receive"); it returns its structured `FINDINGS` block and nothing else. **Do not** make the engine re-read whole docs or re-resolve the shared keys (`docs/analyze-once.md` Step 2; the engine stays read-only and acts on nothing). The engine's block carries `REVIEWED`, the three `SOURCES` lines, and per-finding `symbol` / `lens` / `grounding` (exactly one ref) / `severity` (the drift-size hint) / `description`.

3. **`FINDINGS: none` is a clean terminal** (`docs/analyze-once.md` §"Zero-findings — a clean terminal"; `agents/coherence-reviewer.md` l.94, l.102). Nothing to distribute, nothing to route. Skip Step 4's routing entirely and render the clean-fit write-up at Step 3 below. This is the success case, not an error — and `FINDINGS: none` with degraded `SOURCES` lines (thin grounding) is still a clean terminal.

### Step 3 — Render the write-up (#5): inline PRIMARY, then the supplemental mirrors

Render the write-up **entirely** from the engine's single `FINDINGS` block (`docs/write-up.md` §"What the write-up renders from"). Never re-grep, re-read a doc, or re-derive a finding; never add a claim no field backs.

1. **The inline summary is the PRIMARY deliverable — always produced, never buried** (`docs/write-up.md` §"Four landing places, two tiers"; `BRIEF.md` l.67). Per finding, in order: **what it did** (`description` + `symbol`) · **why** (the `lens`) · **the citations** (the single `grounding` ref, verbatim) · **a copy-paste redo one-liner**:

   ```
   gh issue create --repo <owner/name> --title "Revisit <the change>" --body "<scoped ask + the finding's grounding ref>"
   ```

   This reuses the suite's issue-create primitive (`docs/write-up.md` §"The gh issue create redo one-liner"; convention `milestone-feeder/skills/create/SKILL.md:182`). Keep it **tight** — one short item per finding, what/why/citation/one-liner, never an essay; the output does not balloon as findings fan out (`docs/write-up.md` §"Tight and legible"; `BRIEF.md` l.74).

2. **Clean-fit (`FINDINGS: none`) still produces a write-up — never silence** (`docs/write-up.md` §"The empty / clean-fit state"). Render a positive "**Fits cleanly — nothing changed**" headline that states **what was checked** (read from the `SOURCES` lines — which of app-grep / project-docs / domain-skills were available, so a genuine clean fit reads distinct from a thin-grounding run). No per-finding items, no redo one-liners — there is nothing to redo, and nothing is opened.

3. **Mirror the same content to the three supplemental audit-trail copies — each best-effort, each degrading without suppressing the inline summary** (`docs/write-up.md` §"Graceful degradation"; `BRIEF.md` l.68). Render the mirrors as copies of the *same* write-up — never its canonical home:

   | Mirror | How (pick the host: pwsh on Windows, bash elsewhere) | Skip-and-note when |
   |---|---|---|
   | **memory** | `scripts/memory-mirror.<sh|ps1> --slug <issue-or-pr-slug> --repo-root <REPO_ROOT> --file <write-up>` (detect-or-fallback, #5) | the helper prints `MIRROR-FAILED …` / exits nonzero — note the failure, continue |
   | **the issue comment** | `gh issue comment <n> --body "<write-up>"` | no resolvable issue context — note "issue mirror skipped", continue |
   | **the PR comment** | `gh pr comment <pr> --body "<write-up>"` | no PR exists yet — note "PR mirror skipped — no PR", continue |

   A failed or unavailable mirror is **skipped and noted**, never raised; only the unavailable mirror is skipped — the inline summary and every reachable mirror are still produced (`docs/write-up.md` §"Graceful degradation"). The memory mirror is the `scripts/memory-mirror.{sh,ps1}` helper's detect-or-fallback — you do not pick the target yourself; the helper resolves it (a configured store, else a git-invisible file under `.milestone-config/.runtime/`).

### Step 4 — Route each fix by DRIFT SIZE (enact #6, standalone mode)

For each finding, route on its `severity` field **and nothing else** — not run length, not finding count, not token budget (`docs/heal-routing.md` §"The single routing key"; `BRIEF.md` l.52, l.109). This run is **standalone mode**, so the `drift-trivial` route degrades (there is no driver build loop to re-dispatch the implementer into). Each route's slice is the minimal, self-contained #4 slice — never the whole analysis (`docs/analyze-once.md` §"Self-contained or it doesn't ship").

| `severity` | Route (standalone) | Destination |
|---|---|---|
| `drift-trivial` | **degrades to a small-issue note** — no build loop to re-dispatch the implementer (`BRIEF.md` l.78) | a new issue on the **current** milestone, carrying the finding + its grounding |
| `drift-small` | **new issue** | a new issue on the **current** milestone |
| `drift-medium` | **new issue** | a new issue on the **current** milestone |
| `drift-large` | **hand a brief to `milestone-feeder`** — the [large-drift slice](../../docs/analyze-once.md): a tight adjustments brief with citations, never a raw repo dump | `milestone-feeder` plans + creates the follow-up milestone (its own triage gate) |

1. **Small / medium / standalone-degraded trivial → a current-milestone issue.** Open it via `gh issue create` (the same primitive as the write-up's redo one-liner), carrying the finding's `description` + `symbol` and its single `grounding` ref so the issue starts hard-grounded. These same-milestone fixes are **not** re-coherence-reviewed (`docs/heal-routing.md` §"Same-milestone fixes are not re-reviewed").

2. **Large → a brief to `milestone-feeder`.** Hand the feeder the large-drift slice (the synthesized adjustments + the grounding refs + the drift scope — `docs/analyze-once.md` §"The large-drift slice"). The feeder plans + creates the follow-up milestone with its own triage gate; this skill **authors no milestone by hand** (`docs/heal-routing.md` §"`drift-large` → a brief to `milestone-feeder`"; `BRIEF.md` l.48).

3. **The deferred boundary — state it, do NOT cross it.** After the feeder creates the follow-up milestone, **standalone v1 CANNOT auto-run `milestone-driver`** — the `feeder → driver` auto-handoff does not exist today and is a separate companion change (`docs/heal-routing.md` §"The deferred boundary"; `BRIEF.md` l.83, l.141). **State this in the write-up** so the reader knows the follow-up milestone is created but **not yet auto-built** — a human runs the driver on it. End cleanly; do not present the driver as if it will pick the milestone up automatically.

4. **`FINDINGS: none` → route nothing.** Open no issue, hand nothing to the feeder, re-dispatch no one (`docs/heal-routing.md` §"Empty / zero-findings"). The write-up already reported the clean fit at Step 3.

### Step 5 — End cleanly

Surface the inline write-up as the run's deliverable, with a flat summary of what was routed where (which mirrors landed, which were skipped-and-noted, which issues/milestone were opened, and — when a large-drift milestone was created — the deferred-boundary note). The review run ends. **The change merged regardless of any of the above** — coherence heals, it does not gate.

## Invariants (always true, every path)

- **Never blocks, gates, or touches the merge.** The router produces no hard stop and no merge-blocking verdict, for **every** drift size and **every** path; the active change merges either way (`docs/heal-routing.md` §"Never a gate"; `BRIEF.md` l.42-44, l.50, l.125).
- **Never writes to or force-pushes the protected branch.** This skill opens issues / hands the feeder a brief and writes comments + a memory mirror — it edits **no** application code, creates **no** branch, force-pushes nothing, and never touches the protected branch (`protectedBranch` in the driver profile; `BRIEF.md` l.126).
- **Degraded environment still runs.** Thin/absent `.project/` or absent `.milestone-config/` is never an error — fall back to bounded diff-keyed greps with reduced grounding, and nudge toward `milestone-bootstrapper` once (`BRIEF.md` l.89, l.96).
- **The inline write-up is the deliverable.** Memory, the issue comment, and the PR comment are supplemental audit-trail copies; an unavailable mirror is skipped and noted, never allowed to suppress the inline summary (`docs/write-up.md`; `BRIEF.md` l.68, l.115).
- **Analyze once, distribute slices.** The context is gathered once and the engine dispatched once; each downstream route gets only its minimal, self-contained slice — never a re-gather, re-analyze, or re-resolve (`docs/analyze-once.md`; `BRIEF.md` l.114).
- **Read-only engine, orchestrator acts.** The engine returns findings; this skill performs the heal. The engine never heals, writes files, opens issues, or runs `gh` (`agents/coherence-reviewer.md`; `BRIEF.md` l.113).

## Output style

Be concise — report status and outcomes flatly, no wall-of-text. Present steps, gates, lists, and options as **tables**, not inline prose. Mark anything that needs a human with 🔴. The inline write-up is the un-buried headline a human reads; keep it tight (over-explaining defeats the tool). (Mirrors the siblings' communication-style contract — `milestone-feeder/skills/plan/SKILL.md:585-587`, `milestone-driver/skills/triage/SKILL.md:419-421`; `BRIEF.md` l.63-74, l.129-130.)

## Non-negotiables

- **Never a merge gate.** The review is post-build and read-only on the merge: it heals what it reasonably can and reports the rest, and the change it reviewed merges regardless of any finding, drift size, or route. It never blocks, gates, or emits a "do not merge" verdict (`BRIEF.md` l.42-44, l.50, l.124).
- **Never touches the protected branch.** It writes no application code, creates no branch, force-pushes nothing, and never writes to or force-pushes the protected branch. Its only writes are follow-up issues, a feeder brief, comment/memory mirrors (`BRIEF.md` l.126).
- **Read-only engine; the orchestrator acts.** The `coherence-reviewer` engine is dispatched read-only and returns findings only; this skill performs the heal. The engine opens no issue, posts no comment, runs no `gh` (`agents/coherence-reviewer.md`; `BRIEF.md` l.113).
- **Analyze once, distribute slices.** The review context is assembled once and the engine dispatched once per review call; downstream routes get minimal self-contained slices — no re-gather, re-analyze, or re-resolve (`docs/analyze-once.md`; `BRIEF.md` l.35-40, l.114).
- **Routes on drift size alone.** Every fix routes on the engine's `severity` and nothing else — never run length, finding count, or token budget (`docs/heal-routing.md`; `BRIEF.md` l.52, l.109).
- **Hard-grounding carries through.** Every routed issue and every write-up item carries the finding's real grounding ref (a `.project/` section, a `file:line`, or a `domainSkills` source) — never a fabricated or imagined one; the engine already dropped any ungroundable candidate (`agents/coherence-reviewer.md` §"The hard-grounding rule"; `BRIEF.md` l.111).
- **Degrades, never errors, on absent grounding.** Thin/absent `.project/` or absent `.milestone-config/` reduces grounding and triggers the one-time `milestone-bootstrapper` nudge — it never aborts the run (`BRIEF.md` l.89, l.96, l.119).
- **The deferred boundary is documented, not crossed.** Standalone v1 can create a follow-up milestone via the feeder but **cannot auto-run `milestone-driver`**; the run states this boundary in the write-up and ends cleanly (`BRIEF.md` l.83, l.141; `docs/heal-routing.md` §"The deferred boundary").
- **Authors no application code, opens no PRs.** It reads the diff and the repo to ground findings; it never edits a source file or opens a PR. The `gh` writes (issues, comments) are performed by the skill itself, so the read-only-engine invariant holds.
