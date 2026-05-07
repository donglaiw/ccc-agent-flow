# CCC Protocol

CCC is an interactive two-role coordinator workflow. The output folder is always explicit.

Do not use `.ccc/current_run`.

## Syntax

```text
/ccc a1 <output_folder> "<task>" [plan_rounds,revision_rounds]
/ccc a2 <output_folder> [plan_rounds,revision_rounds]
```

For Codex:

```text
Use the ccc skill as a1 with output folder <output_folder>, task "<task>", and rounds 2,2.
Use the ccc skill as a2 with output folder <output_folder> and rounds 2,2.
```

Examples:

```text
/ccc a1 .ccc/runs/auth-fix "Given the context above, implement the auth fix" 2,2
/ccc a2 .ccc/runs/auth-fix 2,2
```

If rounds are omitted, use `2,2`.

## Arguments

`a1 | a2`

Role for the current interactive session.

`<output_folder>`

The exact CCC run folder. The coordinator creates this folder if needed.

`"<task>"`

Task text. Required for `a1` when starting a new run. For `a2`, read the task from `<output_folder>/task.md`.

`[plan_rounds,revision_rounds]`

Optional rounds in `N,M` format.

`plan_rounds` is the number of allowed plan revisions after `plan_v0`.

`revision_rounds` is the number of allowed code revisions after `code_v0`.

## Run Folder

Inside `<output_folder>`, CCC writes:

```text
task.md
run.md
artifacts/
state/
```

The run folder must not contain CCC-managed `logs/` or `context/` directories.

## Role Ownership

```text
plan_vN          a1
plan_vN_review   a2
code_vN          a1
review_vN        a2
```

`a1` owns implementation and summary in each `code_vN`.

For `code_v0`, `a1` implements, verifies, and summarizes the work as `code_v0.md`.

For `code_v1+`, `a1` reads `review_v{N-1}.md`, fixes accepted findings, verifies, and summarizes the updated work as `code_vN.md`.

## Round Semantics

Example `2,2`:

```text
plan_v0 -> plan_v0_review -> plan_v1 -> plan_v1_review -> plan_v2
code_v0 -> review_v0 -> code_v1 -> review_v1 -> code_v2
```

This means initial plan plus 2 plan revisions, and initial code plus 2 code revisions.

The final artifact after the last allowed revision is not reviewed unless the user increases the round limit.

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

If `plan_vN_review.md` says `VERDICT: APPROVE`, planning is complete and `a1` may write `artifacts/code_v0.md`.

If `plan_vN_review.md` says `VERDICT: NEEDS_REVISION`, `a1` writes `artifacts/plan_v{N+1}.md`, unless `N` already equals `plan_rounds`.

If `plan_vN_review.md` says `VERDICT: BLOCKER`, stop.

If max plan revisions are reached and the latest plan review still says `NEEDS_REVISION`, `a1` should write the final allowed plan version and stop until the user increases the limit. Example for `2,2`:

```text
plan_v0 -> plan_v0_review NEEDS_REVISION
plan_v1 -> plan_v1_review NEEDS_REVISION
plan_v2
```

At this point, no `plan_v2_review` is allowed under `2,2`. Report:

```text
Max plan revision rounds reached; latest artifact is plan_v2.md.
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

If `review_vN.md` says `VERDICT: NEEDS_CHANGES` or `VERDICT: BLOCKER`, `a1` writes `artifacts/code_v{N+1}.md`, unless `N` already equals `revision_rounds`.

If max code revisions are reached and the latest review still requires changes, stop and report:

```text
Max code revision rounds reached; latest artifact is code_vN.md.
```

Example for `2,2`:

```text
code_v0 -> review_v0 NEEDS_CHANGES
code_v1 -> review_v1 NEEDS_CHANGES
code_v2
```

At this point, no `review_v2` is allowed under `2,2` unless the user increases the limit.

## Artifact Validation

Before writing `.done`, the coordinator must validate:

```text
artifact exists
artifact is non-empty
expected top-level heading exists
review artifacts contain exactly one valid VERDICT line
```

Expected headings:

```text
plan_vN.md         # Plan vN
plan_vN_review.md  # Plan vN Review
code_vN.md         # Code vN
review_vN.md       # Review vN
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

Users may use `.ccc/hooks/ccc-wait-done.sh` or their own hooks to wait for the file externally.

## Stage Skills

Use these stage skills:

```text
ccc
ccc-plan
ccc-plan-review
ccc-code
ccc-code-review
```
