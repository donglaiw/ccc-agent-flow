# ccc-agent-flow

CCC is a minimal coordination protocol for one incremental code change reviewed by Claude Code and Codex.

It separates three choices that are often conflated:

| Choice | Meaning | Default |
|---|---|---|
| `main=claude|codex` | Which agent session coordinates the run. | `main=claude` |
| `plan-code=<planner>-<coder>` | Which agent plans and which agent implements. | `plan-code=claude-codex` |
| `manual|normal|auto` | How much human approval is needed between stages. | `normal` |

The default is intentionally opinionated:

```text
main=claude plan-code=claude-codex p2-c2 normal
```

That means Claude Code coordinates the run, Claude plans, Codex implements, each side can request up to two revisions, and unresolved major disagreement blocks for human direction. This matches the common model-strength split: Claude is often better at planning and review, while Codex is often better at implementation.

Run from Codex instead when that is where your subscription, context window, or active work already lives:

```text
main=codex plan-code=claude-codex p2-c2 normal
```

The loop is intentionally narrow:

```text
task -> plan -> plan review -> code -> code review -> revision or verdict
```

This repo is not a general autonomous software-engineering agent, a whole-repository project manager, or a generic multi-agent framework. It is a small, file-based workflow for making one change safer by forcing two coding agents to exchange structured artifacts, raw review transcripts, and bounded revision rounds.

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

Most coding-agent projects are either single-agent editing tools or broad multi-agent frameworks. CCC is deliberately specific:

- **Planning and implementation are configurable.** Use the default `claude-codex`, reverse it with `codex-claude`, or run same-agent loops with `claude-claude` or `codex-codex`.
- **The main session is configurable.** Coordinate from Claude or Codex without changing the artifact contract.
- **Artifacts are the interface.** Plans, reviews, code summaries, raw transcripts, and `.done` sentinels live in the run folder.
- **Review is bounded.** Rounds are explicit, so disagreement terminates as `blocked`, `complete`, or `APPROVE_AUTO_OVERRIDE` instead of looping forever.
- **No framework runtime is required.** CCC is a protocol plus skills and shell scripts, not a daemon, service, database, or graph engine.
- **The reviewer receives a self-contained prompt.** The coordinator includes the relevant task, artifacts, and git outputs, so review does not depend on hidden session memory.

## Stage Ownership

`plan-code=<planner>-<coder>` controls the four stage owners:

| Stage | Owner |
|---|---|
| `plan_vN` | planner |
| `plan_vN_review` | coder |
| `code_vN` | coder |
| `review_vN` | planner |

Examples:

| Config | Behavior |
|---|---|
| `plan-code=claude-codex` | Claude plans and reviews code; Codex reviews plans and implements. |
| `plan-code=codex-claude` | Codex plans and reviews code; Claude reviews plans and implements. |
| `plan-code=claude-claude` | Claude owns every stage, still using CCC artifacts and validation. |
| `plan-code=codex-codex` | Codex owns every stage, still using CCC artifacts and validation. |

## Setup

Install and authenticate whichever companion CLI may be invoked by the main session.

For Codex:

```text
codex login
codex login status
codex --version
codex exec --help
```

For Claude Code:

```text
claude --version
claude --help
printf 'Return READY only.\n' | claude --print --output-format text --no-session-persistence --tools ""
```

Optional compatibility checks:

```text
scripts/ccc-check-agent-cli.sh codex
scripts/ccc-check-agent-cli.sh claude
```

## Usage

Default run:

```text
/ccc run .ccc/runs/auth-fix "Given the context above, implement the auth fix"
```

Equivalent explicit form:

```text
/ccc run .ccc/runs/auth-fix "Given the context above, implement the auth fix" main=claude plan-code=claude-codex p2-c2 normal
```

Run the coordinator from Codex while keeping Claude as planner and Codex as coder:

```text
/ccc run .ccc/runs/auth-fix "Given the context above, implement the auth fix" main=codex plan-code=claude-codex p2-c2 normal
```

Reverse the planning and coding assignment:

```text
/ccc run .ccc/runs/auth-fix "Given the context above, implement the auth fix" main=claude plan-code=codex-claude p2-c2 normal
```

Resume or cancel:

```text
/ccc resume .ccc/runs/auth-fix
/ccc cancel .ccc/runs/auth-fix "No longer needed"
```

## Arguments

Optional arguments may appear in any order.

| Argument | Values | Default |
|---|---|---|
| `main=...` | `main=claude`, `main=codex` | `main=claude` |
| `plan-code=...` | `claude-codex`, `codex-claude`, `claude-claude`, `codex-codex` | `plan-code=claude-codex` |
| rounds | `p1-c1`, `p2-c2`, `p3-c2`, etc. | `p2-c2` |
| mode | `manual`, `normal`, `auto` | `normal` |

