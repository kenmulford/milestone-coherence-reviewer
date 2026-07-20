<p align="center">
  <img src="assets/milestone-coherence-reviewer.svg" alt="milestone-coherence-reviewer — a milestone suite plugin" width="900">
</p>

After a change is built, checks whether it fits how the rest of the app is already built — existing helpers and patterns, your conventions, the stack's idioms — then fixes small drift inline and files bigger drift as issues or a follow-up milestone. Never blocks the merge; leaves a short note on what it changed, why, and how to redo it. Distinct from code review (correctness) and triage (design).

It has two entry points: `review` for a single built change, and `sweep` for an opt-in, app-wide consistency scan. When it spots a repeated ungoverned pattern it can also propose a `.project/conventions.md` rule as a human-gated, config-only PR — closing the loop back into your standing docs. It never touches application code or your protected branch.

```mermaid
%%{init: {"flowchart": {"wrappingWidth": 900}} }%%
flowchart TD
    cfg(["reads your .milestone-config/ profile &amp; .project/ docs — written by milestone-bootstrapper"])

    input[/"a built change — a branch or PR<br/>(runs on its own during a driver build)"/]

    subgraph loop [after a change is built — never blocks the merge]
        direction TB
        subgraph sgR [review — does it fit the app?]
            direction LR
            r1["gather how the app already<br/>does it — helpers, patterns,<br/>conventions, stack idioms"] --> r2["compare the built change<br/>against them"]
        end
        subgraph sgH [heal — route the drift]
            direction LR
            h1["small drift →<br/>fixed inline"] --> h2["bigger drift → issues or<br/>a follow-up milestone"] --> h3["leaves a note — what changed,<br/>why, how to redo it"]
        end

        sgR -->|drift found| sgH
    end

    cfg ~~~ input
    input --> sgR
    cfg <-.-|grounds every step| loop

    style cfg fill:#DEEBF5,stroke:#3A82B4,color:#15212B
    style input fill:#FFFFFF,stroke:#94A9B8,color:#33506B
    style loop fill:#F5F9FC,stroke:#B9CFDF,color:#33506B
    style sgR fill:#FFFFFF,stroke:#3A82B4,stroke-width:2px,color:#3A82B4
    style sgH fill:#FFFFFF,stroke:#5AA6D4,color:#3A82B4
    classDef action fill:#EDF4FA,stroke:#7FAECE,color:#15212B
    class r1,r2,h1,h2,h3 action
```

## How to use

In the suite, it runs on its own during a `milestone-driver` build — you don't invoke it. Standalone, point it at a branch or PR:

```
/milestone-coherence-reviewer:review <branch-or-PR>
```

To scan the whole app for standing inconsistency — not just one change — run the opt-in sweep. Broad by default, or narrow it with a pattern:

```
/milestone-coherence-reviewer:sweep [pattern]
```

## Requires

`superpowers` (from `claude-plugins-official`) — the milestone-suite's shared prerequisite. It is not installed automatically, so add it yourself; the `milestone-driver` and `milestone-feeder` tools that drive and feed this reviewer need it to run the suite.

```
/plugin marketplace add anthropics/claude-plugins-official
/plugin install superpowers@claude-plugins-official
```

If Claude Desktop shows `"Unknown command"` for this plugin's own commands, that's `superpowers` missing — run the two commands above to fix it.

## Status

Built and released. `review` and the opt-in app-wide `sweep` both work, along with inline healing, issue/milestone routing for larger drift, human-gated `.project/conventions.md` rule proposals (v0.2.0), a mechanical grounding-verify pass (v0.2.1), and recall of prior write-ups on the same files as advisory context before re-analyzing (v0.3.0). For the full version history, see [CHANGELOG.md](CHANGELOG.md). Spec in [BRIEF.md](BRIEF.md); built by `milestone-feeder` + `milestone-driver`. Part of the [milestone-suite](https://github.com/kenmulford/milestone-suite) dev-tools suite.
