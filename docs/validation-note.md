# Validation note — full-strength dogfood of the `domainSkills` grounding source

Tracks kenmulford/milestone-coherence-reviewer#47: a real, end-to-end dispatch of
`/milestone-coherence-reviewer:review` against a repo with a populated
`domainSkills` set — the one grounding source of the three-source claim
(`.project/` section / repo `file:line` / `domainSkills`) that had, until this
run, only ever been exercised on the 2-source degraded path (this repo's own
`.milestone-config/driver.json` carries no `domainSkills` key, legitimately —
markdown+shell has no framework, `.project/library-manifest.md#Runtime &
frameworks`).

## Outcome — happy path, AC satisfied

`FINDINGS` returned **one** finding whose `grounding` is a `domainSkills` source,
that citation **resolved** (tier 1, exact match), and the corresponding
`gh issue create` **genuinely fired**, landing a real issue in the disposable
scratch repo. Recorded below.

## Safety framing (superseded, per Ken's 2026-07-05/06 decision)

The issue's original safety claim — "creates no GitHub state anywhere" — is
**superseded**. `skills/review/SKILL.md` Step 5 unconditionally opens a real
`gh issue create` for any firing `drift-small`/`drift-medium`/standalone-degraded
`drift-trivial` finding; there is no dry-run mode. The corrected framing, as
decided on the issue: **this run creates GitHub state only in the disposable
scratch repo `kenmulford/coherence-dogfood-scratch` — never in
`kenmulford/milestone-coherence-reviewer` or any other real repo.**

Verified before writing this note (the issue's repo-selection safety
constraint): every `gh` write this run made carried an explicit
`-R kenmulford/coherence-dogfood-scratch` (never ambient default-repo). Reviewing
the scratch repo's resulting state confirms exactly the writes this run made and
nothing else — 1 PR, 1 issue, 1 PR comment, 3 branches (`main`, `develop`,
`feature/auth-token-cache`):

```
$ gh issue list -R kenmulford/coherence-dogfood-scratch --state all
#2  Revisit AuthTokenCache token storage

$ gh pr list -R kenmulford/coherence-dogfood-scratch --state all
#1  Cache the signed-in user's auth token across app restarts  feature/auth-token-cache -> develop

$ gh pr view 1 -R kenmulford/coherence-dogfood-scratch --json comments --jq '.comments | length'
1
```

The scratch repo is **not** deleted by this run — Ken removes it himself once
this note has captured the outcome, per the issue's teardown criterion.

## Fixture construction (option (b) — a fresh, minimal fixture repo)

Built fresh rather than forked (faster/safer to construct and tear down, per the
issue's own Design section), at `kenmulford/coherence-dogfood-scratch` (private,
pre-existing per the blocker-cleared comment):

| Branch | Content |
| --- | --- |
| `main` | untouched — README only |
| `develop` (`integrationBranch`) | `.milestone-config/driver.json`: `sourceGlobs: ["src/**"]`, `domainSkills: ["maui-skills:maui-secure-storage"]`, `nonNegotiables`, `integrationBranch: develop`, `protectedBranch: main` |
| `feature/auth-token-cache` (PR #1 -> `develop`) | adds `src/Services/AuthTokenCache.cs` — an `AuthTokenCache` that persists the signed-in user's token via `Preferences.Default.Set/Get/Remove("auth_token", …)` instead of `SecureStorage.Default` |

**Deliberately no `.project/` directory.** This isolates the grounding path under
test: with no sibling file under `src/**` using the correct pattern (confirmed —
`grep -rn "SecureStorage" src/` returns nothing, and `AuthTokenCache.cs` is the
only file under `sourceGlobs`) and no `.project/conventions.md` rule, the
*built-differently-from-siblings* and *ignored-convention* lenses have no real
source to ground on — leaving `domainSkills` as the **only** viable grounding
for the hand-rolled-storage pattern. This is what makes the run a clean test of
the specific source this issue exists to validate, not an accidental pass via a
different lens.

`main`/`protectedBranch` split from `develop`/`integrationBranch` (rather than
one branch doing both jobs) exists because the local `no-push` safety hook
(installed for `milestone-driver` globally) blocks a direct push to whatever
branch a repo's own `driver.json` names as `protectedBranch` — confirmed for
real when the first attempt (both keys pointed at `main`) was correctly blocked.
Not an engine defect; the fixture was corrected to a normal two-branch model.

## Methodology — how the run was driven

`skills/review/SKILL.md`'s argument contract takes only the branch/PR
(`$ARGUMENTS`) — no repo-root parameter — because it assumes the invoking
session's working directory *is* the target repo (the normal usage pattern:
you `cd` into your app repo and run the plugin from there). This dogfood ran
from an implementer subagent anchored in `milestone-coherence-reviewer`'s own
repo, so that assumption doesn't hold. Rather than invoke the `Skill` tool
(which would have resolved `REPO_ROOT` against the wrong repo), this run drove
the documented procedure directly — the same scripts, the same single real
dispatch of the engine via the `Agent` tool, the same `gh` calls — with an
explicit repo-root path substituted at every step:

