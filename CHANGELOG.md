# Changelog

Notable changes to the **milestone-coherence-reviewer** plugin, newest first. (Pre-release; nothing shipped yet.)

## Unreleased — v0.1.0 (planned)

**Theme:** the standalone coherence review — check a built change for fit with the app, heal what's safe, and explain it legibly. Specified in [BRIEF.md](BRIEF.md); to be built via the `feeder → driver` dogfood loop.

Planned for v0.1.0:

- **The review engine** — checks a change against three sources (the app via diff-keyed greps, the project docs, the stack's `domainSkills`), with a hard-grounding rule (every finding cites a doc section / `file:line` / skill) and the analyze-once-then-distribute pattern for token efficiency.
- **The legible write-up** — the actual product: a plain-English summary, inline-first and un-buried, of what it did and why, with citations and a copy-paste `gh` one-liner to redo it differently. Mirrored to the issue, the PR, and memory as the audit trail.
- **Heal routing (standalone)** — trivial → inline note; small/medium → issues on the current milestone; large → a follow-up milestone via `milestone-feeder`. Never gates the merge. Routes on drift size only.
- **Suite integration** — reads `.project/` (resolve-once) and the `.milestone-config/` shared keys (incl. `domainSkills`); degrades cleanly when docs are thin.

Tracked as companion changes in their own repos (not this release):

- Driver-embedded path — a new `solve-issue` step (~6.2, after `/code-review`) + a default-filled `coherenceReviewAgent` profile key + heal-orchestration, in `milestone-driver`.
- The automated `feeder → driver` handoff (feeder creating a milestone and the driver then running it, no human in between) — a new capability in the feeder/driver.
