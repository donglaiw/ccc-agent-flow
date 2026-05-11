---
name: ccc
description: Coordinate the CCC single-session workflow using a companion reviewer CLI, explicit output folders, protocol-defined artifacts, and .done sentinels.
---
# Skill: CCC Coordinator

Use this skill to coordinate a CCC run from one driver session. Claude-first uses Codex CLI as reviewer; Codex-first uses Claude Code CLI as reviewer.

Before doing anything else, read `protocol/CCC_PROTOCOL.md`. It is the canonical source for syntax, roles, rounds, artifact contracts, validation, resume behavior, cancel behavior, and final output.

## Coordinator Checklist

1. Parse the requested CCC action: `run`, `resume`, or `cancel`, optional mode `manual`, `normal`, or `auto`, and optional workflow `claude-first` or `codex-first`; mode is not persisted and `resume` defaults to `normal`.
2. Resolve the explicit output folder.
3. Create the run folder, `artifacts/`, and `state/` if needed.
4. Detect or validate the workflow before writing artifacts. Use explicit workflow arguments first, then `CCC_WORKFLOW`, then `scripts/ccc-detect-session.sh` (`claude` maps to `claude-first`; `codex` maps to `codex-first`). If detection is unclear, stop and ask the user to rerun with `claude-first` or `codex-first`.
5. For a new `run`, confirm the workflow-specific reviewer CLI exits successfully, or initialize the run as blocked.
6. For a new `run`, write `task.md` and initialize `run.md`, including `## Runtime` and the git baseline required by the protocol.
7. Determine the next stage from `.done` files and artifact verdicts.
8. For driver stages, perform the matching stage skill directly.
9. For reviewer stages, run the matching non-interactive reviewer command and capture its final message in `state/<review-stage>.review.raw.md`.
10. Validate the artifact, write the `.done` file, update `run.md`, and continue according to mode:
   * `manual` stops for user approval after one completed stage.
   * `normal` runs until complete or a human decision is needed.
   * `auto` runs through reviewer disagreement until complete unless a hard failure blocks the run.

## Reviewer CLI

Reviewer stages are automatic shell commands:

```text
1. Build the review prompt from the protocol template.
2. Run the workflow-specific reviewer command from the repository root.
3. Write the CCC review artifact as an attested summary of that raw output.
```

For plan reviews, use `state/plan_vN_review.review.raw.md`.

For code reviews, use `state/review_vN.review.raw.md`.

If a code-review command mutates repository state, the reviewer CLI exits non-zero, produces no raw transcript, or the output does not clearly support a verdict, stop with `Status: blocked`.

In `auto` mode, unresolved reviewer disagreement may be overridden only as described in the protocol. Preserve all review findings, use `VERDICT: APPROVE_AUTO_OVERRIDE`, and write exactly one `AUTO OVERRIDE:` line in `## Summary`; do not override hard failures.

Driver stages must not create git commits during a CCC run.

## Stage Skills

```text
ccc-plan
ccc-plan-review
ccc-code
ccc-code-review
```

Only this coordinator skill writes `.done` files.