| Step | Real command run |
| --- | --- |
| 1. Resolve keys | `scripts/resolve-config.sh keys <scratch-clone>` |
| 1. Resolve docs | `scripts/resolve-config.sh docs <scratch-clone> -- conventions.md#Anything` |
| 2. Diff | `git diff origin/develop...origin/feature/auth-token-cache` |
| 2. Bounded diff-keyed grep | `grep -rn "SecureStorage\|Preferences" src/`, `find src -type f` |
| 2. Engine dispatch | one `Agent` call, `subagent_type: milestone-coherence-reviewer:coherence-reviewer`, briefed with exactly the four "What you receive" parts |
| 2.5 Verify (tier 1) | `resolve-config.sh keys` output re-checked for an exact `domainSkills` string match |
| 5. Route (open issue) | `gh issue create -R kenmulford/coherence-dogfood-scratch ...` |
| 4. PR-comment mirror | `gh pr comment 1 -R kenmulford/coherence-dogfood-scratch ...` |

This is a genuine follow-up candidate to flag (not fixed here — out of scope
per this issue): **the skill has no way to point at a repo other than the
invoking session's cwd**, which is a real portability gap for exactly this kind
of subagent-driven or scripted invocation. Recorded for a human to decide
whether it merits its own issue.

## The engine dispatch — real, single, per contract

One `Agent` dispatch, `subagent_type: milestone-coherence-reviewer:coherence-reviewer`
(the production `agents/coherence-reviewer.md` definition, unmodified), briefed
with the diff, the (absent) `.project/` sections, the resolved `domainSkills`
list, and the bounded grep results — exactly its documented "What you receive"
contract. Its verbatim return:

```
REVIEWED: PR #1 in kenmulford/coherence-dogfood-scratch (branch feature/auth-token-cache -> develop)
SOURCES:
  app-grep: ran
  project-docs: none
  domain-skills: 1 source
FINDINGS:
  - symbol: AuthTokenCache (SaveToken/GetToken/ClearToken via Preferences.Default, key "auth_token")
    lens: framework-best-practice
    grounding: domainSkills:maui-skills:maui-secure-storage
    severity: drift-small
    description: Auth token is persisted via Preferences.Default (plaintext app-preferences store) instead of SecureStorage.Default; the domain skill's own worked example persists a token under the identical key "auth_token" via SecureStorage.Default.SetAsync/GetAsync/Remove, confirming this is the established MAUI idiom for exactly this case, not a hand-rolled alternative.
PROPOSALS: none
```

A scoping caveat on the key-name match: the literal `"auth_token"` also appears
in the fixture's own diff (`TokenKey = "auth_token"`), which the engine receives
directly — so the matching key name is equally consistent with the engine
echoing the change under review, and does NOT by itself prove the engine read
the cited skill's content. What this run does prove is narrower and still the
point: the `domainSkills` grounding path fired end-to-end — the finding cites
the skill, tier-1 verify resolved the citation, and the issue-opening route
executed for real. Whether the engine deep-reads skill bodies is not
established by this single case.

