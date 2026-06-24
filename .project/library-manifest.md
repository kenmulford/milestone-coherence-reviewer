# Library manifest

<!--
Project doc (.project/). Cite as `.project/library-manifest.md#<section>`. The
implementer's "new dependency = PAUSE" gate reads this; the coherence-reviewer
flags a new library that duplicates one listed here. Keep it current. Keep ##
headings stable — they are citation anchors.
-->

## Runtime & frameworks
The platform/runtime and primary frameworks, with versions. (Mirror these into milestone-driver `nonNegotiables` where they're hard constraints.)
> A **Claude Code plugin** — markdown skills (`skills/review/SKILL.md`) + a markdown agent (`agents/coherence-reviewer.md`) + cross-platform script twins (bash `*.sh` / PowerShell 7+ `*.ps1`). No application runtime, no compiled language, no framework. JSON tooling is `jq` (bash) / built-in `ConvertFrom-Json` (pwsh). Depends on the `superpowers` plugin (claude-plugins-official) and, at runtime, the installed `milestone-driver`'s `read-doc-section` primitive. (.claude-plugin/plugin.json `dependencies`; docs/resolution.md §"Dependency note" + §"Finding the driver primitive"; the `scripts/` tree.)

## Approved libraries (by purpose)
One approved choice per purpose, so a redundant alternative is easy to spot.

| Purpose | Library | Notes |
|---|---|---|
| JSON parse (bash) | `jq` | the suite's already-permitted JSON tool — no new dependency (docs/resolution.md §"Dependency note") |
| JSON parse (pwsh) | `ConvertFrom-Json` (built-in) | PowerShell 7+ built-in; the cross-platform twin of the `jq` path |
| doc-section read | milestone-driver `read-doc-section` primitive | reused unchanged, never reimplemented (docs/resolution.md §"How `.project/` sections are read") |

## Adding a dependency (the gate)
A new dependency is a PAUSE, not an autonomous call. Record what it buys, its license / OSS status, and why nothing approved suffices; a human approves before it's added.
> A new dependency is a **PAUSE**, not an autonomous call. The suite stays dependency-light and reuses already-permitted tooling (`jq` / `ConvertFrom-Json`) and the driver's existing dependency-free primitive rather than adding anything. Propose via a GitHub issue (the suite convention, e.g. labeled `needs decision`) before adding. (docs/resolution.md §"Dependency note" — "no new dependency is introduced".)

## Avoid / banned
Libraries explicitly not to use, and why.
> - Do **not** duplicate the driver's shared keys into a coherence-owned config — read `driver.json` in place (BRIEF.md §"Integration" l.90, §"Constraints" l.132).
> - Do **not** reimplement the driver's `read-doc-section` primitive or a Markdown parser (docs/resolution.md §"How `.project/` sections are read").
> - Do **not** introduce a non-`jq` JSON tool on bash, or break the byte-for-byte bash/pwsh script parity.
