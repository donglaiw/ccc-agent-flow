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

The run folder has no CCC-managed `logs/` or `context/` directories.

## Run Metadata

When starting a new run, `a1` writes `<output_folder>/task.md` and `<output_folder>/run.md`.

`run.md` must include:

```text
# CCC Run
## Role
## Rounds
## Task Summary
## Git Baseline
## Current Workflow State
## Status
```

`Git Baseline` records the review base before code changes:

```text
run_start_ref: <git sha from `git rev-parse --verify HEAD`, or none>
run_start_status: <summary of `git status --short`>
run_start_status_file: state/run_start.status
run_start_unstaged_diff: state/run_start.diff
run_start_staged_diff: state/run_start_cached.diff
```

The coordinator writes those `state/run_start.*` files at run start. If the repository is dirty at run start, reviewers must use those baseline files to distinguish pre-existing changes from CCC changes.

## Git Review Baseline

`ccc-code-review` must inspect the actual repository, not only `code_vN.md`.

If `run_start_ref` is a valid git ref, use it as the baseline:

```text
git status --short
git diff --stat <run_start_ref>...HEAD
git diff <run_start_ref>...HEAD
git diff --cached
git diff
```

This keeps committed mid-cycle changes reviewable. `git diff --cached` and `git diff` catch staged and unstaged changes that are not in `HEAD`.

If the run started dirty, compare current status and diffs against `state/run_start.status`, `state/run_start.diff`, and `state/run_start_cached.diff` before assigning findings to the CCC run.

If `run_start_ref` is `none` or invalid, the review verdict must be `VERDICT: BLOCKER` unless the user provides another explicit diff base.

Each `code_vN.md` must include the run baseline and current `HEAD` under `## Git Baseline`.

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

`plan_vN.md`:

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

`plan_vN_review.md`:

```text
# Plan vN Review
## Summary
## Findings
## Questions
## Verdict
One protocol-approved verdict line.
```

`code_vN.md`:

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

For `code_v0`, `Changes Since Previous Code Version` says `Initial implementation.`

For `code_v1+`, it summarizes what changed in response to `review_v{N-1}.md`.

`review_vN.md`:

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

## Validation Before .done

Before writing `.done`, the coordinator validates:

```text
artifact exists
artifact is non-empty
artifact filename version matches the top-level heading version
expected top-level heading exists exactly once
required sections exist
review artifacts contain exactly one valid whole-line VERDICT
plan_v1+ and code_v1+ have a non-empty Changes Since section
```

## Locking and Atomic Writes

Before performing a stage, the coordinator creates a stage lock with an atomic `mkdir`:

```text
<output_folder>/state/locks/<stage>.lock/
```

If the lock already exists and there is no corresponding `.done` file, stop and report the lock path.

Write artifacts and done files through a temporary file in the same directory, validate the temporary artifact, then rename it into place.

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

The coordinator writes or updates `run.md` with `Status: canceled`, records the reason, and stops. It does not delete artifacts.

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
