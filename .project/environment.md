# Environment

<!--
Project doc (.project/). Cite as `.project/environment.md#<section>`. Declares what the
project's runtime and production environment looks like — the facts downstream tools ground
their data, test, and caching decisions in. It does NOT provision anything; it records the
model so issues don't drift. Fill every [TBD]; a section left [TBD] is treated as "not
specified." Humans own this file; tools propose, never rewrite. Keep the ## headings stable
— they are citation anchors.
-->

## Environments
Which environments exist (production, staging, test, local) and how they differ.
> None beyond the local developer CLI: this plugin runs inside Claude Code against a target git repository. There are no prod / staging / test deployment tiers. (README.md "How to use"; BRIEF.md §"How it runs" l.78.)

## Data stores
Databases and other persistent stores: the engine(s), and the **topology** — separate prod / staging / test databases, or a shared one. **Test-data isolation:** how tests get a clean, isolated database (a dedicated test DB, a per-worker DB suffix, transactional rollback, truncate-on-start). This is the single biggest drift source if left unstated.
> **None** — no databases or persistent stores. The only persistence is the supplemental memory mirror: a detect-or-fallback `.md` written to a user-configured memory store (Obsidian vault / `autoMemoryDirectory`) or, when none is configured, a git-invisible file under `.milestone-config/.runtime/`. No test-data isolation concern (there is no DB). (docs/write-up.md §"The memory mirror (detect-or-fallback)"; scripts/memory-mirror.sh.)

## Caching
Whether caching exists and, if so, the layer and technology (in-memory, Redis, CDN), what is cached, and the invalidation policy. **"None" is a valid, drift-preventing answer** — record it explicitly.
> **None** — no cache layer. The resolve-once / analyze-once pattern reuses resolved keys and sections in memory for the duration of a single run (gather once, distribute slices); that is per-run reuse, not a caching technology. (docs/resolution.md §"Resolve-once contract"; docs/analyze-once.md.)

## Async & messaging
Background jobs, queues, streams, schedulers — or "none."
> **None** — no background jobs, queues, streams, or schedulers. The review runs synchronously per invocation. (skills/review/SKILL.md — synchronous procedure.)

## External services & integrations
Third-party services the app depends on: auth / identity, payments, email / SMS, object storage, analytics, other APIs.
> **GitHub** via the `gh` CLI (issue/PR comments, follow-up issue creation, the redo one-liner). **Sibling plugins:** `milestone-driver` (orchestrates the embedded path, supplies `domainSkills` and the `read-doc-section` primitive), `milestone-feeder` (the large-drift handoff target), `milestone-bootstrapper` (populated `.project/` + `domainSkills`), and `superpowers` (a documented prerequisite, installed separately — not a declared dependency). (BRIEF.md §"Integration" l.85-96; docs/write-up.md §"Four landing places".)

## Runtime & hosting
Where it runs and the runtime/version targets (hosting platform, language-runtime versions, regions). For mandated frameworks and packages, cross-reference `library-manifest.md`.
> Runs inside the Claude Code CLI harness on the developer's machine; cross-platform by design — bash on macOS/Linux, PowerShell 7+ on Windows (host selection mirrors the suite's `ci-preflight-steps`). No hosting platform. (docs/resolution.md §"What runs it" table; BRIEF.md §"Constraints" l.131 — bash-first / PowerShell-7 fallback.)
