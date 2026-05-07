---
name: ccc
description: Coordinate the CCC two-agent workflow interactively using a1/a2 roles, output folders, zero-based Markdown artifacts, and .done sentinels.
---
# Skill: CCC Coordinator

Use this skill to coordinate the CCC workflow from an interactive Claude Code or Codex session.

## Syntax

```text
/ccc a1 <output_folder> "<task>" [plan_rounds,revision_rounds]
/ccc a2 <output_folder> [plan_rounds,revision_rounds]
```

Examples:

```text
/ccc a1 .ccc/runs/auth-fix "Given the context above, implement the auth fix" 2,2
/ccc a2 .ccc/runs/auth-fix 2,2
```

For Codex, interpret the same arguments using the Codex-native skill invocation format:

```text
Use the ccc skill as a1 with output folder <output_folder>, task "<task>", and rounds 2,2.
Use the ccc skill as a2 with output folder <output_folder> and rounds 2,2.
```

## Defaults

If `[plan_rounds,revision_rounds]` is omitted, use:

```text
2,2
```

This means:

```text
maximum 2 plan revisions after plan_v0
maximum 2 code revisions after code_v0
```

## Argument Rules

* First argument must be `a1` or `a2`.
* Second argument is the output folder for this CCC run.
* Third argument is the task text.
* Task text is required for `a1` when starting a new run.
* For an existing run, `a1` may read `<output_folder>/task.md`.
* Task text is optional for `a2`; `a2` should read `<output_folder>/task.md`.
* Rounds are optional and must use the format `N,M`.

## Output Folder

The output folder is the run folder.

Create it if needed.

Inside it, create:

```text
artifacts/
state/
```

For a new `a1` run, write:

```text
task.md
run.md
```

Do not create CCC-managed `logs/` or `context/` directories in the run folder.

## Role Ownership

```text
plan_vN          a1
plan_vN_review   a2
code_vN          a1
review_vN        a2
```

## Coordinator Responsibilities

The coordinator must:

1. Read `.ccc/CCC_PROTOCOL.md` if present, otherwise `protocol/CCC_PROTOCOL.md`.
2. Parse positional arguments.
3. Validate role is `a1` or `a2`.
4. Resolve `<output_folder>`.
5. Create the run folder, `artifacts/`, and `state/` if needed.
6. If role is `a1` and task text is provided, write `<output_folder>/task.md`.
7. Write or update `<output_folder>/run.md` with role, rounds, task summary, and current workflow state.
8. Determine the next stage by reading `<output_folder>/state/*.done`.
9. If the next stage belongs to this role, perform it using the matching CCC stage skill.
10. Validate the produced artifact.
11. Write the corresponding `.done` file.
12. If the next stage belongs to the other role, do not perform it.
13. Report the exact `.done` file this session is waiting for.
14. Never busy-poll inside the model.

## Stage Skills

Use these stage skills:

```text
ccc-plan
ccc-plan-review
ccc-code
ccc-review
```

`ccc-code` handles both initial implementation and review-driven revisions.

## Planning Rules

* If `plan_v0.done` does not exist, `a1` writes `artifacts/plan_v0.md`.
* If `plan_vN.done` exists, `plan_vN_review.done` does not exist, and `N < plan_rounds`, `a2` writes `artifacts/plan_vN_review.md`.
* If `plan_vN_review.md` says `VERDICT: NEEDS_REVISION`, `a1` writes `artifacts/plan_v{N+1}.md`, unless `N` already equals `plan_rounds`.
* If `plan_vN_review.md` says `VERDICT: APPROVE`, planning is complete.
* If `plan_vN_review.md` says `VERDICT: BLOCKER`, stop.
* If max plan revisions are reached and the latest plan review still says `NEEDS_REVISION`, write the final allowed plan version and stop.

Example for `2,2`:

```text
plan_v0 -> plan_v0_review -> plan_v1 -> plan_v1_review -> plan_v2
```

At this point, no `plan_v2_review` is allowed under `2,2` unless the user increases the limit. Report:

```text
Max plan revision rounds reached; latest artifact is plan_v2.md.
```

## Code Rules

* After an approved plan exists, `a1` writes `artifacts/code_v0.md`.
* `code_v0.md` combines implementation notes, verification, and a review-ready summary.
* For `code_v1+`, `a1` reads `review_v{N-1}.md`, fixes accepted findings, verifies, and writes `artifacts/code_vN.md`.
* `a1` may edit code during `code_vN`.

Code artifact structure:

```text
# Code vN
## Overview
## What Changed
## Implementation Details
## Files Changed
| File | Purpose |
|---|---|
## Verification
## Review Focus
## Risks and Unknowns
## Changes Since Previous Code Version
```

## Review Rules

* After `code_vN.done`, if `review_vN.done` does not exist and `N < revision_rounds`, `a2` writes `artifacts/review_vN.md`.
* If `review_vN.md` says `VERDICT: APPROVE` or `VERDICT: APPROVE_WITH_MINOR_COMMENTS`, workflow is complete.
* If `review_vN.md` says `VERDICT: NEEDS_CHANGES` or `VERDICT: BLOCKER`, `a1` writes `artifacts/code_v{N+1}.md`, unless `N` already equals `revision_rounds`.
* If max code revisions are reached and the latest review still requires changes, stop.

Example for `2,2`:

```text
code_v0 -> review_v0 -> code_v1 -> review_v1 -> code_v2
```

At this point, no `review_v2` is allowed under `2,2` unless the user increases the limit. Report:

```text
Max code revision rounds reached; latest artifact is code_v2.md.
```

## Validation Before .done

Before writing `.done`, validate:

* artifact exists
* artifact is non-empty
* expected top-level heading exists
* review artifacts contain exactly one valid `VERDICT:` line

Expected headings:

```text
# Plan vN
# Plan vN Review
# Code vN
# Review vN
```

Valid plan review verdicts:

```text
VERDICT: APPROVE
VERDICT: NEEDS_REVISION
VERDICT: BLOCKER
```

Valid code review verdicts:

```text
VERDICT: APPROVE
VERDICT: APPROVE_WITH_MINOR_COMMENTS
VERDICT: NEEDS_CHANGES
VERDICT: BLOCKER
```

## Done Files

Only this coordinator skill writes `.done` files.

Individual stage skills must not write `.done`.

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

Do not wait by polling inside the model.

When the next stage belongs to the other role, end with:

```text
CCC run: <output_folder>
Current role: <a1|a2>
Stage completed: none
Waiting for: <output_folder>/state/<stage>.done
Next role: <a1|a2>
```

Users may use `.ccc/hooks/ccc-wait-done.sh` or their own hooks to wait for the file externally.

## Final Output

Always end with:

```text
CCC run: <output_folder>
Current role: <a1|a2>
Stage completed: <stage|none>
Next waiting point: <done-file|complete|blocked>
```
