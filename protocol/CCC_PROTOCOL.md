# CCC Protocol

This file is the canonical CCC workflow specification. README files and skills should point here instead of repeating these rules.

CCC is a single-session coordinator workflow for one incremental code change. The coordinator runs in either Claude Code or Codex, assigns planning and coding stages to Claude or Codex, writes versioned artifacts, and stops at a clear verdict.

Do not use `.ccc/current_run`; the output folder is always explicit.

## Defaults

The default run is:

```text
main=claude plan-code=claude-codex p2-c2 normal
```

Meaning:

```text
main=claude              Claude Code coordinates the run.
plan-code=claude-codex   Claude owns planning and code review; Codex owns plan review and coding.
p2-c2                    allow plan_v0..plan_v2 and code_v0..code_v2.
normal                   block for human direction on unresolved major disagreement.
```

Use `main=codex` when the coordinator should run from Codex because that is where the active context, subscription, or token budget lives.

## Agents

CCC recognizes two agent names in configuration:

```text
claude
codex
```

CLI requirements:

```text
claude  Claude Code CLI with `claude --print`
codex   Codex CLI with `codex exec`
```

Check local CLI compatibility when practical:

```text
scripts/ccc-check-agent-cli.sh claude
scripts/ccc-check-agent-cli.sh codex
```

CCC uses non-interactive companion calls. It must not ask the user to run `/codex:` or `/claude:` slash commands.

## Syntax

```text
/ccc run <output_folder> "<task>" [pN-cM] [manual|normal|auto] [main=claude|main=codex] [plan-code=<planner>-<coder>]
/ccc resume <output_folder> [manual|normal|auto] [main=claude|main=codex] [plan-code=<planner>-<coder>]
/ccc cancel <output_folder> "<reason>"
```

Valid `plan-code` values:

```text
plan-code=claude-codex
plan-code=codex-claude
plan-code=claude-claude
plan-code=codex-codex
```

Optional arguments may appear in any order. Reject duplicate arguments of the same type. On parse errors, print the error and stop without creating or modifying the run folder.

Argument defaults:

```text
main       claude
plan-code  claude-codex
rounds     p2-c2
mode       normal
```

`pN-cM` means:

```text
plan_rounds: N
revision_rounds: M
```

The older `N,M` spelling may be accepted as an alias for `pN-cM`, but new docs should use `pN-cM`.

Mode is not persisted in `run.md`; `/ccc resume <output_folder>` defaults to `normal` unless `manual` or `auto` is passed again.

`main` and `plan-code` are persisted in `run.md`. `/ccc resume <output_folder>` reuses persisted values unless the user passes explicit replacements.

Plan-code selection precedence:

```text
1. If the command includes plan-code=<planner>-<coder>, use it.
2. Else, if CCC_PLAN_CODE is a valid planner-coder pair, use it.
3. Else, use default plan-code=claude-codex.
```

`CCC_PLAN_CODE` values are case-sensitive and must be one of `claude-codex`, `codex-claude`, `claude-claude`, or `codex-codex`. Any other value is treated as absent.

## Main Detection

Main selection precedence:

```text
1. If the command includes main=claude or main=codex, use it.
2. Else, if CCC_MAIN is claude or codex, use it.
3. Else, use default main=claude.
```

`CCC_MAIN` values are case-sensitive and must be exactly `claude` or `codex`. Any other value is treated as absent. Explicit command arguments always override `CCC_MAIN`.

Detection uses agent-provided environment markers:

```text
CLAUDECODE=1 or CLAUDE_CODE_SESSION_ID present -> claude
CODEX_CI=1 -> codex
both Claude and Codex markers present -> unknown
otherwise -> unknown
```

Shell markers are best-effort. Do not rely on parent-process names except as a future fallback; wrappers, sandboxes, tmux, and login shells make process-name detection unstable.

The coordinator still runs `scripts/ccc-detect-session.sh` at run start and records `session_detected`. If detection confidently reports a different agent from the selected `main`, stop before writing stage artifacts unless the user explicitly confirms the mismatch. A Codex user should pass `main=codex` or set `CCC_MAIN=codex`.

## Stage Ownership

`plan-code=<planner>-<coder>` controls ownership:

```text
plan_vN          planner
plan_vN_review   coder
code_vN          coder
review_vN        planner
```

The coordinator is the `main` agent. If a stage owner equals `main`, perform the stage directly in the current session. If the stage owner differs from `main`, invoke that owner through its non-interactive CLI and then validate the resulting artifact before writing `.done`.

This keeps the common default optimized for model strengths:

```text
Claude plans and reviews code.
Codex reviews plans and implements code.
```

## Modes

