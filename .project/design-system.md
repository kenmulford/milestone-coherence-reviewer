# Design system

<!--
Project doc (.project/). Cite as `.project/design-system.md#<section>`. Machine-readable
design tokens live in `tokens.json` alongside this file. Absent or all-[TBD] →
no design-lens grounding (design-reviewer / coherence-reviewer / wireframing
skip it). Skip this file entirely for repos with no UI surface. Keep ## headings
stable — they are citation anchors.
-->

## Design tokens
Canonical color, type, spacing, and radius scales. Source of truth is `tokens.json`; describe intent and usage here.
> **Not applicable** — no UI surface. This plugin ships markdown skills/agents + shell scripts; it renders no UI, so there is no design-lens grounding to capture. (README.md "How to use"; BRIEF.md §"Non-goals" — "Not visual/UX".)

## Component inventory
The canonical components and where they live. New UI reuses these before introducing a one-off.

| Component | Location | Use for |
|---|---|---|
| None — no UI surface | — | not applicable (markdown + shell plugin) |

## Layout & responsive rules
Grid, breakpoints, spacing rhythm, density.
> **Not applicable** — no UI surface.

## Required states
Every interactive surface must handle these explicitly.
- **Empty:** not applicable — no UI surface
- **Loading:** not applicable — no UI surface
- **Error:** not applicable — no UI surface
- **Disabled:** not applicable — no UI surface

## Accessibility baseline
The standard you hold, plus contrast, focus, target size, and semantics expectations.
> **Not applicable** — no UI surface.

## Voice & microcopy
Tone for labels, errors, and empty states.
> **Not applicable** — no UI surface. (Tone for the reviewer's *write-up* prose is owned by docs/write-up.md, not a design system.)
