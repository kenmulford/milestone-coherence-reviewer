---
name: demo
---

Drive the resolution layer (`scripts/resolve-config.{sh,ps1}`).

   "${CLAUDE_PLUGIN_ROOT}/scripts/resolve-config.<sh|ps1>" keys <REPO_ROOT>

Read back via `"${CLAUDE_PLUGIN_ROOT}/scripts/memory-mirror.<sh|ps1>" --recall`.
The fallback is `scripts/memory-mirror.sh (resolve_target())`.
