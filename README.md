# ccc-agent-flow

CCC is a single-session coordinator workflow for pairing Claude Code and Codex. The active session is the driver: it plans, implements, writes artifacts, and invokes the other agent non-interactively for review.

The canonical protocol lives in [protocol/CCC_PROTOCOL.md](protocol/CCC_PROTOCOL.md).

## Workflows

| Workflow | Driver | Reviewer | Reviewer command |
|---|---|---|---|
| `claude-first` | Claude Code | Codex CLI | `codex exec --sandbox read-only ...` |
| `codex-first` | Codex | Claude Code CLI | `claude --print ... --tools ""` |

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

`scripts/ccc-detect-session.sh` uses environment markers first:

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

CCC blocks instead of silently truncating when a reviewer prompt exceeds:

```text
CCC_REVIEW_PROMPT_MAX_BYTES=200000
```

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
```

Validate them with:

```text
scripts/ccc-validate.sh examples/runs/hello-world
scripts/ccc-validate.sh examples/runs/hello-world-codex-first
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
