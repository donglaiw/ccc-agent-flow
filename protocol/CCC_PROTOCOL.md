# CCC Protocol

This file is the canonical CCC workflow specification. README files and skills should point here instead of repeating these rules.

CCC is an interactive two-role coordinator workflow. The output folder is always explicit.

Do not use `.ccc/current_run`.

## Syntax

```text
/ccc a1 <output_folder> "<task>" [plan_rounds,revision_rounds]
/ccc a2 <output_folder> [plan_rounds,revision_rounds]
/ccc cancel <output_folder> "<reason>"
```

For Codex:

```text
Use the ccc skill as a1 with output folder <output_folder>, task "<task>", and rounds 2,2.
Use the ccc skill as a2 with output folder <output_folder> and rounds 2,2.
Use the ccc skill to cancel output folder <output_folder> with reason "<reason>".
```

If rounds are omitted, use `2,2`.

## Roles

```text
a1  writes plans and code artifacts; may edit repository code during code stages
a2  reviews plans and code artifacts; must not edit repository code
```

Role ownership:

```text
plan_vN          a1
plan_vN_review   a2
code_vN          a1
review_vN        a2
```

Before acquiring any stage lock, the coordinator must derive the expected next stage and expected role from `.done` files and artifact verdicts. If the invoked role is not the expected role, it must stop before writing anything and report the expected role and waiting `.done` file.

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
    locks/
```

The run folder has no CCC-managed `logs/` or `context/` directories.

## Run Metadata

When starting a new run, `a1` writes `<output_folder>/task.md`, captures the run baseline files, and initializes `<output_folder>/run.md`.

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
protocol_version: 1
```

`## Description` is free-form text for humans.

`## Roles` is an enumeration, not a single current role:

```text
a1: <tool/session/person>
a2: <tool/session/person>
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
expected_role: <a1|a2|none>
latest_artifact: <artifact path|none>
latest_verdict: <APPROVE|APPROVE_WITH_MINOR_COMMENTS|NEEDS_CHANGES|BLOCKER|none>
next_waiting_for: <state file|complete|blocked|max-rounds-reached|canceled>
```

Field values are constrained:

```text
current_stage: none | plan_vN | plan_vN_review | code_vN | review_vN
expected_role: a1 | a2 | none
latest_artifact: none | artifacts/plan_vN.md | artifacts/plan_vN_review.md | artifacts/code_vN.md | artifacts/review_vN.md
latest_verdict: APPROVE | APPROVE_WITH_MINOR_COMMENTS | NEEDS_CHANGES | BLOCKER | none
next_waiting_for: state/<stage>.done | complete | blocked | max-rounds-reached | canceled
```

`expected_role: none` is only valid when status is `complete`, `canceled`, `blocked`, or `max-rounds-reached`.

`## Status` must contain exactly one of:

```text
active
waiting
complete
blocked
max-rounds-reached
canceled
```

Status semantics:

```text
active    a stage is currently in progress and the stage lock is held
waiting   no stage is in progress and the next stage belongs to the other role
complete  the workflow has an approving code review verdict
blocked   the workflow has a BLOCKER verdict or cannot continue without user direction
max-rounds-reached  the workflow exhausted the configured max version without approval
canceled  the user canceled the run
```

Existing runs with a different `protocol_version` must stop before writing and report the mismatch.

All `run.md` writes use the atomic metadata-write procedure in `Locking and Atomic Writes`.

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

`NEEDS_CHANGES` asks `a1` for the next plan or code version, if another version is allowed.

`BLOCKER` stops the workflow for user direction.

## Planning Transitions

If no plan exists:

```text
a1 writes artifacts/plan_v0.md
ccc writes state/plan_v0.done
```

If `plan_vN.done` exists, `plan_vN_review.done` does not exist, and `N < plan_rounds`:

```text
a2 writes artifacts/plan_vN_review.md
ccc writes state/plan_vN_review.done
```

If `plan_vN_review.md` says `VERDICT: APPROVE` or `VERDICT: APPROVE_WITH_MINOR_COMMENTS`, planning is approved and `a1` may write `artifacts/code_v0.md`.

If `plan_vN_review.md` says `VERDICT: NEEDS_CHANGES`, `a1` writes `artifacts/plan_v{N+1}.md`, unless `N` already equals `plan_rounds`.

If `plan_vN_review.md` says `VERDICT: BLOCKER`, stop.

If the final allowed plan version has been written and has no allowed review stage, do not mark the workflow complete. Stop and report:

```text
Max plan version reached; latest artifact is plan_vN.md and is not approved.
```

## Code and Review Transitions

After planning is approved:

