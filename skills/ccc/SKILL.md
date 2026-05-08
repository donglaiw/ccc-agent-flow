---
name: ccc
description: Coordinate the CCC single-session Claude Code workflow using the Codex CLI for synchronous reviews, explicit output folders, protocol-defined artifacts, and .done sentinels.
---
# Skill: CCC Coordinator

Use this skill to coordinate a CCC run from one Claude Code session with the Codex CLI installed and authenticated.

Before doing anything else, read `protocol/CCC_PROTOCOL.md`. It is the canonical source for syntax, roles, rounds, artifact contracts, validation, resume behavior, cancel behavior, and final output.

## Coordinator Checklist

1. Parse the requested CCC action: `run`, `resume`, or `cancel`.
2. Resolve the explicit output folder.
3. Create the run folder, `artifacts/`, and `state/` if needed.
4. For a new `run`, confirm `codex login status`, `codex exec --help`, and `codex exec review --help` work, or initialize the run as blocked.
5. For a new `run`, write `task.md` and initialize `run.md`, including the git baseline required by the protocol.
6. Determine the next stage from `.done` files and artifact verdicts.
7. For driver stages, perform the matching stage skill directly.
8. For reviewer stages, run the matching non-interactive Codex CLI command and capture its final message in `state/<review-stage>.codex.raw.md`.
9. Validate the artifact, write the `.done` file, update `run.md`, and continue until complete, blocked, canceled, or max rounds are reached.

## Codex CLI Review

Reviewer stages are automatic shell commands:

```text
1. Build the review prompt from the protocol template.
2. Run codex exec or codex exec review from the repository root with --output-last-message state/<review-stage>.codex.raw.md.
3. Write the CCC review artifact as an attested summary of that raw output.
```

For plan reviews, use `state/plan_vN_review.codex.raw.md`.

For code reviews, use `state/review_vN.codex.raw.md`.

If a code-review command mutates repository state, the Codex CLI exits non-zero, produces no raw transcript, or the output does not clearly support a verdict, stop with `Status: blocked`.

## Stage Skills

```text
ccc-plan
ccc-plan-review
ccc-code
ccc-code-review
```

Only this coordinator skill writes `.done` files.
