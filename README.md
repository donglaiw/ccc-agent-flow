# ccc-agent-flow

CCC is a Claude Code first workflow that uses the Codex CLI for automatic review passes.

Claude Code plans and implements, then runs Codex non-interactively for review stages in the same session.

## Usage

Install and authenticate the Codex CLI:

```text
codex login
codex login status
codex --version
codex exec --help
codex exec review --help
```

The canonical protocol pins the supported Codex CLI command surface. If compatibility is unclear, CCC should block before writing stage artifacts.

Run CCC from Claude Code:

```text
/ccc run .ccc/runs/auth-fix "Given the context above, implement the auth fix" 2,2
```

Default mode is `normal`: CCC keeps running automatically, but waits for a human decision if major reviewer disagreement remains after the configured rounds.

Use `manual` to require approval after each completed CCC stage:

```text
/ccc run .ccc/runs/auth-fix "Given the context above, implement the auth fix" 2,2 manual
/ccc resume .ccc/runs/auth-fix manual
```

Use `auto` to keep going without human approval when the reviewer and driver still disagree:

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

CCC runs sequentially in one Claude Code session.

Claude Code writes plan and code artifacts. For review artifacts, the coordinator runs a non-interactive `codex` command, captures the final Codex message, writes the required Markdown artifact, validates it, and continues. There is no polling loop and no manual Codex trigger.

Raw Codex output is kept beside the `.done` files:

```text
state/plan_vN_review.codex.raw.md
state/review_vN.codex.raw.md
```

Only one Claude Code coordinator session should be active for a given output folder.

Typical review calls:

```text
codex exec --sandbox read-only --output-last-message .ccc/runs/auth-fix/state/plan_v0_review.codex.raw.md -
codex exec review --uncommitted --output-last-message .ccc/runs/auth-fix/state/review_v0.codex.raw.md -
```

## Example

See [examples/runs/hello-world](examples/runs/hello-world) for a complete small run with plan, Codex-backed review, code, follow-up review, state sentinels, and `run.md`.

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