```text
manual  complete one stage, write its artifact and .done file, update run.md, then stop for user approval before the next stage
normal  run stages until complete, blocked, or canceled; unresolved major reviewer disagreement waits for a human decision
auto    run stages until complete, blocked by hard failure, or canceled; unresolved reviewer disagreement does not require human approval
```

Mode decisions:

| Situation | manual | normal | auto |
|---|---|---|---|
| Any stage completes | Stop for user approval before the next stage. | Continue. | Continue. |
| Review approves | Continue, subject to the manual approval stop above. | Continue. | Continue. |
| Review requests changes and another version is allowed | Stop for user approval before the next stage. | Write the next version. | Write the next version. |
| Review reports `BLOCKER` and another version is allowed | Block unless the user explicitly directs a clear fix. | Block unless the user explicitly directs a clear fix. | Treat as content-level reviewer disagreement and write the next version. |
| No version remains and unresolved findings are minor-only | Complete or advance with `VERDICT: APPROVE_WITH_MINOR_COMMENTS`. | Complete or advance with `VERDICT: APPROVE_WITH_MINOR_COMMENTS`. | Complete or advance with `VERDICT: APPROVE_AUTO_OVERRIDE`. |
| No version remains and unresolved findings are major or reviewer `BLOCKER` | Block for human decision. | Block for human decision. | Complete or advance with `VERDICT: APPROVE_AUTO_OVERRIDE`. |
| Hard failure | Block. | Block. | Block. |

Hard failures originate from the coordinator or infrastructure, not from reviewer prose: invalid CLI or auth state, failed commands, missing raw transcripts, validation failure, repository mutation, `HEAD` divergence, invalid baseline, prompt budget overflow, parse errors, and user cancellation.

## Rounds

CCC uses zero-based versions. `p2-c2` allows:

```text
plan_v0 -> plan_v0_review -> plan_v1 -> plan_v1_review -> plan_v2
code_v0 -> review_v0 -> code_v1 -> review_v1 -> code_v2
```

The final artifact at the maximum version is a decision point, not automatically an approval in `manual` or `normal` mode. `auto` mode may override unresolved reviewer disagreement at this point.

## Output Folder

The coordinator creates:

```text
<output_folder>/
  task.md
  run.md
  artifacts/
  state/
```

## Run File

When starting a new run, the coordinator writes `<output_folder>/task.md`, captures the git baseline files, and initializes `<output_folder>/run.md`.

`run.md` must include:

```text
# CCC Run

## Description
## Runtime
## Rounds
## Task Summary
## Git Baseline
## Workflow State
## Status
```

`## Runtime` records:

```text
main: <claude|codex>
planner: <claude|codex>
coder: <claude|codex>
plan_code: <claude-codex|codex-claude|claude-claude|codex-codex>
session_detected: <claude|codex|unknown>
main_source: <explicit|env|default|persisted>
plan_code_source: <explicit|env|default|persisted>
```

`plan_code` must equal `<planner>-<coder>`.

On resume, `main_source: persisted` and `plan_code_source: persisted` record that stored values were reused for that invocation. CCC does not preserve the original selection source separately.

`## Rounds` uses:

```text
plan_rounds: <N>
revision_rounds: <M>
```

`## Git Baseline` records:

```text
run_start_ref: <git sha or 4b825dc642cb6eb9a060e54bf8d69288fbee4904>
run_start_ref_kind: head | empty_tree
run_start_status_file: state/run_start.status
run_start_unstaged_diff: state/run_start.diff
run_start_staged_diff: state/run_start_cached.diff
```

`state/run_start.status` is the exact stdout of `git status --short` at run start. An empty file means the run started clean.

For normal repositories, `run_start_ref` is `git rev-parse --verify HEAD` and `run_start_ref_kind` is `head`.

For fresh repositories with no commits, `run_start_ref` is the Git empty-tree SHA `4b825dc642cb6eb9a060e54bf8d69288fbee4904` and `run_start_ref_kind` is `empty_tree`.

`## Workflow State` is machine-readable:

```text
current_stage: <stage|none>
latest_artifact: <artifact path|none>
latest_verdict: <APPROVE|APPROVE_WITH_MINOR_COMMENTS|APPROVE_AUTO_OVERRIDE|NEEDS_CHANGES|BLOCKER|none>
next_action: <stage|complete|blocked|canceled>
```

`## Status` must contain exactly one of:

```text
active
complete
blocked
canceled
```

All `run.md` writes use a temporary file in the same directory, then an atomic rename.

## Agent Calls

Stages owned by the main agent are performed directly in the current session with the matching stage skill.

Stages owned by the other agent use a non-interactive CLI call from the repository root.

For Codex-owned stages:

```text
codex exec --output-last-message <output-file> -
```

