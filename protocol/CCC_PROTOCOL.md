# CCC Protocol

This file is the canonical CCC workflow specification. README files and skills should point here instead of repeating these rules.

CCC is a single-session Claude Code coordinator workflow. Claude Code owns the run, writes plan/code artifacts, and invokes the Codex plugin for Claude Code synchronously for review stages.

The two-session lock-and-wait protocol is preserved on the `two-session` branch.

Do not use `.ccc/current_run`; the output folder is always explicit.

## Requirements

Use this protocol from Claude Code with the Codex plugin installed:

```text
/plugin marketplace add openai/codex-plugin-cc
/plugin install codex@openai-codex
/reload-plugins
/codex:setup
```

The plugin provides `/codex:review`, `/codex:adversarial-review`, `/codex:rescue`, `/codex:status`, `/codex:result`, and `/codex:cancel`. CCC uses foreground review calls with `--wait`; it must not use background jobs as a polling loop.

## Syntax

```text
/ccc run <output_folder> "<task>" [plan_rounds,revision_rounds]
/ccc resume <output_folder>
/ccc cancel <output_folder> "<reason>"
```

If rounds are omitted, use `2,2`.

## Roles

```text
driver    Claude Code; writes task, run, plan, code, state, and done files
reviewer  Codex plugin for Claude Code; provides review findings and verdicts
```

Stage ownership:

```text
plan_vN          driver
plan_vN_review   reviewer, invoked by driver
code_vN          driver
review_vN        reviewer, invoked by driver
```

The coordinator runs these stages sequentially in one Claude Code session. It may stop for user direction on `BLOCKER`, invalid plugin output, failed validation, or max-round exhaustion.

## Rounds

CCC uses zero-based versions. The two numeric arguments are maximum version indexes, equivalent to the number of allowed revisions after the initial `v0`.

Example `2,2` allows these artifacts:

```text
plan_v0 -> plan_v0_review -> plan_v1 -> plan_v1_review -> plan_v2
code_v0 -> review_v0 -> code_v1 -> review_v1 -> code_v2
```

This is three possible plan artifacts and three possible code artifacts. The final artifact at the maximum version is a max-rounds stop point, not an approval.

## Output Folder

The coordinator creates the run folder if needed:

```text
<output_folder>/
  task.md
  run.md
  artifacts/
  state/
```

The run folder has no CCC-managed `logs/`, `context/`, or `locks/` directories in the default Claude Code workflow.

## Run Metadata

When starting a new run, the coordinator writes `<output_folder>/task.md`, captures the run baseline files, and initializes `<output_folder>/run.md`.

`run.md` must include:

```text
# CCC Run

## Metadata
## Description
## Roles
## Rounds
## Task Summary
## Git Baseline
## Workflow State
## Status
```

`## Metadata` uses machine-readable fields:

```text
protocol_version: 2
mode: claude-code-codex-plugin
```

`## Description` is free-form text for humans.

`## Roles` is an enumeration:

```text
driver: claude-code
reviewer: codex-plugin-cc
```

`## Rounds` uses machine-readable fields:

```text
plan_rounds: <N>
revision_rounds: <M>
```

`## Git Baseline` records the review base before code changes:

```text
run_start_ref: <git sha or 4b825dc642cb6eb9a060e54bf8d69288fbee4904>
run_start_ref_kind: head | empty_tree
run_start_status_file: state/run_start.status
run_start_unstaged_diff: state/run_start.diff
run_start_staged_diff: state/run_start_cached.diff
```

The coordinator writes those `state/run_start.*` files at run start. `state/run_start.status` is canonical for run-start status; do not duplicate that status inline in `run.md`.

`state/run_start.status` is the exact stdout of `git status --short` at run start. An empty file means the run started clean.

`state/run_start.diff` is the exact stdout of `git diff` at run start.

`state/run_start_cached.diff` is the exact stdout of `git diff --cached` at run start.

For normal repositories, `run_start_ref` is the output of `git rev-parse --verify HEAD` and `run_start_ref_kind` is `head`.

For fresh repositories with no commits, `run_start_ref` is the Git empty-tree SHA `4b825dc642cb6eb9a060e54bf8d69288fbee4904` and `run_start_ref_kind` is `empty_tree`.

If `run_start_ref` is neither a valid git ref nor the empty-tree SHA, code review must use `VERDICT: BLOCKER` unless the user provides another explicit diff base.

`## Workflow State` is machine-readable. Do not rely on prose parsing:

