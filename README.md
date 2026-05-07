# ccc-agent-flow

Minimal CCC skill design for coordinating coding collaboration between Claude Code and Codex.

## Usage

Open two interactive sessions in the same repository and alternate turns between them.

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

`a1` owns planning and code changes. `a2` reviews both plans and code. The roles are intentionally positional so two interactive sessions can coordinate through artifacts and `.done` files.

The canonical workflow, artifact names, verdicts, validation rules, locking rules, and round semantics live in [protocol/CCC_PROTOCOL.md](protocol/CCC_PROTOCOL.md).

## Waiting

The optional wait helper only waits for a `.done` file. It does not coordinate the workflow.

```text
scripts/ccc-wait-done.sh --timeout 600 .ccc/runs/auth-fix/state/plan_v0_review.done
```

Exit codes:

```text
0    file appeared
2    usage error
124  timeout
```

## Example

See [examples/runs/hello-world](examples/runs/hello-world) for a complete small run with plan, review, code, follow-up review, state sentinels, and `run.md`.

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
