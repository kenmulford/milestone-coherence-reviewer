# Changelog

Notable changes to the **milestone-coherence-reviewer** plugin, newest first. (Built on `develop` via the `feeder → driver` dogfood loop.)

## v0.4.0 — consumer-shaped spin-out issues

**Theme:** spin-out issues stop imposing this plugin's house style and adopt the consumer repo's own issue-template convention — without ever inferring what an unknown field means, and without letting a template's shape gate or lengthen a finding. Shipped alongside a release-hygiene sweep that removed the hand-maintained version text and stale inventories the docs had accumulated.

### ✨ Consumer-shaped spin-out issues

| Issue | PR | What |
|---|---|---|
| #81 Compose heal-routing spin-out issues to the consumer repo's issue template | #94 | The Step 5 spin-out now shapes its body to the consumer's `.github/ISSUE_TEMPLATE/`. A **4-rung resolution ladder** (`agentIssueTemplate` profile key → exactly one template → built-in shape → absence never blocks) resolves **once per run, repo-wide**. **Three emission modes**, chosen by which rung matched — because the rung is what determines whether the template's shape is known to the suite: **A** stock/keyed translates every non-`markdown` field to `## <label>` in `body:` order; **B** consumer-owned emits the first `textarea`'s label and the built-in body under it, nothing else; **C** `.md` is used as a skeleton directly. Modes A and C mirror `milestone-feeder#331`. Mode B deliberately diverges: inferring which arbitrary field means "evidence" is the guess this engine declines everywhere else (`agents/coherence-reviewer.md:58`), and letting a consumer's field count drive body length would break the flat-cost rule at `docs/write-up.md:255`. The contract is a single source, `docs/issue-templates.md`, with a lean pointer from `skills/review/SKILL.md:187` — the `docs/heal-routing.md` pattern. |
| — Design spec | #93 | The recorded design behind #94, in `docs/superpowers/specs/2026-07-20-template-shaped-spin-out-design.md`. Also records a defect found in the companion issues: `milestone-bootstrapper#156` provisions **two** stock templates while `milestone-feeder#331` falls back to the built-in default at **two or more**, so a bootstrapped repo would have received the stock set and then had every agent ignore it. Fixed by having `#156` record *which* template agents author to, rather than making selection a count problem. Both companion issues were commented; neither is built here. |

### 🔧 Release hygiene

| Issue | PR | What |
|---|---|---|
| #82 Bump plugin version to 0.4.0 | #89 | Minor bump (feature-additive), plus the CI-guarded `.project/conventions.md` citation that must track it. Corrects #68's acceptance criterion, which claimed the diff should touch only `plugin.json` — its own merged PR had to move the citation anyway. Demonstrated by a red→green run rather than asserted. |
| #83 Stale-proof the hand-maintained version literals | #90 | `CHANGELOG.md`'s standing header claimed "v0.1.0 released" directly above a `## v0.3.0` section; `README.md`'s Status line opened with a version literal that would go wrong the moment `0.4.0` shipped. Both removed in favor of the `CHANGELOG.md` pointer the sentence already carried. The three parenthetical attributions — `(v0.2.0)`, `(v0.2.1)`, `(v0.3.0)` — are retained deliberately: they are historical facts about when features landed and do not drift. `README.md:59`'s "no longer" framing restated as the standing fact. |
| #84 Refresh `.project/` inventories | #91 | `conventions.md`'s inventories and `design-philosophy.md`'s verification claim were written at v0.1.0 and never maintained: `skills/` named only `review` (sweep shipped v0.2.0), `docs/` enumerated four files of six, `scripts/` claimed all twins when three are CI-only bash, `.github/` was absent, and §"Test patterns" asserted "None" while `check-size-budgets.test.sh` runs in CI. All reconciled. `docs/` is now **described rather than enumerated** — the enumeration is what drifted, twice. This matters beyond tidiness: the engine grounds its findings in resolved `.project/` sections, so a stale inventory made the reviewer judge changes against a v0.1.0 picture of its own codebase. |
| #85 Reconcile `feeder.json` sourceGlobs with `driver.json` | #92 | `driver.json` was broadened in v0.2.1 (#39); `feeder.json` was missed and still carried the original three globs. Both now resolve to the same set. The dead `hooks/**` glob — which matched nothing, exactly as `BRIEF.md:102` predicted — is removed from both. Live drift, not theoretical: `sourceGlobs` scopes a coherence review's grep surface. |