```text
current_stage: <stage|none>
expected_actor: <driver|reviewer|none>
latest_artifact: <artifact path|none>
latest_verdict: <APPROVE|APPROVE_WITH_MINOR_COMMENTS|NEEDS_CHANGES|BLOCKER|none>
next_action: <stage|complete|blocked|max-rounds-reached|canceled>
```

Field values are constrained:

```text
current_stage: none | plan_vN | plan_vN_review | code_vN | review_vN
expected_actor: driver | reviewer | none
latest_artifact: none | artifacts/plan_vN.md | artifacts/plan_vN_review.md | artifacts/code_vN.md | artifacts/review_vN.md
latest_verdict: APPROVE | APPROVE_WITH_MINOR_COMMENTS | NEEDS_CHANGES | BLOCKER | none
next_action: plan_vN | plan_vN_review | code_vN | review_vN | complete | blocked | max-rounds-reached | canceled
```

`expected_actor: none` is only valid when status is `complete`, `canceled`, `blocked`, or `max-rounds-reached`.

`## Status` must contain exactly one of:

```text
active
complete
blocked
max-rounds-reached
canceled
```

Status semantics:

```text
active    the single-session coordinator is still running or resumable
complete  the workflow has an approving code review verdict
blocked   the workflow has a BLOCKER verdict, invalid plugin output, failed validation, or needs user direction
max-rounds-reached  the workflow exhausted the configured max version without approval
canceled  the user canceled the run
```

Existing runs with a different `protocol_version` must stop before writing and report the mismatch. Two-session protocol v1 runs should be resumed from the `two-session` branch.

All `run.md` writes use a temporary file in the same directory, then an atomic rename.

## Codex Plugin Review Calls

Plan review uses the steerable read-only review command:

```text
/codex:adversarial-review --wait Review <output_folder>/artifacts/plan_vN.md against <output_folder>/task.md. Do not edit code. Return the CCC plan-review artifact structure and exactly one valid VERDICT line.
```

For `plan_v1+`, include the previous plan and review in the focus text.

Code review uses the normal Codex review command against the captured baseline:

```text
/codex:review --wait --base <run_start_ref>
```

If extra scrutiny is needed, use:

```text
/codex:adversarial-review --wait --base <run_start_ref> Focus on the CCC review artifact requirements, prior review findings, and regressions introduced since the baseline.
```

The coordinator must copy or summarize Codex plugin output into the required review artifact, preserving findings and producing exactly one valid CCC verdict line. If plugin output is ambiguous or lacks a valid verdict, the coordinator asks the plugin for clarification or stops with `Status: blocked`.

## Git Review Baseline

`ccc-code-review` must inspect the actual repository, not only `code_vN.md`.

When `run_start_ref_kind` is `head`, use `run_start_ref` as the baseline:

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

This keeps committed mid-cycle changes reviewable. `git diff --cached` and `git diff` catch staged and unstaged changes that are not in `HEAD`.

If the run started dirty, compare current status and diffs against `state/run_start.status`, `state/run_start.diff`, and `state/run_start_cached.diff` before assigning findings to the CCC run.

Each `code_vN.md` must include the run baseline and current `HEAD` under `## Git Baseline`.

Each `review_vN.md` must include the `run_start_ref` from `run.md` under `## Diff Baseline`. Validation must confirm the Diff Baseline SHA equals `run_start_ref`.

## Verdicts

All review artifacts use the same verdict vocabulary:

```text
VERDICT: APPROVE
VERDICT: APPROVE_WITH_MINOR_COMMENTS
VERDICT: NEEDS_CHANGES
VERDICT: BLOCKER
```

Validation must match exactly one whole line with this regex:

```text
^VERDICT: (APPROVE|APPROVE_WITH_MINOR_COMMENTS|NEEDS_CHANGES|BLOCKER)$
```

Do not use substring matching.

`APPROVE` and `APPROVE_WITH_MINOR_COMMENTS` allow the workflow to advance.

`NEEDS_CHANGES` asks the driver for the next plan or code version, if another version is allowed.

`BLOCKER` stops the workflow for user direction.

## Planning Transitions

If no plan exists:

```text
driver writes artifacts/plan_v0.md
coordinator writes state/plan_v0.done
```

If `plan_vN.done` exists and `plan_vN_review.done` does not exist:

```text
driver invokes Codex plugin for plan review
driver writes artifacts/plan_vN_review.md from plugin output
coordinator writes state/plan_vN_review.done
```

