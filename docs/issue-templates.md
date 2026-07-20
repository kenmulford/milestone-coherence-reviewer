# Issue templates — shaping the spin-out body to the consumer repo's convention

[Heal routing](heal-routing.md) decides **where** each fix lands. This doc is the
piece next to it: for the routes that open **a new issue**, it decides **what
that issue's body looks like** — so a spun-out finding reads like every other
issue in the consumer's backlog instead of like a third structure a triager has
to learn.

These issues land alongside human-filed and `milestone-feeder`-filed ones. Three
shapes in one backlog is the exact problem issue templates exist to solve.

This doc is the **single source** for template resolution, the emission modes,
the stock mapping, and the degradation matrix. `skills/review/SKILL.md` carries a
lean pointer here and **no copy** — the same single-source arrangement it has
with [heal-routing](heal-routing.md) (the route table) and [recall](recall.md)
(the read-back contract). Design record:
[`docs/superpowers/specs/2026-07-20-template-shaped-spin-out-design.md`](superpowers/specs/2026-07-20-template-shaped-spin-out-design.md).

> Scope note. This is the **`review` path only** — `skills/sweep/SKILL.md` is
> unchanged. This doc shapes the **body**; it never touches *where* the issue
> attaches (heal-routing's
> [reconciliation](heal-routing.md#milestone-attachment-reconciliation-not-a-hard-coded-assumption)),
> and it is **never a gate** — no template condition can stop an issue from
> being created.

## The built-in shape (the floor every path falls back to)

The **built-in shape** is what the spin-out emits today: the finding's
`description` + `symbol`, plus its single `grounding` ref, verbatim
(`skills/review/SKILL.md` §"Step 5"; the finding's fields are
`agents/coherence-reviewer.md:93-97`). Every rung, mode, and degradation row
below either shapes that content into a template or falls back to it unchanged.

## The resolution ladder — once per run, repo-wide

Which template (if any) the run authors to. Resolved **once per run**, not per
finding: the template set is the same for every finding, so there is nothing
per-finding to resolve. This is the suite's resolve-once-and-hand-in pattern —
the same one the [resolution layer](resolution.md) uses for the shared keys and
the `.project/` sections (`BRIEF.md` §"Analyze once, then distribute" l.33-40).

| Rung | Condition | Result |
| --- | --- | --- |
| 1 | `agentIssueTemplate` is set in `.milestone-config/driver.json` **and** the named file is readable | use that template — **Mode A** |
| 2 | exactly one file in `.github/ISSUE_TEMPLATE/` | use it — **Mode A** if it is a suite-authored stock file, **Mode B** if it is consumer-owned, **Mode C** if it is `.md` |
| 3 | zero templates, **or** two-plus with no `agentIssueTemplate` key | the built-in shape |
| 4 | — | absence **never** blocks issue creation |

`agentIssueTemplate` is read from the **driver profile in place**, the same way
every other shared key is (`docs/resolution.md` §"Where the shared keys come
from (resolution order)"). It is **skipped when absent, never invented** — coherence fabricates no
default. Reading it costs nothing today: no consumer profile sets it yet
(`.milestone-config/driver.json` in this repo does not), so unkeyed repos simply
fall through to rung 2.

Rung 2's "two-plus falls through" is why rung 1 exists. `milestone-bootstrapper`
provisions **two** stock templates (`change_request.yml` + `bug_report.yml`); a
count-only rule would hand a bootstrapped repo the stock set and then ignore it
forever. The bootstrapper records which of the two agents author to, as
`agentIssueTemplate`, and rung 1 reads it. Until that lands the key is simply
unset and the ladder behaves as though rung 1 were not there — **this doc's
behavior ships standalone, with no blocking dependency.**

## The three emission modes

The mode is chosen by **which rung matched**, because that is what determines
whether the template's *shape* is known to the suite. Nothing here inspects a
field's meaning.

| Mode | Reached via | Shape | Emission |
| --- | --- | --- | --- |
| **A** | rung 1, or rung 2 on a suite-authored stock `.yml` | known | translate every non-`markdown` field to `## <label>`, in `body:` order |
| **B** | rung 2 on a consumer-owned `.yml` | unknown | the **first** `textarea`'s `attributes.label` becomes one `## <label>`; the whole built-in body goes under it; every other field is omitted |
| **C** | rung 2 on a `.md` template | n/a | use the `.md` body as the skeleton directly |

### Mode A — stock or keyed (shape known)

Full field translation is safe here because the suite authored the template (or
the consumer keyed it, asserting that agents should author to it) and sized it
for exactly this use, so a full translation produces no empty sections. The
per-section content comes from the [stock mapping](#finding--the-stock-change_requestyml)
below.

A Mode A field the mapping cannot fill is not guessed: an **optional** field is
omitted, and a **required** field falls to the built-in shape for that finding
(the last row of the [degradation matrix](#degradation-matrix)) — with the one
recorded exception, the Non-goals constant.

### Mode B — consumer-owned (shape unknown)

**Structural, no semantics.** The first `textarea`'s label is used as a container
heading and nothing else is interpreted. There is deliberately **no** keyword
list, regex, or heuristic for deciding which arbitrary field means "evidence" or
"summary".

Two reasons, both load-bearing:

- **Guessing is the one thing this engine refuses.** A finding that cannot be
  hard-grounded is dropped, never guessed (`agents/coherence-reviewer.md:58`).
  Inferring a stranger's field semantics is the same move, one layer out.
- **It keeps the body's size set by the finding, not by their template.**
  Emitting a section per field would let a consumer's ten-field form set the
  body length, breaking the flat-cost property at `docs/write-up.md:255` — *"one
  short item per finding … not an essay"*.

This is a **deliberate divergence from `milestone-feeder`'s** equivalent, which
translates all fields in `body:` order. The asymmetry is real: the feeder authors
a full issue specification with content for every section, while the reviewer
emits one ~3-line finding and would render four or five empty headings. Recorded
here so it reads as intentional, not as drift.

### Mode C — `.md` skeleton

Use the `.md` body as the skeleton directly. Alignment is cheap on this rung —
there is no field structure to reason about — so this matches the feeder
exactly. The `grounding` ref still lands verbatim in the composed body.

## Finding → the stock `change_request.yml`

The stock section order is Summary → Impact → Proposed solution → Non-goals →
Acceptance criteria → detail. A finding carries `description`, `symbol`, `lens`,
`grounding`, and `severity` (`agents/coherence-reviewer.md:93-97`).

| Section | Filled from | Notes |
| --- | --- | --- |
| Summary | `description` + `symbol` | one plain sentence naming the change |
| Impact | `lens` | the why — what it diverges from |
| Proposed solution | the redo one-liner's scoped ask (`skills/review/SKILL.md` §"Step 4") | what to do differently |
| Non-goals | a **truthful constant** | *"None — filed from a single coherence finding and carrying no scope beyond it."* |
| Acceptance criteria | **derived — one checkbox** | `- [ ] <symbol> follows the pattern at <grounding>` |
| detail | the `grounding` ref, **verbatim** | never a paraphrase (`docs/write-up.md:107`) |

### The two stock dropdowns

The stock form carries `Surface` and `Risk` dropdowns whose options match the
label taxonomy the bootstrapper's `provision-labels` writes.

| Dropdown | Behavior |
| --- | --- |
| `Risk` | **mapped from `severity`** — `drift-trivial`/`drift-small` → `light`; `drift-medium`/`drift-large` → `heavy`. Grounded: heal routing already routes on `severity` and nothing else (`docs/heal-routing.md` §"The single routing key — drift size, nothing else") |
| `Surface` | **omitted.** `ui` vs `logic` is not encoded in the finding schema (`agents/coherence-reviewer.md:93-97`), a coherence finding *can* touch a UI surface, and picking one would be a guess. Left for whoever triages the spun-out issue |

### Why the Non-goals constant is not a fabrication

A template that forces an agent to emit an empty or invented section is worse
than no template, and `milestone-feeder` parks with a `PRODUCT_GAP` when a
required field cannot be grounded.

**The reviewer cannot park.** Returning a gap for an unfillable Non-goals field
would make the spin-out gate on template shape, violating the tool's central
invariant — *coherence heals, it does not gate* (`BRIEF.md` l.42-52;
`docs/heal-routing.md` §"Never a gate — the merge proceeds regardless").

The constant resolves this without fabricating. *"None — filed from a single
coherence finding"* is a **true statement about what this issue is**; it asserts
nothing about the code. A single drift observation genuinely has no scope
boundary to declare, and saying so is more honest than either omitting a required
section or inventing scope.

## `.yml` field semantics

How a GitHub issue-form field becomes body text. These apply in **every** mode
that reads a `.yml`.

| Element | Behavior |
| --- | --- |
| `type: markdown` | **never emitted** — display-only chrome for the browser form, not content |
| `type: textarea` / `input` | the field's content under `## <attributes.label>` |
| `type: dropdown` | renders the **selected option's text**, not the option list |
| `type: checkboxes` | not present in the stock form; treated as any other unfillable field — optional → omitted, required → built-in shape for that finding |
| `attributes.value` | a **prefill to replace**, never content to echo into the body |
| `attributes.render: <lang>` | wraps that field's content in a fenced block |
| the form's top-level `labels:` | applied to the created issue (`gh issue create --label …`) |
| the form's top-level `title:` | applied as the issue title's **prefix** |

## Invariants (always true, every path)

- **The `grounding` ref is present and verbatim in every composed body.** Never
  dropped, never paraphrased, never relocated out of existence — regardless of
  whether the template has an evidence-shaped field, and on every rung, mode, and
  degradation row. It inherits the engine's central rule
  (`agents/coherence-reviewer.md:58`) and the write-up's verbatim-citation rule
  (`docs/write-up.md:107`).
- **Never gates.** Every resolution or parse failure degrades to the built-in
  shape and the issue **is still created**. No template condition can prevent a
  spin-out, and none can block the merge (`docs/heal-routing.md` §"Never a gate —
  the merge proceeds regardless").
- **Body length is set by the finding, not the template** (`docs/write-up.md:255`).
  Mode B guarantees this structurally; Mode A is bounded because the suite (or
  the consumer's own key) controls the template's size.
- **Resolved once per run, repo-wide** — never per finding, never re-resolved
  downstream (`docs/analyze-once.md`).
- **Nothing is inferred from a field's name.** No keyword list, no regex, no
  heuristic maps a stranger's field to a role.
- **Reads only.** Resolution reads the driver profile and
  `.github/ISSUE_TEMPLATE/`; it writes neither, and provisions no template.

## Degradation matrix

Every row is **fail-soft**; none errors, and none blocks the create
(`.project/design-philosophy.md#Error & failure philosophy` — *absence means
skip; coherence heals, it never gates*).

| Condition | Behavior |
| --- | --- |
| no `.github/ISSUE_TEMPLATE/` directory | built-in shape |
| `agentIssueTemplate` unset | fall through to rung 2 (not a failure) |
| `agentIssueTemplate` set but the file is missing or unreadable | built-in shape, noted in the write-up |
| template YAML unparseable | built-in shape, noted |
| two or more templates and no `agentIssueTemplate` key | built-in shape |
| a Mode B template with **zero** `textarea` fields | built-in shape |
| a Mode A **optional** field that cannot be filled | that section omitted |
| a Mode A **required** field that cannot be filled | the truthful constant for Non-goals; **any other** such field → built-in shape for that finding |

A "noted" row is surfaced the same way every other best-effort step in the run is
— skipped-and-noted in the write-up, never raised (`docs/write-up.md`
§"Graceful degradation"; `skills/review/SKILL.md` Step 4 item 6).

## Out of scope

- **The write-up format**, its four landing places, and the per-finding tightness
  rule (`docs/write-up.md`) — unchanged.
- **The drop-if-ungroundable inversion** (`agents/coherence-reviewer.md:58`) —
  deliberate, stays.
- **The `chore/propose-*` conventions-PR lane** (`skills/review/SKILL.md` §"Step 3") —
  a separate lane; a proposal's config-only PR is not an issue and is not shaped
  here.
- **Heal routing itself** — which finding takes which route, and whether the new
  issue attaches to a milestone or the backlog, stay in
  [heal-routing.md](heal-routing.md).
- **Sweep-mode spin-outs** — `skills/sweep/SKILL.md` is unchanged.
- **Enforcement.** Issue *forms* are browser-UI only; `gh issue create` with a
  body bypasses them entirely
  ([cli/cli#5865](https://github.com/cli/cli/issues/5865)). This is structure the
  agent self-imposes so the body *reads* like a templated issue — the platform
  does not validate it, and nothing here tries to make it.
- **Provisioning templates.** `milestone-bootstrapper` provisions the stock set
  and records `agentIssueTemplate`; this doc only *reads* the result.

## Contract summary

- **Resolve once per run, repo-wide** — rung 1 `agentIssueTemplate`, else rung 2
  exactly-one-template, else the built-in shape. Absence never blocks.
- **Three modes, chosen by rung, never by inspecting field meaning** — A (shape
  known) translates every non-`markdown` field; B (shape unknown) uses the first
  `textarea`'s label as a single container heading; C (`.md`) uses the file as a
  skeleton.
- **The stock `change_request.yml` maps** Summary ← `description` + `symbol`,
  Impact ← `lens`, Proposed solution ← the redo one-liner's ask, Non-goals ← the
  truthful constant, Acceptance criteria ← one derived checkbox, detail ← the
  verbatim `grounding` ref. `Risk` ← `severity`; `Surface` omitted.
- **The `grounding` ref is verbatim in every composed body, on every path.**
- **Never gates** — every failure degrades to the built-in shape and the issue is
  still created; the change under review merges either way.
- **Body length is set by the finding, not the template.**

Same DNA as the rest of the layer: the [engine](../agents/coherence-reviewer.md)
grounds the finding, [analyze-once](analyze-once.md) shapes the slice,
[heal-routing](heal-routing.md) picks the destination, this doc shapes the body —
and the merge proceeds either way.