For Codex-owned read-only review stages, add:

```text
--sandbox read-only
```

For Claude-owned stages:

```text
claude --print --output-format text --no-session-persistence
```

For Claude-owned read-only review stages, add:

```text
--tools ""
```

`--tools ""` is a Claude CLI contract, not an independent sandbox proof. Use `scripts/ccc-check-agent-cli.sh claude` when practical.

## Review Prompt Contract

All cross-agent calls use self-contained prompts. The coordinator includes the task, relevant CCC artifacts, and relevant git outputs. The recipient evaluates exactly the prompt contents.

This symmetry is a deliberate tradeoff. The recipient does not independently re-derive the whole changeset from repository state. Integrity depends on the coordinator assembling a complete prompt, preserving raw transcripts for review stages, and using the pre/post git-diff mutation guard for code review commands.

Before invoking another agent, compute the UTF-8 byte length of the exact stdin payload. The default ceiling is:

```text
CCC_REVIEW_PROMPT_MAX_BYTES=200000
```

If the prompt would exceed the ceiling, stop with `Status: blocked` before writing the raw transcript and report:

```text
Reviewer prompt exceeds CCC_REVIEW_PROMPT_MAX_BYTES; narrow the task, reduce the diff, or raise the limit explicitly.
```

Reviewer prompts must include:

```text
Do not edit files.
Review only the artifacts and diffs included in this prompt. Do not inspect other repository files.
Tag each finding as [minor] or [major].
READY: yes|no
```

The coordinator maps readiness to CCC verdicts:

```text
READY: yes with no material findings      -> VERDICT: APPROVE
READY: yes with only minor findings       -> VERDICT: APPROVE_WITH_MINOR_COMMENTS
READY: no with fixable findings           -> VERDICT: NEEDS_CHANGES
READY: no with external blocker/unsafe uncertainty -> VERDICT: BLOCKER
```

The coordinator saves raw reviewer output at:

```text
state/plan_vN_review.review.raw.md
state/review_vN.review.raw.md
```

The CCC review artifact is an attested summary of the raw reviewer output, not a replacement for it. The coordinator may write the final `VERDICT:` line after interpreting the raw output, but it must not silently soften or discard material findings.

Reviewer prose cannot promote a finding to hard-failure status. Hard failures are detected only by coordinator-side checks.

## Git Review Baseline

Driver commits during a run are not allowed. The intended review surface is the working tree relative to `run_start_ref`.

When `run_start_ref_kind` is `head`, confirm `git rev-parse HEAD` equals `run_start_ref` before any code-review command. If `HEAD` has moved, stop with `Status: blocked`; recover by restoring `HEAD` to `run_start_ref`, or cancel and start a new run.

Use these git outputs in code-review prompts:

```text
git status --short
git diff --stat <run_start_ref>...HEAD
git diff <run_start_ref>...HEAD
git diff --cached
git diff
```

When `run_start_ref_kind` is `empty_tree`, compare the empty tree to `HEAD` without triple-dot merge-base syntax:

```text
git status --short
git diff --stat 4b825dc642cb6eb9a060e54bf8d69288fbee4904 HEAD
git diff 4b825dc642cb6eb9a060e54bf8d69288fbee4904 HEAD
git diff --cached
git diff
```

To guard tracked and staged repository content, capture `git diff` and `git diff --cached` immediately before and after any code-review command. If the before/after outputs differ, stop with `Status: blocked`, report the mutation diff to the user, and require the user to restore or stash those changes before resuming.

## Verdicts

All review artifacts use exactly one whole-line verdict:

```text
VERDICT: APPROVE
VERDICT: APPROVE_WITH_MINOR_COMMENTS
VERDICT: APPROVE_AUTO_OVERRIDE
VERDICT: NEEDS_CHANGES
VERDICT: BLOCKER
```

`APPROVE_AUTO_OVERRIDE` is machine-readable evidence that the coordinator proceeded in `auto` mode despite unresolved reviewer disagreement. It must include exactly one whole line beginning with `AUTO OVERRIDE:` in the artifact's `## Summary`.

Minor issues are non-material comments, nits, or follow-up suggestions that do not affect correctness, safety, data integrity, public contracts, user-visible behavior, or verification. Major issues affect one of those areas or make the result unsafe to judge. Findings must be tagged `[minor]` or `[major]`; ambiguous severity is major.

## Transitions

Planning:

```text
planner writes artifacts/plan_vN.md
coordinator writes state/plan_vN.done
coder reviews plan_vN and writes artifacts/plan_vN_review.md
coordinator writes state/plan_vN_review.done
```

If plan review approves, move to code. If it requests changes and another plan version is allowed, planner writes the next plan. If no version remains, follow the mode table.