If `plan_vN_review.md` says `VERDICT: APPROVE` or `VERDICT: APPROVE_WITH_MINOR_COMMENTS`, planning is approved and the driver may write `artifacts/code_v0.md`.

If `plan_vN_review.md` says `VERDICT: NEEDS_CHANGES`, the driver writes `artifacts/plan_v{N+1}.md`, unless `N` already equals `plan_rounds`.

If `plan_vN_review.md` says `VERDICT: BLOCKER`, stop.

If the final allowed plan version has been written and still is not approved, do not mark the workflow complete. Stop and report:

```text
Max plan version reached; latest artifact is plan_vN.md and is not approved.
```

## Code and Review Transitions

After planning is approved:

```text
driver writes artifacts/code_v0.md
coordinator writes state/code_v0.done
```

If `code_vN.done` exists and `review_vN.done` does not exist:

```text
driver invokes Codex plugin for code review
driver writes artifacts/review_vN.md from plugin output
coordinator writes state/review_vN.done
```

If `review_vN.md` says `VERDICT: APPROVE` or `VERDICT: APPROVE_WITH_MINOR_COMMENTS`, the workflow is complete.

If `review_vN.md` says `VERDICT: NEEDS_CHANGES`, the driver writes `artifacts/code_v{N+1}.md`, unless `N` already equals `revision_rounds`.

If `review_vN.md` says `VERDICT: BLOCKER`, stop unless the user explicitly directs the driver to continue with a clear fix.

If the final allowed code version has been written and still is not approved, do not mark the workflow complete. Stop and report:

```text
Max code version reached; latest artifact is code_vN.md and is not approved.
```

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

`plan_v1+` must summarize what changed in response to `plan_v{N-1}_review.md`.

`plan_vN_review.md` required sections:

```text
# Plan vN Review
## Summary
## Findings
## Questions
## Verdict
One protocol-approved verdict line.
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

`code_v1+` must summarize what changed in response to `review_v{N-1}.md`.

`review_vN.md` required sections:

```text
# Review vN
## Summary
## Diff Baseline
## Findings
## Tests to Add
## Questions
## Verdict
One protocol-approved verdict line.
```

`## Diff Baseline` must include:

```text
run_start_ref: <sha>
```

## Validation Before .done

Before writing `.done`, the coordinator validates:

```text
artifact exists
artifact is non-empty
expected top-level heading exists exactly once
required sections exist exactly as listed in Artifact Contracts
review artifacts contain exactly one valid whole-line VERDICT
plan_v0 and code_v0 have required non-empty Changes Since text
plan_v1+ and code_v1+ have non-empty Changes Since sections
code_vN Git Baseline contains run_start_ref and current_head
review_vN Diff Baseline SHA equals run_start_ref from run.md
```

Filename-to-heading validation is exact:

```text
plan_v(0|[1-9][0-9]*)\.md          -> # Plan v\1
plan_v(0|[1-9][0-9]*)_review\.md   -> # Plan v\1 Review
code_v(0|[1-9][0-9]*)\.md          -> # Code v\1
review_v(0|[1-9][0-9]*)\.md        -> # Review v\1
```

Versions are decimal integers with no leading zeros except `v0`.

Only the coordinator writes `.done` files. Individual stage skills must not write `.done`.

Done file content:

```text
---
stage: <stage>
actor: <driver|reviewer>
artifact: artifacts/<artifact>.md
status: complete
---
Completed by CCC coordinator after artifact validation.
```

## Resume

`/ccc resume <output_folder>` reads `run.md`, `.done` files, artifact verdicts, and the configured rounds, then continues from the next missing stage.

Resume must not infer workflow state only from `run.md`; `.done` files and artifact verdicts are the source of truth.

## Cancel

To abandon a run, use:

```text
/ccc cancel <output_folder> "<reason>"
```

The coordinator writes or updates `run.md` with `Status: canceled`, records the reason, and stops. Cancel does not delete artifacts.

## Validator

Use `scripts/ccc-validate.sh <output_folder>` to mechanically validate `run.md`, artifact headings, required sections, verdict lines, baseline keys, and `.done` references for a CCC run.

## Final Output

Always end with:

```text
CCC run: <output_folder>
Mode: claude-code-codex-plugin
Stage completed: <stage|none>
Next action: <stage|complete|blocked|max-rounds-reached|canceled>
```

## Stage Skills

Use these skills:

```text
ccc
ccc-plan
ccc-plan-review
ccc-code
ccc-code-review
```
