# Conventions

<!--
Project doc (.project/). Cite as `.project/conventions.md#<section>`. This is the file the
implementer and coherence-reviewer lean on hardest — "reuse conventions" and
"does this fit the app?" both resolve here. Prefer pointing at a canonical
exemplar in the codebase (path:line) over prose. Keep ## headings stable — they
are citation anchors.
-->

## Naming
Files, types, functions, tests, branches.
> Skills under `skills/<verb>/SKILL.md`; the agent under `agents/<name>.md`; docs under `docs/<topic>.md`; cross-platform script twins share a basename with `.sh` / `.ps1` extensions (`resolve-config.{sh,ps1}`, `memory-mirror.{sh,ps1}`). Branches: a feature branch → PR → `develop`. (Repo tree: skills/review/SKILL.md, agents/coherence-reviewer.md, docs/*, scripts/*; .milestone-config/driver.json `integrationBranch`.)

## File & folder layout
Where things go, and the shape of a feature.
> - `.claude-plugin/` — `plugin.json` (version source of truth) + the plugin's own `marketplace.json`.
> - `skills/` — the two entry points: `review` (the per-change orchestrator) and `sweep` (the opt-in app-wide scan).
> - `agents/` — the read-only review engine (`coherence-reviewer.md`).
> - `docs/` — the contracts: one contract topic per file (`docs/<topic>.md`), plus the validation records for a dogfood run. Read the directory for the current set; a hand-maintained list here is what drifts.
> - `scripts/` — two kinds. The **cross-platform twins** consumed at run time, sharing a basename across hosts (`resolve-config.{sh,ps1}`, `memory-mirror.{sh,ps1}`); and the **CI-only bash checkers**, deliberately without a pwsh twin because only the ubuntu-latest CI job consumes them (`check-version-citation.sh`, `check-size-budgets.sh`, `check-size-budgets.test.sh` — rationale at `scripts/check-size-budgets.sh:46-48`, "No pwsh twin").
> - `.github/` — `workflows/ci.yml` (the CI gates; see §"Test patterns") and the golden-case fixtures its checker's test runner reads, one directory per case under `workflows/fixtures/size-budgets/`.
> - `.milestone-config/` — the shared driver/feeder config, read in place.
>
> (Repo tree.)

## Test patterns
Where tests live, how they're named, fixtures/factories, and what a good test looks like.
> **No application unit-test suite** and no `tests/` directory (this is a markdown + shell plugin). Correctness is established by four things: documented-contract conformance; `/code-review` per PR; verified byte-for-byte bash/pwsh script parity for the cross-platform twins; and the two CI gates, `version-citation-check` and `size-budgets` (`.github/workflows/ci.yml:32`, `.github/workflows/ci.yml:47`). The size-budgets gate is itself self-tested — `scripts/check-size-budgets.test.sh` runs a case table of golden-case fixtures under `.github/workflows/fixtures/size-budgets/`, and CI runs it ahead of the checker it covers (`.github/workflows/ci.yml:53-54`). (Repo tree; `scripts/check-size-budgets.test.sh` header comment.)

## Canonical exemplars (mirror these)
The reference implementations to copy when building something similar. Point at real code.

| For… | Mirror | Notes |
|---|---|---|
| a cross-platform script twin | `scripts/resolve-config.sh` + `scripts/resolve-config.ps1` | byte-for-byte identical output across hosts; TAB-separated record stream (docs/resolution.md) |
| a read-only review engine / agent | `agents/coherence-reviewer.md` | structured FINDINGS + PROPOSALS return block; hard-grounding rule; returns findings + proposals, acts on nothing (the orchestrator acts) |
| a skill (orchestrator) entry point | `skills/review/SKILL.md` | resolve → engine → analyze-once → write-up → heal-route; read-only on the merge |
| a contract doc | `docs/resolution.md` | spec-style; cites BRIEF.md by section + line; degradation matrix + exit-code tables |

## Commits & PRs
Message format and PR expectations.
> **Conventional Commits** with a PR-number suffix: `feat: …`, `docs: …`, `chore: …`, each ending `(#<pr>)`. One issue → one PR → `develop`; the `develop → main` release PR is opened by the human (Ken). (`git log` — e.g. "feat: three-source coherence review engine (read-only agent) (#10)", "docs: analyze-once-then-distribute orchestration contract (#11)"; CHANGELOG.md issue→PR table.)

## Versioning
Does the project follow semantic versioning? If so, **where the version lives** (e.g. `pyproject.toml`, `package.json`, `*.csproj`, a `VERSION` file) and the **bump cadence** (per feature / milestone). When semver is on, `milestone-driver` applies the bump per PR and `milestone-feeder` names milestones as versions so the driver can derive the target.
> **SemVer.** The single source of version truth is `.claude-plugin/plugin.json` (`version`); `marketplace.json` carries **no** `version` field — Claude Code resolves `plugin.json` first, and setting both silently masks the marketplace value. Milestones are named as versions (e.g. `v0.1.0`, `v0.1.1`) so the driver can derive the bump target. (BRIEF.md §"Plugin packaging" l.102-104; .claude-plugin/plugin.json `version` 0.4.0; .milestone-config/feeder.json `versioning: semver`.)
