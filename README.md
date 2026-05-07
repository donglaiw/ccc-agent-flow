# ccc-agent-flow

Minimal CCC skill design for coordinating coding collaboration between Claude Code and Codex.

## Usage

Open two interactive sessions in the same repository.

Session 1, acting as `a1`:

```text
/ccc a1 .ccc/runs/auth-fix "Given the context above, implement the auth fix" 2,2
```

Session 2, acting as `a2`:

```text
/ccc a2 .ccc/runs/auth-fix 2,2
```

For Codex, use the equivalent skill phrasing:

```text
Use the ccc skill as a1 with output folder .ccc/runs/auth-fix, task "Given the context above, implement the auth fix", and rounds 2,2.
Use the ccc skill as a2 with output folder .ccc/runs/auth-fix and rounds 2,2.
```

The last argument is optional. Omitting it uses the default:

```text
2,2
```

Each session should rerun `/ccc ...` after the other role completes its `.done` file.

For waiting, use the optional helper:

```text
.ccc/hooks/ccc-wait-done.sh .ccc/runs/auth-fix/state/plan_v0_review.done
```

The helper only waits for a file. It does not coordinate the workflow.

## Rounds

CCC uses zero-based versions.

The final `2,2` means:

```text
2 plan revision rounds after plan_v0
2 code revision rounds after code_v0
```

Planning:

```text
plan_v0 -> plan_v0_review -> plan_v1 -> plan_v1_review -> plan_v2
```

Code/review:

```text
code_v0 -> review_v0 -> code_v1 -> review_v1 -> code_v2
```

`code_v0` is the initial implementation plus a reviewer-ready summary.

`code_v1+` are revisions based on the previous review plus updated summaries.

The final plan or code version after the last allowed revision is not reviewed unless the user increases the round limit.

## Artifacts

The output folder is always explicit. Do not use `.ccc/current_run`.

Example run folder:

```text
.ccc/runs/auth-fix/
  task.md
  run.md
  artifacts/
    plan_v0.md
    plan_v0_review.md
    plan_v1.md
    plan_v1_review.md
    plan_v2.md
    code_v0.md
    review_v0.md
    code_v1.md
    review_v1.md
    code_v2.md
  state/
    plan_v0.done
    plan_v0_review.done
    plan_v1.done
    plan_v1_review.done
    plan_v2.done
    code_v0.done
    review_v0.done
    code_v1.done
    review_v1.done
    code_v2.done
```

The run folder has no `logs/` and no `context/`.

## Skills

Use these stage skills:

```text
ccc
ccc-plan
ccc-plan-review
ccc-code
ccc-code-review
```

`ccc-code` handles both initial implementation and later review-driven revisions.
