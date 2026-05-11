# ccc-agent-flow

CCC is a minimal coordination protocol for one incremental code change reviewed by two frontier coding agents.

One agent is the driver: it plans, edits, verifies, and writes the CCC artifacts. The other agent is the reviewer: it critiques the plan or code through a non-interactive CLI call. The driver then either revises, blocks for human direction, or finishes with an explicit verdict.

Choose the direction by choosing who should own the edit:

| Start With | Use | Best When |
|---|---|---|
| Claude Code first | `claude-first` | You want Claude Code to drive planning and implementation, with Codex acting as the outside reviewer. |
| Codex first | `codex-first` | You want Codex to drive planning and implementation, with Claude Code acting as the outside reviewer. |

If you are not sure, start with the agent you are already using. CCC keeps both directions structurally identical: same run folder, same artifact names, same review contract, same modes, same validator.

The loop is intentionally narrow:

```text
task -> plan -> review -> revise plan -> code -> review -> revise code -> verdict
```

This repo is not a general autonomous software-engineering agent, a whole-repository project manager, or a generic multi-agent framework. It is a small, file-based workflow for making one change safer by forcing Claude Code and Codex to exchange structured artifacts, raw review transcripts, and bounded revision rounds.

That narrow scope is the point. CCC is useful when a single coding agent can probably make the change, but you want a second model to challenge the plan and diff before you accept it.

Good fits:

- targeted bug fixes
- config or API naming cleanup
- small refactors
- one feature slice
- review-driven hardening of an existing patch

Poor fits:

- open-ended product development
- full-repo autonomous maintenance
- long-running agent swarms
- benchmark harnesses
- replacing human code review

The canonical protocol lives in [protocol/CCC_PROTOCOL.md](protocol/CCC_PROTOCOL.md).

## Why This Exists

Most coding-agent projects are either single-agent editing tools or broad multi-agent frameworks. CCC is different because it is deliberately specific:

- **Claude Code and Codex are peers.** Either can drive, and either can review.
- **The workflow is symmetric.** `claude-first` and `codex-first` use the same artifacts, stages, verdicts, modes, and validator.
- **Artifacts are the interface.** Plans, reviews, code summaries, raw transcripts, and `.done` sentinels live in the run folder.
- **Review is bounded.** Rounds are explicit, so disagreement terminates as `blocked`, `complete`, or `APPROVE_AUTO_OVERRIDE` instead of looping forever.
- **No framework runtime is required.** CCC is a protocol plus skills and shell scripts, not a daemon, service, database, or graph engine.
- **The reviewer receives a self-contained prompt.** The driver must include the relevant task, artifacts, and git outputs, so review does not depend on hidden session memory.

## Workflows

| Workflow | Driver | Reviewer | Reviewer command | Review surface |
|---|---|---|---|---|
| `claude-first` | Claude Code | Codex CLI | `codex exec --sandbox read-only ...` | Self-contained prompt assembled by Claude Code. |
| `codex-first` | Codex | Claude Code CLI | `claude --print ... --tools ""` | Self-contained prompt assembled by Codex. |

Install and authenticate the reviewer CLI for the workflow you use.

For `claude-first`:

```text
codex login
codex login status
codex --version
codex exec --help
```

For `codex-first`:

```text
claude --version
claude --help
printf 'Return READY only.\n' | claude --print --output-format text --no-session-persistence --tools ""
```

Optional compatibility checks:

```text
scripts/ccc-check-reviewer-cli.sh claude-first
scripts/ccc-check-reviewer-cli.sh codex-first
```

## Usage

Run from the driver session:

```text
/ccc run .ccc/runs/auth-fix "Given the context above, implement the auth fix" 2,2
```

Pass the workflow explicitly when detection is unclear:

```text
/ccc run .ccc/runs/auth-fix "Given the context above, implement the auth fix" 2,2 claude-first
/ccc run .ccc/runs/auth-fix "Given the context above, implement the auth fix" 2,2 codex-first
```

Resume or cancel:

```text
/ccc resume .ccc/runs/auth-fix
/ccc cancel .ccc/runs/auth-fix "No longer needed"
```

## Detection

Explicit workflow arguments are preferred when you already know which direction you want:

```text
claude-first
codex-first
```

Selection precedence:

```text
explicit workflow argument
CCC_WORKFLOW=claude-first or CCC_WORKFLOW=codex-first
scripts/ccc-detect-session.sh
ask user to pass claude-first or codex-first
```

`CCC_WORKFLOW` values are case-sensitive. Any other value is treated as absent.

`scripts/ccc-detect-session.sh` uses environment markers:

```text
CLAUDECODE=1 or CLAUDE_CODE_SESSION_ID present -> claude
CODEX_CI=1 -> codex
both present -> unknown
otherwise -> unknown
```

Detection maps `claude` to `claude-first` and `codex` to `codex-first`. Explicit `claude-first` or `codex-first` is always authoritative and recommended when running Codex from a shell that may have inherited Claude markers.

`run.md` records:

```text
workflow: <claude-first|codex-first>
driver: <claude-code|codex>
reviewer: <codex-cli|claude-code-cli>
session_detected: <claude|codex|unknown>
workflow_source: <explicit|env|detected|persisted>
```