### Consumer notes (upgrading from v0.3.0)

- **New behavior on the spin-out path:** heal-routing issues filed into your repo now adopt your `.github/ISSUE_TEMPLATE/` convention when one is resolvable. If you have no templates, two or more with no `agentIssueTemplate` key, an unreadable or unparseable template, or a template with no `textarea`, you get **exactly today's shape** — every degradation row terminates at the built-in shape.
- **The `grounding` ref is verbatim on every path**, regardless of template shape. No template condition can drop it, and none can prevent a spin-out from being created — coherence still never gates.
- **New optional profile key** — `agentIssueTemplate` in `.milestone-config/driver.json`, naming the template agents should author to. **Unset is fully supported** and falls through to the count-based rung. It becomes useful once `milestone-bootstrapper#156` begins writing it; nothing here depends on that landing.
- **New contract doc** — `docs/issue-templates.md`. `skills/review/SKILL.md` carries a pointer, no copy.
- **Sweep is unchanged** — this is the `review` path only.
- **No schema changes** to `.milestone-config/driver.json` beyond the optional key above — no key is required, and no existing key changed meaning.
- **Two skills got materially smaller.** `skills/review/SKILL.md` briefly sat at 5086/5090 — four words of headroom — before a condensation pass took it to **4021**, and `skills/sweep/SKILL.md` to **4112**. The `## Invariants` section was folded into `## Non-negotiables` (it was the same list written twice, one heading byte-identical in both), and Step 3's proposal-PR machinery moved to a new single source, **`docs/proposal-pr.md`**, which `sweep` now shares instead of restating. Ceilings ratcheted down to 4100 / 4200 accordingly.

### ⚖️ Post-run audit trail

Judgment-call PRs for this release: **#91**, **#94**

- **#91** edited `.project/design-philosophy.md`, whose own header states *"Humans own this file; tools may propose changes but never rewrite it."* Triage downgraded this to Advisory on precedent — #65 / `1c35821` made an ordinary docs-accuracy edit to the same file through the same pipeline. The edit is one line, factual correction only. **Worth a human confirming the precedent holds.**
- **#94** removed two clauses from `skills/review/SKILL.md:187` to buy the pointer's words. Both were verbatim duplicates of `docs/heal-routing.md` content the same sentence already cites, and `heal-routing.md:121-122` declares itself the single copy of that logic — so the duplicates were themselves drift. Rejected alternative: compressing an unrelated paragraph.

Also of note: **#83 was rewritten mid-run.** Its original findings were authored against a checkout 7 commits behind `origin/develop` and were largely already fixed by PR #79; three of its five findings described problems that did not exist. Triage caught it, the issue was rewritten against verified state and re-triaged clean before building. **#86** (a CHANGELOG-authoring issue) was closed not-planned at triage — all three precedents it cited as convention turned out to be orchestrator-authored doc PRs, never milestone issues, and `solve-milestone` Step 6 already automates the task.

## v0.3.0 — readable coherence memory (recall before re-analysis)

**Theme:** the write-only memory mirror gains its read half. Before analyzing a change, the reviewer recalls prior coherence write-ups whose grounding touches the same files and reuses or references them instead of re-deriving findings from scratch — advisory-only, diff-keyed, and fail-soft. No second store; the existing `memory-mirror` target gains a read path.

### ✨ Readable coherence memory

