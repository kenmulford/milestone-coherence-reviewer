# Template-shaped spin-out issues — design

**Issue:** [#81](https://github.com/kenmulford/milestone-coherence-reviewer/issues/81) — *Compose heal-routing spin-out issues to the consumer repo's issue template*
**Date:** 2026-07-20
**Status:** designed, awaiting implementation
**Companions:** `milestone-feeder#331`, `milestone-bootstrapper#156`

---

## Problem

The heal-routing spin-out at `skills/review/SKILL.md:187` (Step 5, item 1) opens issues via `gh issue create` with a body composed from the finding's `description` + `symbol` + its single `grounding` ref. That shape is defined here and ignores whatever issue-template convention the consumer repo already has.

These issues land in a repo alongside human-filed and feeder-filed issues. Three structures in one backlog means a triager cannot scan them the same way — the exact problem issue templates exist to solve.

Severity is lower than the feeder's equivalent: these bodies are short by design (`docs/write-up.md:255` — *"one short item per finding, never an essay"*), so the drift is structural rather than a bloat problem.

## Cross-plugin context

Three plugins write issues into consumer repos. Two companion issues were already filed:

| Issue | Scope | State |
|---|---|---|
| `milestone-bootstrapper#156` | provisions stock `change_request.yml` + `bug_report.yml` at repo-init; never clobbers an existing template | open, no milestone |
| `milestone-feeder#331` | resolves the consumer template when authoring | open, milestone `v0.12.3` |
| `milestone-coherence-reviewer#81` | same resolution for `gh issue create` spin-outs | **this design** |

### The defect these two had, and its fix

`#156` provisions **two** stock templates. `#331`'s selection rule is *"exactly one template → author to it; two or more → built-in default"*, with smart selection explicitly deferred.

Composed, those defeat each other: a bootstrapped repo receives the stock set and then every agent ignores it forever, because the count is two. `#331` half-anticipates this (*"there is also nothing to select against yet… until a stock set exists"*) but treats it as a temporary state; `#156` makes the stock set two, so the deferred selection problem becomes load-bearing the moment it lands.

**Resolution (decided 2026-07-20):** fix it in the bootstrapper. When `#156` provisions the stock set, it also records which template agents author to, as an `agentIssueTemplate` key in `.milestone-config/driver.json`. Selection stops being a count problem for every consumer of the shared profile. This design's resolution ladder reads that key as its first rung; `#331` should adopt the same rung.

## Resolution ladder

Shared contract — all three plugins resolve identically.

| Rung | Condition | Result |
|---|---|---|
| 1 | `agentIssueTemplate` set in `.milestone-config/driver.json`, and the named file is readable | use that template |
| 2 | exactly one file in `.github/ISSUE_TEMPLATE/` | use it |
| 3 | zero templates, or two-plus with no key | built-in shape |
| 4 | — | absence **never** blocks issue creation |

Resolution happens **once per run, repo-wide** — not per finding. The template set is the same for every finding, so there is nothing per-finding to resolve. This mirrors `#331`'s resolve-once-and-hand-in contract and this repo's existing grounding-digest pattern.

**`#81` ships standalone.** Rungs 2–4 work with nothing else built. Rung 1 is inert until `#156` lands and begins writing the key; an unset key simply falls through. No blocking dependency.

## Emission — two modes

The mode is chosen by *which rung matched*, because that determines whether the template's shape is known to the suite.

### Mode A — stock or keyed template (shape known)

Reached via rung 1, or rung 2 when the single template is a suite-authored stock file.

Mirrors `#331`: translate each non-`markdown` field to `## <label>` in `body:` order.

Justified because the suite authored these templates and sized them for this use. A full translation produces no empty sections.

### Mode B — consumer-owned template (shape unknown)

Reached via rung 2 when the single template is not suite-authored.

**Structural, no semantics:** the first `textarea` field's `attributes.label` becomes a single `## <label>` heading; the entire built-in body goes underneath it; every other field is omitted.

Justified because guessing which arbitrary field means "evidence" is exactly the inference this engine refuses everywhere else (`agents/coherence-reviewer.md:58` — a finding that cannot be grounded is dropped, never guessed). Emitting all fields would also let the consumer's template size set the body length, breaking the flat-cost property at `docs/write-up.md:255` — the body must be sized by *its* finding, not by their template.

**This is a deliberate divergence from `#331`,** which translates all fields in `body:` order. The divergence is justified by a real asymmetry: the feeder authors a full issue specification with content for every section, while the reviewer emits one ~3-line finding and would render four or five empty headings. Recorded here so it reads as intentional, not as drift.

### Mode C — `.md` skeleton (resolution rung 2, `.md` file)

Mirrors `#331` exactly: use the `.md` body as the skeleton directly. Alignment is cheap on this rung and there is no field structure to reason about.

## Finding → stock `change_request.yml`

Stock section order per `#156`: Summary → Impact → Proposed solution → Non-goals → Acceptance criteria → detail.

A finding carries `description`, `symbol`, `lens`, `grounding`, `severity`.

| Section | Filled from | Notes |
|---|---|---|
| Summary | `description` + `symbol` | one plain sentence naming the change |
| Impact | `lens` | the why — what it diverges from |
| Proposed solution | the redo one-liner's scoped ask | what to do differently |
| Non-goals | **truthful constant** | *"None — filed from a single coherence finding and carrying no scope beyond it."* |
| Acceptance criteria | **derived, one checkbox** | `- [ ] <symbol> follows the pattern at <grounding>` |
| detail | `grounding` ref, **verbatim** | never a paraphrase (`docs/write-up.md:107`) |

### Dropdowns

`#156` has the stock form carry `Surface` and `Risk` dropdowns emitting values that match the label taxonomy `provision-labels` writes.

| Dropdown | Behavior |
|---|---|
| `Risk` | mapped from `severity` — `drift-trivial`/`small` → `light`; `medium`/`large` → `heavy`. Grounded: heal-routing already routes on `severity` and nothing else. |
| `Surface` | **omitted.** `ui` vs `logic` is not encoded in the finding schema. Picking one would be a guess, and a coherence finding *can* touch a UI surface. Left for whoever triages the spun-out issue. |

### Why a constant is not a fabrication

`#156`'s anti-criterion says a template forcing an agent to emit an empty or invented section is worse than no template, and `#331` parks with `PRODUCT_GAP` when a required field cannot be grounded.

**The reviewer cannot park.** `skills/review/SKILL.md` — *"The change merged regardless… coherence heals, it does not gate."* Returning a gap for an unfillable Non-goals field would make the spin-out gate on template shape, violating the tool's central invariant.

The constant resolves this without fabricating: *"None — filed from a single coherence finding"* is a **true statement about what this issue is**. It asserts nothing about the code. A single drift observation genuinely has no scope boundary to declare, and saying so is more honest than either omitting a required section or inventing scope.

## Invariants

Always true, every path:

- The `grounding` ref is present and **verbatim** in every composed body. It is never dropped, never paraphrased, and never relocated out of existence — regardless of whether the template has an evidence-shaped field. This is the anti-criterion `#81` names first, and it inherits the engine's central rule (`agents/coherence-reviewer.md:58`).
- **Never gates.** Every resolution or parse failure degrades to the built-in shape and the issue is still created. No template condition can prevent a spin-out.
- **Body length is set by the finding, not the template.** Mode B guarantees this structurally. Mode A is bounded because the suite controls the stock template's size.
- `type: markdown` blocks are display-only and never emitted.
- `attributes.value` on a textarea is a **prefill to replace**, not content to echo.
- `render:` wraps that field's content in a fenced block.
- The form's `labels:` and `title:` prefix are applied when present.

## Degradation matrix

| Condition | Behavior |
|---|---|
| no `.github/ISSUE_TEMPLATE/` directory | built-in shape |
| `agentIssueTemplate` set but file missing or unreadable | built-in shape, noted in the write-up |
| template YAML unparseable | built-in shape, noted |
| two or more templates and no `agentIssueTemplate` key | built-in shape |
| consumer template (Mode B) with zero `textarea` fields | built-in shape |
| required field ungroundable (Mode A) | truthful constant for Non-goals; any *other* ungroundable required field → built-in shape for that finding |

Every row is fail-soft and none errors, matching `.project/design-philosophy.md#Error & failure philosophy` — *absence means skip; coherence heals, it never gates*.

## Scope

**In scope:** the resolution ladder, the three emission modes, the stock mapping table, the invariants and degradation matrix above, applied to the Step 5 spin-out at `skills/review/SKILL.md:187`.

**Out of scope:**
- The write-up format, its four landing places, and the per-finding tightness rule.
- The drop-if-ungroundable inversion (`agents/coherence-reviewer.md:58`) — deliberate, stays.
- The `chore/propose-*` conventions-PR lane (`skills/review/SKILL.md:133`).
- Enforcement. Issue forms are browser-UI only; `gh issue create --body-file` bypasses them ([cli/cli#5865](https://github.com/cli/cli/issues/5865)). This is structure the agent self-imposes.
- Sweep-mode spin-outs — this design covers the `review` path; sweep is unchanged.

**Companion changes this design requires elsewhere** (filed separately, not built here):
- `#156` — write `agentIssueTemplate` to `.milestone-config/driver.json` when provisioning the stock set.
- `#331` — adopt the same rung-1 key so all three plugins resolve identically.

## Size budget

`skills/review/SKILL.md` is CI-governed at a 5090-word ceiling (`scripts/check-size-budgets.sh`), currently 5082 — **8 words of headroom**, and the ratchet only moves down. This design does **not** fit inline.

Per `#81`'s own acceptance criterion, the resolution logic goes in a single-source doc with a lean pointer from the skill, matching the `docs/heal-routing.md` pattern established in #43. Proposed: `docs/issue-templates.md`.

> **Note:** the headroom figure differs from `#81`'s body, which cites *"ceiling 5090, currently ~4913, ~177 words of headroom"*. That was measured before v0.4.0. The current measured value is 5082/5090. The single-source-doc requirement is therefore not optional.

## Corrections to `#81`'s body

Triage found two stale citations, recorded here so implementation does not propagate them:

| `#81` cites | Actual |
|---|---|
| `skills/review/SKILL.md:157` as the spin-out site | `:157` is the write-up redo-one-liner fence (Step 4). The `gh issue create` site is **`:187`** (Step 5, item 1). |
| `agents/coherence-reviewer.md:60` for drop-if-ungroundable | `:60` is *"Exactly one is the floor, not a cap on truth"*. The rule is at **`:58`**. |

## Testing

No unit-test layer exists (markdown + shell plugin). Verification is documented-contract conformance plus the two CI gates, per `.project/conventions.md#Test patterns`.

Verify by fixture: compose against (a) no template directory, (b) one stock `change_request.yml`, (c) one arbitrary consumer `.yml` with no evidence-shaped field, (d) one `.md` skeleton, (e) two templates with no key, (f) two templates with the key set. Assert in every case that the `grounding` ref appears verbatim and that an issue would be created.
