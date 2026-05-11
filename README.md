# ccc-duet

CCC is a small workflow for using Claude Code and Codex on one code change. One agent plans, one agent implements, and each reviews the other at the handoff points. You run CCC from whichever agent session you want as the coordinator.

## What It Is / When To Use

A file-based protocol for making one incremental change safer through structured cross-review. Not a general autonomous agent, a repo-wide project manager, or a multi-agent framework.

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

Design rationale, full configuration, environment variables, run metadata, review contract, rules, and related work live in [DESIGN.md](DESIGN.md). The canonical protocol lives in [protocol/CCC_PROTOCOL.md](protocol/CCC_PROTOCOL.md).

## Setup

Install both CLIs:

```text
npm install -g @openai/codex @anthropic-ai/claude-code
```

Log in:

```text
codex login
claude         # then /login
```

Open your coordinator (Claude Code or Codex) and install the skills from `skills/` (`ccc`, `ccc-plan`, `ccc-plan-review`, `ccc-code`, `ccc-code-review`). After install, the coordinator is available as `/ccc` in Claude Code or `$ccc` in Codex.

Optional CLI checks:

```text
scripts/ccc-check-agent-cli.sh codex
scripts/ccc-check-agent-cli.sh claude
```

## Quick Start

```text
/ccc .ccc/runs/auth-fix "Given the context above, implement the auth fix"
$ccc .ccc/runs/auth-fix "Given the context above, implement the auth fix"
```

Syntax:

```text
/ccc <output_folder> "<task>" [pN-cM] [manual|normal|auto] [plan-code=<planner>-<coder>]
```

Defaults: `plan-code=claude-codex`, `p2-c2`, `normal`. The default run means: Claude plans, Codex reviews the plan, Codex implements, Claude reviews the code. The split is intentional — the coder critiques whether the plan is executable before implementing it, and the planner later checks whether the implementation matches the plan.

Resume or cancel:

```text
/ccc resume .ccc/runs/auth-fix
/ccc cancel .ccc/runs/auth-fix "No longer needed"
```

## What Happens

CCC creates a run folder:

```text
.ccc/runs/auth-fix/
  task.md
  run.md
  artifacts/
  state/
```

Then runs this bounded loop:

```text
task -> plan_v0 -> plan_v0_review -> code_v0 -> review_v0 -> revision or verdict
```

With the default `p2-c2`, each side can request up to two revisions (`plan_v0 -> plan_v1 -> plan_v2`, etc.). CCC stops as `complete`, `blocked`, or `canceled`. In `auto` mode it may finish with `VERDICT: APPROVE_AUTO_OVERRIDE` when disagreement remains but no more revision rounds are allowed.

## Examples

```text
scripts/ccc-validate.sh examples/runs/hello-world
scripts/ccc-validate.sh examples/runs/hello-world-codex-session
scripts/ccc-validate.sh examples/runs/hello-world-auto-override
```