| Issue | PR | What |
|---|---|---|
| #69 Add a `--recall` read-back mode to `memory-mirror.{sh,ps1}` | #74 | A read-only `--recall [--repo-root <dir>] -- <path> …` mode on both script twins. Reuses the existing `resolve_target`/`Resolve-Target` verbatim (same detect-or-fallback store, no new store, no new dependency); one read + one linear pass; emits a TAB-separated record stream (`ENTRY-BEGIN` / `MATCH` / verbatim body / `ENTRY-END` / `NONE` / `SUMMARY` last) for prior entries whose `<path>:<line>` grounding refs byte-match a touched path. Absent/empty/unreadable store → `NONE` + `SUMMARY entries=0`, exit 0 (no `MIRROR-FAILED` case for recall); bad usage → exit 2. Byte-for-byte bash/pwsh parity verified across all states, including a multibyte fixture (the `.ps1` emits UTF-8-no-BOM straight to the stdout stream). |
| #70 Document the recall/read-back contract, symmetric to the write path | #73 | Recorded the recall contract as a doc — where recall attaches, the diff-keyed match against prior entries' `<path>:<line>` refs, the advisory-never-gates invariant, and the fail-soft degradation matrix — scoped to the `review` flow only, with an explicit deferred-boundary note for sweep (sweep has no diff). |
| #71 Wire recall into the review orchestrator as advisory context | #75 | Recall runs **orchestrator-side** at review start (gathered once, before the single engine dispatch) and is handed to the read-only engine as an advisory **fifth** context part — the engine runs no recall script (read-only-engine ↔ orchestrator split preserved). Reuse-when-valid / flag-when-stale; recall never gates, never auto-suppresses a finding, and is never fed to the severity-only router. The write-up renders a recall status note (matched priors, or an explicit "no related prior write-ups found"). Fail-soft: empty/failed recall → analysis proceeds from scratch. Recall mechanics live in a single source, `docs/recall.md`, with lean pointers from `skills/review/SKILL.md`, `docs/analyze-once.md`, and `docs/write-up.md`. |
| #68 Bump plugin version to 0.3.0 | #72 | Minor version bump (feature-additive milestone); `.claude-plugin/plugin.json` `version` 0.2.1 → 0.3.0, plus the CI-required `.project/conventions.md` version citation. |

### Consumer notes (upgrading from v0.2.1)

- **New behavior on the `review` path:** the reviewer now recalls prior coherence write-ups touching the same files before analyzing, reusing or referencing them instead of re-deriving. It is **advisory only** — it never gates a finding, never auto-suppresses one, and is never an input to heal-routing (which stays severity-only). Empty or failed recall degrades to the prior from-scratch behavior.
- **Uses the store that already exists** — the `memory-mirror` detect-or-fallback target (Obsidian vault / `autoMemoryDirectory` / `.milestone-config/.runtime/` fallback). No second store, no new dependency.
- **New `--recall` mode** on `scripts/memory-mirror.{sh,ps1}`, and a new single-source contract doc `docs/recall.md`.
- **Sweep is unchanged** — recall is `review`-path only; sweep-mode recall is explicitly deferred (a sweep has no diff to key the match on).
- The `skills/review/SKILL.md` size-budget ceiling was lowered (5100 → 5090) as the recall mechanics were relocated into `docs/recall.md` — a budget *reduction*, per the size-budgets ratchet's shrink rule.
- **No schema changes** to `.milestone-config/driver.json` — no new profile keys.

### ⚖️ Post-run audit trail

Judgment-call PRs for this release: none

## v0.2.1 — audit remediation: mechanical grounding-verify, dogfood, truth-ups

Patch release — the audit-remediation milestone (12 issues, all merged CI-green).