Code:

```text
coder writes artifacts/code_vN.md
coordinator writes state/code_vN.done
planner reviews code_vN and writes artifacts/review_vN.md
coordinator writes state/review_vN.done
```

If code review approves, the workflow is complete. If it requests changes and another code version is allowed, coder writes the next code version. If no version remains, follow the mode table.

## Artifact Contracts

`plan_vN.md` required sections:

```text
# Plan vN
## Summary
## Scope
## Proposed Changes
## Files and Areas
## Verification Plan
## Risks and Questions
## Changes Since Previous Plan Version
```

`plan_v0.md` must write `Initial plan.` in `Changes Since Previous Plan Version`.

`plan_vN_review.md` required sections:

```text
# Plan vN Review
## Summary
## Findings
## Questions
## Verdict
```

Each `plan_vN_review.md` must have a corresponding non-empty raw transcript:

```text
state/plan_vN_review.review.raw.md
```

`code_vN.md` required sections:

```text
# Code vN
## Overview
## What Changed
## Implementation Details
## Files Changed
| File | Purpose |
|---|---|
## Git Baseline
## Verification
## Review Focus
## Risks and Unknowns
## Changes Since Previous Code Version
```

`## Git Baseline` must include:

```text
run_start_ref: <sha>
current_head: <sha|none>
```

`code_v0.md` must write `Initial implementation.` in `Changes Since Previous Code Version`.

`review_vN.md` required sections:

```text
# Review vN
## Summary
## Diff Baseline
## Findings
## Tests to Add
## Questions
## Verdict
```

`## Diff Baseline` must include:

```text
run_start_ref: <sha>
```

Each `review_vN.md` must have a corresponding non-empty raw transcript:

```text
state/review_vN.review.raw.md
```

## Write Ordering

For every stage, write files in this order:

```text
1. For reviewer stages, write state/<stage>.review.raw.md.tmp and atomically rename it to state/<stage>.review.raw.md.
2. Write artifacts/<stage>.md.tmp.
3. Validate the intended final artifact path and required raw transcript, when applicable.
4. Atomically rename artifacts/<stage>.md.tmp to artifacts/<stage>.md.
5. Write state/<stage>.done.tmp.
6. Atomically rename state/<stage>.done.tmp to state/<stage>.done.
7. Update run.md through a same-directory temporary file and atomic rename.
```

The `.done` file is the commit point for a stage.

## Validation Before .done

Before writing `.done`, validate:

```text
artifact exists
artifact is non-empty
expected top-level heading exists exactly once
required sections exist exactly as listed
review artifacts contain exactly one valid whole-line VERDICT
APPROVE_AUTO_OVERRIDE has exactly one whole "AUTO OVERRIDE:" line in ## Summary, and no other verdict uses "AUTO OVERRIDE:" lines
plan_v0 and code_v0 have required Changes Since text
code_vN Git Baseline contains run_start_ref and current_head
review_vN Diff Baseline SHA equals run_start_ref from run.md
plan_vN_review and review_vN have non-empty state/<stage>.review.raw.md files
```

Filename-to-heading validation is exact:

```text
plan_v(0|[1-9][0-9]*)\.md          -> # Plan v\1
plan_v(0|[1-9][0-9]*)_review\.md   -> # Plan v\1 Review
code_v(0|[1-9][0-9]*)\.md          -> # Code v\1
review_v(0|[1-9][0-9]*)\.md        -> # Review v\1
```

Only the coordinator writes `.done` files.

Done file content:

```text
---
stage: <stage>
artifact: artifacts/<artifact>.md
status: complete
---
Completed by CCC coordinator after artifact validation.
```

## Resume

`/ccc resume <output_folder>` reads `run.md`, `.done` files, artifact verdicts, and configured rounds, then continues from the next missing stage.

Resume must not infer workflow state only from `run.md`; `.done` files and artifact verdicts are the source of truth.

If an artifact exists without the matching `.done`, stop and ask the user to repair: rerun the stage, move the artifact aside, or manually validate it and write `.done` only if it satisfies this protocol. If `.done` exists without its artifact, the run is invalid and must be repaired before resume.

## Cancel

```text
/ccc cancel <output_folder> "<reason>"
```

The coordinator writes or updates `run.md` with `Status: canceled`, records the reason, and stops. Cancel does not delete artifacts.

## Validator

Use:

```text
scripts/ccc-validate.sh <output_folder>
```

## Final Output

Always end with:

```text
CCC run: <output_folder>
Stage completed: <stage|none>
Next action: <stage|complete|blocked|canceled>
```

## Stage Skills

Use:

```text
ccc
ccc-plan
ccc-plan-review
ccc-code
ccc-code-review
```
