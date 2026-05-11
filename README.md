# ccc-agent-flow

CCC is a single-session coordinator workflow that can run Claude-first or Codex-first.

The active session plans and implements, then runs the other agent non-interactively for review stages in the same repository.

## Usage

Install and authenticate the reviewer CLI for the workflow you want.

For Claude-first runs, Claude Code is the driver and Codex CLI is the reviewer:

```text
codex login
codex login status
codex --version
codex exec --help
codex exec review --help
```

For Codex-first runs, Codex is the driver and Claude Code CLI is the reviewer:

```text
claude --version
claude --help
claude --print --output-format text --no-session-persistence --tools "" "Return READY"
```

The canonical protocol pins the supported reviewer command surfaces. If compatibility is unclear, CCC should block before writing stage artifacts.

Run CCC from the driver session:

```text
/ccc run .ccc/runs/auth-fix "Given the context above, implement the auth fix" 2,2
```

CCC tries to detect whether it is running in a Claude Code or Codex session at startup. If detection is unclear, pass the workflow explicitly:

```text
/ccc run .ccc/runs/auth-fix "Given the context above, implement the auth fix" 2,2 claude-first
/ccc run .ccc/runs/auth-fix "Given the context above, implement the auth fix" 2,2 codex-first
```

The helper `scripts/ccc-detect-session.sh` performs env-var-first best-effort detection: `CLAUDECODE=1` or `CLAUDE_CODE_SESSION_ID` means `claude`, and `CODEX_CI=1` means `codex`. Some apps do not expose reliable shell markers, so explicit `claude-first` or `codex-first` is always valid.

Default mode is `normal`: CCC keeps running automatically, but waits for a human decision if major reviewer disagreement remains after the configured rounds.

Use `manual` to require approval after each completed CCC stage:

```text
/ccc run .ccc/runs/auth-fix "Given the context above, implement the auth fix" 2,2 manual
/ccc resume .ccc/runs/auth-fix manual
```

Use `auto` to keep going without human approval when the reviewer and driver still disagree. In `auto` mode, content-level reviewer `BLOCKER` findings are overridden at the final allowed version with `VERDICT: APPROVE_AUTO_OVERRIDE`; hard infrastructure or protocol failures still block.

```text
/ccc run .ccc/runs/auth-fix "Given the context above, implement the auth fix" 2,2 auto
/ccc resume .ccc/runs/auth-fix auto
```

Mode is not persisted; `resume` defaults to `normal` unless `manual` or `auto` is passed again.

Do not commit during an active CCC run; commit after the run reaches a terminal state.

Resume an interrupted run:

```text
/ccc resume .ccc/runs/auth-fix
```

Cancel a run:

```text
/ccc cancel .ccc/runs/auth-fix "No longer needed"
```

The canonical workflow, artifact names, verdicts, validation rules, and round semantics live in [protocol/CCC_PROTOCOL.md](protocol/CCC_PROTOCOL.md).

## How It Works

CCC runs sequentially in one driver session.

The driver writes plan and code artifacts. For review artifacts, the coordinator runs a non-interactive reviewer command, captures the final reviewer message, writes the required Markdown artifact, validates it, and continues. There is no polling loop and no manual reviewer trigger.

Raw reviewer output is kept beside the `.done` files:

```text
state/plan_vN_review.review.raw.md
state/review_vN.review.raw.md
```

Only one coordinator session should be active for a given output folder.

Typical Claude-first review calls:

```text
codex exec --sandbox read-only --output-last-message .ccc/runs/auth-fix/state/plan_v0_review.review.raw.md -
codex exec review --uncommitted --output-last-message .ccc/runs/auth-fix/state/review_v0.review.raw.md -
```

Typical Codex-first review calls use `claude --print --output-format text --no-session-persistence --tools ""` and capture stdout to `state/<stage>.review.raw.md`.

## Example

See [examples/runs/hello-world](examples/runs/hello-world) for a complete small run with plan, reviewer-backed review, code, follow-up review, state sentinels, and `run.md`.

Validate a run folder with:

```text
scripts/ccc-validate.sh examples/runs/hello-world
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