- **Mechanical grounding-verify pass** between engine dispatch and write-up render, with bounded live re-check for groundings resolved outside the pre-dispatch cache — the audit's flagship fix (#38)
- Full-strength dogfood run against a disposable scratch fixture: the domainSkills grounding path validated end-to-end, recorded in `docs/validation-note.md` (#47)
- `docs/heal-routing.md` is the sole authority for the route table + reconciliation (#43); sweep's no-milestone fallback routes to review (#42)
- Act-verify-retry on the PR write path (#44); resumable broad sweep (#45); first-run failure guidance (#46); broadened sourceGlobs (#39); stale version citation fixed (#41)
- CI scaffold + version-citation check (#48); per-file size-budget check (#49)
- Precision truth-sweep: shipped human-gated feeder→driver handoff distinguished from the still-deferred unattended cycle; dead driver#232 refs corrected to feeder#148 (#40)

## v0.2.0 — Coherence beyond per-change drift

**Theme:** Coherence beyond per-change drift — an opt-in app-wide consistency scan and config rule-authoring, closing the loop back into `.project/`.

### ✨ Coherence beyond per-change drift

| Issue | PR | What |
|---|---|---|
| #29 Propose conventions.md entries (rule-authoring) | #31 | Adds a `PROPOSALS` return block parallel to `FINDINGS`. When the engine spots a repeated ungoverned pattern (≥3 consistent sites, or a disagreeing cluster with a grounded recommended winner), it proposes a `.project/conventions.md` rule; the orchestrator writes the entry and opens a **human-gated config-only PR** to the integration branch (review Step 3), rendered in the write-up. Proposals are a separate lane (not drift-routed). The engine stays read-only (returns findings **and** proposals, opens no PR); the tool never touches application code or the protected branch, and never gates the merge. |
| #28 Opt-in app-wide sweep + engine sweep-mode | #32 | Adds `/milestone-coherence-reviewer:sweep [pattern]` — a broad-by-default (or pattern-narrowed) app-wide consistency scan. A read-only engine **sweep-mode** classifies standing inconsistency clusters (agree / disagree / governed, with the *defensible-deviation* split: a documented, cited deviation is not drift) and feeds ungoverned repeated clusters into the #29 PROPOSALS lane, routing undocumented-deviation drift through the existing size buckets. The "no whole-repo scan" non-goal is scoped to the per-change path; the sweep is the separate on-demand mode. Reuses `review`'s resolve-config, write-up, mirrors, Step-3 config-PR, and heal-routing by reference. |

### 🔧 Fixes

| Issue | PR | What |
|---|---|---|
| #27 Remove the now-dead `allowCrossMarketplaceDependenciesOn` | #30 | Removed the dead `allowCrossMarketplaceDependenciesOn` key from `.claude-plugin/marketplace.json` — it permitted a cross-marketplace dependency already removed from `plugin.json`, and this repo was the last in the suite still carrying it. Also bumped `plugin.json` to `0.2.0`. |

### Consumer notes (upgrading from v0.1.1)

- **New skill:** `/milestone-coherence-reviewer:sweep [pattern]` — an opt-in, on-demand app-wide consistency scan (broad by default, or narrowed to a named pattern). The per-change `review` skill is unchanged.
- **New engine output + write surface:** the engine now returns a `PROPOSALS` block alongside `FINDINGS`. Both `review` and `sweep` may open a **config-only PR** proposing a `.project/conventions.md` entry — human-gated (merge = accept, close = reject), targeting the integration branch, never the protected branch, never application code. The engine stays read-only; the orchestrator opens the PR.
- **Non-goal narrowed:** "no whole-repo scan" now scopes to the *per-change* path (which stays diff-keyed and flat-cost); the opt-in `sweep` is the separate on-demand mode (scope-bounded to `sourceGlobs`, never per-run).
- **No schema changes** to `.milestone-config/driver.json` — no new profile keys; `coherenceReviewAgent` is default-filled.

### ⚖️ Post-run audit trail

Judgment-call PRs for this release: none

## v0.1.1 — Claude Desktop slash-command fix

**Theme:** drop the cross-marketplace `superpowers` dependency so the plugin's slash commands register in Claude Desktop (they already worked in the Claude Code CLI). Mirrors [kenmulford/milestone-driver#246](https://github.com/kenmulford/milestone-driver/issues/246).

### 🐛 Fix

| Issue | PR | What |
|---|---|---|
| #24 Drop cross-marketplace superpowers dependency | #25 | Removed the `dependencies: [{ superpowers@claude-plugins-official }]` declaration from `.claude-plugin/plugin.json`. Claude Desktop loaded the plugin but skipped registering its skills (Unknown command) while that cross-marketplace dependency was declared. `superpowers` is now a documented prerequisite — install it alongside this plugin — not an auto-installed dependency. |

## v0.1.0 — the standalone coherence reviewer

**Theme:** the standalone coherence review — check a built change for fit with the app, heal what's safe, and explain it legibly. Specified in [BRIEF.md](BRIEF.md); built via the `feeder → driver` dogfood loop.

### ✨ The standalone coherence reviewer

| Issue | PR | What |
|---|---|---|
| #1 Scaffold the plugin package | #8 | `.claude-plugin/plugin.json` (the single version source of truth, `0.1.0`) and the plugin's own `marketplace.json` (no `version` field), mirroring the suite siblings. |
| #2 Config + project-docs resolve-once layer | #9 | `scripts/resolve-config.{sh,ps1}` resolve the shared keys from `.milestone-config/driver.json` (root `milestone-driver.json` fallback) and `.project/` sections via the installed driver's `read-doc-section` primitive (wired, not reimplemented), with graceful degradation. Byte-for-byte parity across the bash/PowerShell twins. |
| #3 Three-source review engine | #10 | `agents/coherence-reviewer.md`: a read-only reviewer that checks a built diff against the app (bounded diff-keyed greps), the resolved `.project/` sections, and `domainSkills`, emitting hard-grounded findings (ungroundable findings dropped) plus a drift-size hint. Performs no heal. |
| #4 Analyze-once orchestration | #11 | `docs/analyze-once.md`: gather the review context + findings once, then distribute minimal, self-contained slices (inline-fix = finding + citation + file scope; large-drift = a tight adjustments brief). Build-once under fan-out; zero-findings clean terminal. |
| #5 Legible write-up + mirrors | #12 | `docs/write-up.md` (the primary deliverable spec — inline-primary summary + issue/PR/memory mirrors, the `gh` redo one-liner, clean-fit "fits cleanly" rule) and `scripts/memory-mirror.{sh,ps1}` (conservative detect-or-fallback: the user's configured memory store, else a git-invisible `.milestone-config/.runtime/` file). |
| #6 Heal routing by drift size | #13 | `docs/heal-routing.md`: route each fix by drift size alone — trivial → inline (degrades to a small-issue note standalone), small/medium → current-milestone issues, large → a `milestone-feeder` brief. Never gates the merge; recursion self-terminates at milestone granularity (no counter). |
| #7 Standalone `review` skill | #14 | `skills/review/SKILL.md`: the entry point `/milestone-coherence-reviewer:review <branch-or-PR>` that ties it all together (resolve → engine → analyze-once → write-up → heal-route). Read-only on the merge; never blocks, gates, or touches the merge or the protected branch. |

### Consumer notes

- **New standalone plugin.** Install it via its own marketplace, then run `/milestone-coherence-reviewer:review <branch-or-PR>` to review a built change for coherence with the rest of the app. The inline write-up is the deliverable; fixes are healed by drift size (trivial inline, small/medium as current-milestone issues, large fed to `milestone-feeder`) — it never blocks the merge.
- **Reads, does not duplicate, the suite's shared config.** It resolves the shared keys (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`, `nonNegotiables`, `domainSkills`) from `.milestone-config/driver.json` (root `milestone-driver.json` fallback) and `.project/` sections via the driver's resolve-once primitive. It adds **no new keys** to `driver.json` / `feeder.json` and writes no config of its own.
- **Degrades cleanly.** Thin/absent `.project/` or an absent driver profile is never an error — it falls back to bounded diff-keyed greps with reduced grounding.
- **Memory mirror is opt-in.** The supplemental memory mirror writes only to a memory store you have already configured (an Obsidian vault via `NPM_CLAUDE_VAULT_ROOT` / a `.obsidian/` dir / an `autoMemoryDirectory` setting); otherwise it falls back to a git-invisible file under `.milestone-config/.runtime/`. It never guess-writes into an unconfigured location.

### ⚖️ Post-run audit trail

Judgment-call PRs for this release: **#9** — the resolve-once layer's `/code-review` ran one fix cycle past the documented 2-cycle cap to land a single, fully-specified CR-strip; the findings were converging (5 → 3 → 1, each narrower) on a sound plan, so the extra cycle was taken (rather than parking a foundational issue over a one-liner) and labeled for audit.

Tracked as companion changes in their own repos at release time:

- **Driver-embedded path** — a new `solve-issue` step (~6.2, after `/code-review`) + a default-filled `coherenceReviewAgent` profile key + heal-orchestration, in `milestone-driver`. → [kenmulford/milestone-driver#231](https://github.com/kenmulford/milestone-driver/issues/231) — **Update (shipped 2026-06-24, `milestone-driver` v1.13.0):** coherence review now runs before the final `/code-review` in `solve-issue`/`solve-milestone`, gated on the reviewer being present + configured, silently skipped otherwise, never gating.
- **The automated `feeder → driver` handoff** (the feeder creating a milestone and the driver then running it, no human in between) — a new capability in the feeder/driver. Standalone v0.1.0 can create the follow-up milestone via the feeder but cannot auto-run the driver. → [kenmulford/milestone-feeder#148](https://github.com/kenmulford/milestone-feeder/issues/148) (corrected — `milestone-driver#232` never existed) — **Update (shipped 2026-06-24, `milestone-feeder` v0.5.0):** `create` now offers to hand a clean run straight to the driver, governed by `feeder.json#autoHandoff` (`prompt` default / `auto` / `off`). This is a narrower, human-gated create-time handoff, not the unattended no-human-in-between cycle described above — that fully-automated cycle is still not built.

Done after the v0.1.0 release: the plugin is now listed in the [`kenmulford/milestone-suite`](https://github.com/kenmulford/milestone-suite) catalog (HTTPS `url` source) — installable from the suite as well as its own marketplace.