```text
a1 writes artifacts/code_v0.md
ccc writes state/code_v0.done
```

If `code_vN.done` exists, `review_vN.done` does not exist, and `N < revision_rounds`:

```text
a2 writes artifacts/review_vN.md
ccc writes state/review_vN.done
```

If `review_vN.md` says `VERDICT: APPROVE` or `VERDICT: APPROVE_WITH_MINOR_COMMENTS`, the workflow is complete.

If `review_vN.md` says `VERDICT: NEEDS_CHANGES`, `a1` writes `artifacts/code_v{N+1}.md`, unless `N` already equals `revision_rounds`.

If `review_vN.md` says `VERDICT: BLOCKER`, stop unless the user explicitly directs `a1` to continue with a clear fix.

If the final allowed code version has been written and has no allowed review stage, do not mark the workflow complete. Stop and report:

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

## Locking and Atomic Writes

Before performing a stage, the coordinator derives the expected next stage and expected role. It must reject stale-role invocations before attempting any lock.

If both a stage lock and `run.lock` are needed, acquire the stage lock first, then `run.lock`. Release in reverse order: `run.lock`, then the stage lock. Do not acquire these locks in the opposite order.

Stage lock acquisition is the atomic test-and-set operation:

```text
mkdir <output_folder>/state/locks/<stage>.lock
```

If `mkdir` succeeds, this session owns the stage lock. If `mkdir` fails and there is no corresponding `.done` file, stop and report the lock path.

Write artifacts, done files, and `run.md` through temporary files in the same directory, then rename them into place.

Stage completion order is fixed:

```text
write artifact tmp
validate artifact tmp
rename artifact tmp to artifact
write done tmp
rename done tmp to done
acquire run.lock
write run.md tmp with updated Workflow State and Status
rename run.md tmp to run.md
release run.lock
release stage lock
```

The coordinator derives the next stage from `.done` files and artifact verdicts. `run.md` is a machine-readable summary, not the source of truth for stage transitions.

After the corresponding `.done` file is successfully written and synced, remove the stage lock directory:

```text
rmdir <output_folder>/state/locks/<stage>.lock
```

If a session crashes and leaves a stage lock, recovery is manual: verify no peer session is still working on that stage, verify there is no corresponding `.done` file, then remove the stale lock with `rmdir <output_folder>/state/locks/<stage>.lock`.

`run.md` writes use a separate metadata lock:

```text
mkdir <output_folder>/state/locks/run.lock
write <output_folder>/run.md.tmp
rename run.md.tmp to run.md
rmdir <output_folder>/state/locks/run.lock
```

If `run.lock` already exists, stop and report it.

If a session crashes and leaves `run.lock`, recovery is manual: verify no peer session is still updating `run.md`, inspect any `run.md.tmp`, keep or remove that temp file intentionally, then remove the stale lock with `rmdir <output_folder>/state/locks/run.lock`.

Only the `ccc` coordinator skill writes `.done` files. Individual stage skills must not write `.done`.

Done file content:

```text
---
stage: <stage>
role: <a1|a2>
artifact: artifacts/<artifact>.md
status: complete
---
Completed by CCC coordinator after artifact validation.
```

## Waiting

Never busy-poll inside the model.

When the next stage belongs to the other role, end with:

```text
CCC run: <output_folder>
Current role: <a1|a2>
Stage completed: none
Waiting for: <output_folder>/state/<stage>.done
Next role: <a1|a2>
```

Users may use `scripts/ccc-wait-done.sh` or their own external wait mechanism.

## Cancel

To abandon a run, use:

```text
/ccc cancel <output_folder> "<reason>"
```

Cancel must not hold `run.lock` while waiting for user confirmation. The coordinator first inspects `state/locks/*.lock`; for each stage lock, it prompts the user to confirm no peer session is active before removing that lock. User confirmation is the verification mechanism for clearing stage locks during cancel. After stage-lock cleanup, the coordinator acquires `state/locks/run.lock`, writes or updates `run.md` with `Status: canceled`, records the reason, removes `state/locks/run.lock`, and stops. Cancel does not delete artifacts.

The coordinator may also write `state/canceled.done` for external waiters in a future protocol version. This version does not require a cancel sentinel.

## Validator

Use `scripts/ccc-validate.sh <output_folder>` to mechanically validate `run.md`, artifact headings, required sections, verdict lines, baseline keys, and `.done` references for a CCC run.

## Final Output

Always end with:

```text
CCC run: <output_folder>
Current role: <a1|a2|cancel>
Stage completed: <stage|none>
Next waiting point: <done-file|complete|blocked|max-rounds-reached|canceled>
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