## Expected vs. actual

| | Expected (by fixture design) | Actual (engine's real return) | Match |
| --- | --- | --- | --- |
| Lens | `hand-rolled-library` or `framework-best-practice` (both ground on `domainSkills`) | `framework-best-practice` | yes |
| Grounding | `domainSkills:maui-skills:maui-secure-storage` | `domainSkills:maui-skills:maui-secure-storage` | yes |
| Severity | not `drift-large` (so the new-issue route fires in standalone mode) | `drift-small` | yes |
| `SOURCES.app-grep` | `ran` (diff touches `sourceGlobs`) | `ran` | yes |
| `SOURCES.project-docs` | `none` (no `.project/` in the fixture, by design) | `none` | yes |
| `SOURCES.domain-skills` | `1 source` (one entry in the fixture) | `1 source` | yes |
| `PROPOSALS` | `none` (no `.project/conventions.md` to extend — Step 3's degraded-repo suppression) | `none` | yes |

## Verify pass (Step 2.5, issue #38) — tier 1 only, as this issue's design specifies

Per this issue's own recorded Design section, a `domainSkills` grounding never
exercises tier 2 (no live-resolution path exists for it — `docs/analyze-once.md`
§"Tier 2"); only tier 1 applies. Tier 1 checked the finding's
`domainSkills:maui-skills:maui-secure-storage` grounding against this run's own
Step 1 resolved-keys cache:

```
$ resolve-config.sh keys <scratch-clone> | grep domainSkills
KEY	domainSkills	maui-skills:maui-secure-storage
```

Exact string match. Tier 1 passed. **0 findings dropped** — no drop-count line
would render in the write-up (consistent with `docs/write-up.md`
§"Dropped-grounding count").

## Real artifacts

- Scratch repo: https://github.com/kenmulford/coherence-dogfood-scratch (private — Ken removes it after this note captures the outcome)
- PR #1 (the change under review): https://github.com/kenmulford/coherence-dogfood-scratch/pull/1
- Issue #2 (opened by the real `gh issue create` this run fired — the AC's core requirement): https://github.com/kenmulford/coherence-dogfood-scratch/issues/2
- PR comment (the inline write-up's PR-comment mirror): https://github.com/kenmulford/coherence-dogfood-scratch/pull/1#issuecomment-4888952730

## Mirrors (Step 4)

| Mirror | Outcome |
| --- | --- |
| Inline summary (primary) | rendered above, and posted as the PR comment |
| PR comment | posted for real (link above) — the reachable mirror, since PR #1 exists |
| Issue comment | skipped and noted — no pre-existing issue context (the change under review is a PR, not an issue) |
| Memory | **intentionally not exercised**, by scope decision for this run — see below |

**Memory mirror — deliberately skipped, not a failure.** `scripts/memory-mirror.sh`'s
detect-or-fallback resolution (leg 1) would have targeted a *real*, non-scratch
Obsidian vault (`$NPM_CLAUDE_VAULT_ROOT` is set in this environment and
`Claude Memory/MEMORY.md` already exists under it — the genuine opt-in signal
the helper checks for). Appending a throwaway dogfood entry there would leak a
side effect of this run outside the disposable-scratch-repo boundary the
issue's decision establishes for *every other* write this run makes. This is a
scope decision for this run, not an engine defect: the helper's target-resolution
logic (`scripts/memory-mirror.sh`) was read and confirmed correct against the
write-up contract (`docs/write-up.md` §"The memory mirror") — it would have
worked exactly as designed, which is precisely why it was skipped here.

## Genuine follow-up candidates (not fixed here — out of scope for this issue)

1. **No repo-root parameter on `/review`'s argument contract** — see
   "Methodology" above. A real portability gap for non-cwd-anchored invocations;
   flagged for a human decision on whether it warrants its own issue.

No other engine defects surfaced. The dispatch, grounding, routing, and mirror
behavior all matched the documented contract exactly — this was a clean,
full-strength validation of the previously-unexercised `domainSkills` path.
