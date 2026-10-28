# Codex runtime mapping

Read this when the skill runs under Codex. Claude Code needs none of it.

## Plugin root

`${CLAUDE_PLUGIN_ROOT}` is not substituted on Codex. It is the parent of the `skills/` directory that holds this file. Write the absolute path in its place in every command you run and every brief you send.

## Invocation and `$ARGUMENTS`

| Claude Code | Codex |
|---|---|
| `/milestone-coherence-reviewer:review <branch-or-PR>` | `$milestone-coherence-reviewer:review <branch-or-PR>` |
| `/milestone-coherence-reviewer:sweep [pattern]` | `$milestone-coherence-reviewer:sweep [pattern]` |
| `$ARGUMENTS` | the text after the `$milestone-coherence-reviewer:<skill>` mention in the user's message; empty when there is none |

Print the Codex form wherever a skill prints an invocation, including `review`'s 🔴 error-and-stop block.

## Engine dispatch

Each dispatch of the engine (`agents/coherence-reviewer.md`) is one `spawn_agent` call with no `agent_type`, then `wait_agent` for its return block. The message's first line is:

```
Your role instructions are in <abs plugin root>/agents/coherence-reviewer.md. Read that file first and follow it. Ignore its YAML frontmatter.
```

The rest of the message is the brief the skill specifies, plus the absolute plugin root. Dispatch counts are unchanged: `review` spawns once; a broad `sweep` spawns once per not-yet-done sub-path, waiting for each before its verify pass and checkpoint write.

## Gates

`review` and `sweep` hold no in-session approval gate. The human gate is merging or closing the config-only PR, which happens outside the session. Do not add a prompt through `request_user_input` or `request_user_input_async`.
