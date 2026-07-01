# Changelog

Notable changes to the **milestone-coherence-reviewer** plugin, newest first. (Built on `develop` via the `feeder → driver` dogfood loop; v0.1.0 released.)

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

Tracked as companion changes in their own repos (still deferred):

- **Driver-embedded path** — a new `solve-issue` step (~6.2, after `/code-review`) + a default-filled `coherenceReviewAgent` profile key + heal-orchestration, in `milestone-driver`. → [kenmulford/milestone-driver#231](https://github.com/kenmulford/milestone-driver/issues/231)
- **The automated `feeder → driver` handoff** (the feeder creating a milestone and the driver then running it, no human in between) — a new capability in the feeder/driver. Standalone v0.1.0 can create the follow-up milestone via the feeder but cannot auto-run the driver. → [kenmulford/milestone-driver#232](https://github.com/kenmulford/milestone-driver/issues/232)

Done after the v0.1.0 release: the plugin is now listed in the [`kenmulford/milestone-suite`](https://github.com/kenmulford/milestone-suite) catalog (HTTPS `url` source) — installable from the suite as well as its own marketplace.
