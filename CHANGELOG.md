# Changelog

Notable changes to the **milestone-coherence-reviewer** plugin, newest first. (Built on `develop` via the `feeder → driver` dogfood loop; v0.1.0 released.)

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

Tracked as companion changes in their own repos (not this release):

- **Driver-embedded path** — a new `solve-issue` step (~6.2, after `/code-review`) + a default-filled `coherenceReviewAgent` profile key + heal-orchestration, in `milestone-driver`.
- **The automated `feeder → driver` handoff** (the feeder creating a milestone and the driver then running it, no human in between) — a new capability in the feeder/driver. Standalone v0.1.0 can create the follow-up milestone via the feeder but cannot auto-run the driver.
- **Suite-catalog entry** in `kenmulford/milestone-suite`'s `marketplace.json` (HTTPS `url` source), so the plugin is installable from the suite catalog as well as its own marketplace.