`p2-c2` means:

```text
2 plan revisions after plan_v0
2 code revisions after code_v0
```

So the maximum versions are:

```text
plan_v0 -> plan_v1 -> plan_v2
code_v0 -> code_v1 -> code_v2
```

## Detection

Explicit `main=...` is preferred.

Selection precedence:

```text
main=claude or main=codex argument
CCC_MAIN=claude or CCC_MAIN=codex
default main=claude
```

`CCC_MAIN` values are case-sensitive. Any other value is treated as absent.

`plan-code` selection is simpler:

```text
plan-code=... argument
CCC_PLAN_CODE=claude-codex, codex-claude, claude-claude, or codex-codex
default plan-code=claude-codex
```

`scripts/ccc-detect-session.sh` uses environment markers:

```text
CLAUDECODE=1 or CLAUDE_CODE_SESSION_ID present -> claude
CODEX_CI=1 -> codex
both present -> unknown
otherwise -> unknown
```

Detection records `session_detected` and lets the coordinator catch obvious mismatches. If you run CCC from Codex, pass `main=codex` explicitly or set `CCC_MAIN=codex`.

`run.md` records:

```text
main: <claude|codex>
planner: <claude|codex>
coder: <claude|codex>
plan_code: <claude-codex|codex-claude|claude-claude|codex-codex>
session_detected: <claude|codex|unknown>
main_source: <explicit|env|default|persisted>
plan_code_source: <explicit|env|default|persisted>
```

On resume, persisted values are reused unless explicitly overridden.

## Modes

Default mode is `normal`.

| Mode | Behavior |
|---|---|
| `manual` | Stop for user approval after each completed stage. |
| `normal` | Keep running, but block for human direction on major unresolved disagreement. |
| `auto` | Continue through reviewer disagreement and use `VERDICT: APPROVE_AUTO_OVERRIDE` at the final allowed version. Hard infrastructure or protocol failures still block. |

Mode is not persisted; `resume` defaults to `normal` unless `manual` or `auto` is passed again.

## Review Contract

All cross-agent calls use a self-contained prompt. The coordinator includes the task, relevant CCC artifacts, and relevant git outputs. The reviewer output is captured as:

```text
state/plan_vN_review.review.raw.md
state/review_vN.review.raw.md
```

This symmetry is a tradeoff: the reviewer does not independently re-derive the whole changeset. Review integrity depends on the coordinator assembling the prompt faithfully, preserving the raw transcript, and using the pre/post git-diff mutation guard around code review commands.

CCC blocks instead of silently truncating when the UTF-8 byte length of the full stdin payload exceeds:

```text
CCC_REVIEW_PROMPT_MAX_BYTES=200000
```

## Rules

Only one coordinator session should be active for a given output folder.

Do not commit during an active CCC run. Commit only after the run reaches a terminal state.

Reviewer commands must not mutate tracked or staged repository content. CCC captures `git diff` and `git diff --cached` before and after code review commands and blocks if they differ.

## Examples

Bundled examples:

```text
examples/runs/hello-world
examples/runs/hello-world-main-codex
examples/runs/hello-world-auto-override
```

Validate them with:

```text
scripts/ccc-validate.sh examples/runs/hello-world
scripts/ccc-validate.sh examples/runs/hello-world-main-codex
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
| [Aider](https://github.com/Aider-AI/aider) | practical git-aware pair programming with strong editing UX | CCC separates planning, coding, and review ownership into explicit artifacts. |
| Aider architect/editor patterns | splitting planning and editing across model roles | CCC specializes the pattern for Claude Code and Codex with explicit review rounds and verdicts. |
| [AutoGen](https://github.com/microsoft/autogen) | general multi-agent conversations and tool orchestration | CCC is not a framework; it is a concrete protocol for a specific coding workflow. |
| [LangGraph](https://github.com/langchain-ai/langgraph) | state-machine and graph orchestration for long-running agents | CCC uses plain files and shell-callable CLIs instead of requiring a graph runtime. |
| [MetaGPT](https://github.com/FoundationAgents/MetaGPT) | role-specialized software-company-style agent pipelines | CCC avoids broad role simulation and focuses on one implementation/review loop. |
| [ChatDev](https://github.com/OpenBMB/ChatDev) | research-style multi-agent software conversations | CCC is designed for real repository diffs, git baselines, validator checks, and CLI integration. |

The closest conceptual shape is a generator-reviewer loop:

```text
planner -> plan -> coder review -> coder implementation -> planner review -> revision or verdict
```

CCC keeps that shape small and concrete: one coordinator, two configurable stage owners, one run folder, one incremental change.