On resume, `workflow_source: persisted` means the workflow was reused from `run.md`; CCC does not retain the original selection source separately.

## Modes

Default mode is `normal`.

| Mode | Behavior |
|---|---|
| `manual` | Stop for user approval after each completed stage. |
| `normal` | Keep running, but block for human direction on major unresolved disagreement. |
| `auto` | Continue through reviewer disagreement and use `VERDICT: APPROVE_AUTO_OVERRIDE` at the final allowed version. Hard infrastructure or protocol failures still block. |

Examples:

```text
/ccc run .ccc/runs/auth-fix "Given the context above, implement the auth fix" 2,2 manual
/ccc resume .ccc/runs/auth-fix manual
/ccc run .ccc/runs/auth-fix "Given the context above, implement the auth fix" 2,2 auto
/ccc resume .ccc/runs/auth-fix auto
```

Mode is not persisted; `resume` defaults to `normal` unless `manual` or `auto` is passed again.

## Review Contract

Both workflows use the same self-contained review contract. The driver includes the task, relevant CCC artifacts, and relevant git outputs in the reviewer prompt. The reviewer output is captured as:

```text
state/plan_vN_review.review.raw.md
state/review_vN.review.raw.md
```

The reviewer should evaluate the prompt as the review surface. This symmetry is a tradeoff: the reviewer does not independently re-derive the whole changeset. Review integrity depends on the driver assembling the prompt faithfully, the raw transcript being preserved, and the pre/post git-diff mutation guard catching reviewer-side edits.

CCC blocks instead of silently truncating when the UTF-8 byte length of the full reviewer stdin payload exceeds:

```text
CCC_REVIEW_PROMPT_MAX_BYTES=200000
```

`claude-first` uses Codex in read-only sandbox mode. `codex-first` uses Claude Code with tools disabled through `--tools ""`; CCC checks that the CLI accepts this mode and also verifies that tracked and staged diffs do not change during code review. The `--tools ""` behavior is a Claude CLI contract, not an independent sandbox proof.

Current runs require `## Runtime` in `run.md` and `.review.raw.md` transcript names. Older local experiment folders that used `.codex.raw.md` should be recreated or renamed before validation.

## Rules

Only one coordinator session should be active for a given output folder.

Do not commit during an active CCC run. Commit only after the run reaches a terminal state.

Reviewer commands must not mutate tracked or staged repository content. CCC captures `git diff` and `git diff --cached` before and after code review commands and blocks if they differ.

## Examples

Bundled examples:

```text
examples/runs/hello-world
examples/runs/hello-world-codex-first
examples/runs/hello-world-auto-override
```

Validate them with:

```text
scripts/ccc-validate.sh examples/runs/hello-world
scripts/ccc-validate.sh examples/runs/hello-world-codex-first
scripts/ccc-validate.sh examples/runs/hello-world-auto-override
```

## Skills

Use these skills:

```text
ccc
ccc-plan
ccc-plan-review
ccc-code
ccc-code-review
```

## References

CCC sits near several existing coding-agent projects, but it has a narrower target than most of them: structured cross-review for one incremental change.

| Project | What It Is Good At | How CCC Differs |
|---|---|---|
| [OpenHands](https://github.com/All-Hands-AI/OpenHands) | autonomous software-engineering agents, sandboxed execution, SWE-style tasks | CCC is not a full autonomous agent runtime; it coordinates one bounded Claude/Codex change loop. |
| [Aider](https://github.com/Aider-AI/aider) | practical git-aware pair programming with strong editing UX | CCC separates driver and reviewer into two different agents and persists structured review artifacts. |
| Aider architect/editor patterns | splitting planning and editing across model roles | CCC specializes the pattern for Claude Code and Codex with explicit review rounds and verdicts. |
| [AutoGen](https://github.com/microsoft/autogen) | general multi-agent conversations and tool orchestration | CCC is not a framework; it is a concrete protocol for a specific coding workflow. |
| [LangGraph](https://github.com/langchain-ai/langgraph) | state-machine and graph orchestration for long-running agents | CCC uses plain files and shell-callable CLIs instead of requiring a graph runtime. |
| [MetaGPT](https://github.com/FoundationAgents/MetaGPT) | role-specialized software-company-style agent pipelines | CCC avoids broad role simulation and focuses on one implementation/review loop. |
| [ChatDev](https://github.com/OpenBMB/ChatDev) | research-style multi-agent software conversations | CCC is designed for real repository diffs, git baselines, validator checks, and CLI integration. |

The closest conceptual shape is a generator-reviewer loop:

```text
driver model -> plan/code artifact -> reviewer model -> critique -> driver revision
```

CCC keeps that shape small and concrete: one driver, one reviewer, one run folder, one incremental change. It is closer to a reproducible collaboration protocol than to an agent framework.

Study these projects for different reasons:

| Need | Look At |
|---|---|
| autonomous SWE-agent runtime | OpenHands |
| practical git-aware editing UX | Aider |
| generic multi-agent conversations | AutoGen |
| explicit state-machine orchestration | LangGraph |
| role-specialized software pipelines | MetaGPT |
| research/demo multi-agent coding conversations | ChatDev |
