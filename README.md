# ccc-agent-flow

CCC is a Claude Code first workflow that uses the [Codex plugin for Claude Code](https://github.com/openai/codex-plugin-cc) for synchronous review passes.

The old two-session coordinator has been preserved on the pushed `two-session` branch. `main` now defaults to one Claude Code coordinator session: Claude Code plans and implements, then uses foreground Codex plugin slash commands for review stages.

## Usage

Install and set up the Codex plugin inside Claude Code:

```text
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/reload-plugins
/codex:setup
```

CCC v2 targets the `openai/codex-plugin-cc` `v1.0.4` command surface. If your installed plugin differs, verify `/codex:setup`, `/codex:review --wait`, `/codex:review --base <ref>`, and `/codex:adversarial-review --wait` before starting a run. If compatibility is unclear, CCC should block before writing stage artifacts.

Run CCC from Claude Code:

```text
/ccc run .ccc/runs/auth-fix "Given the context above, implement the auth fix" 2,2
```

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

Claude Code writes plan and code artifacts. For review artifacts, the coordinator prints an exact foreground `/codex:... --wait` command, the user runs that slash command in Claude Code, then the coordinator captures the raw result, writes the required Markdown artifact, validates it, and continues. There is no peer-session wait loop and no polling inside the model.

Raw Codex output is kept beside the `.done` files:

```text
state/plan_vN_review.codex.raw.md
state/review_vN.codex.raw.md
```

Only one Claude Code coordinator session should be active for a given output folder.

Typical review calls:

```text
/codex:adversarial-review --wait Review .ccc/runs/auth-fix/artifacts/plan_v0.md against .ccc/runs/auth-fix/task.md. Do not edit code. Return findings, questions, and whether the plan appears ready for implementation.
/codex:review --wait --base <run_start_ref>
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
