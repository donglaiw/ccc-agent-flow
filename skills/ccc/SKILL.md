---
name: ccc
description: Coordinate the CCC single-session Claude Code workflow using the Codex plugin for synchronous reviews, explicit output folders, protocol-defined artifacts, and .done sentinels.
---
# Skill: CCC Coordinator

Use this skill to coordinate a CCC run from one Claude Code session with the Codex plugin installed.

Before doing anything else, read `protocol/CCC_PROTOCOL.md`. It is the canonical source for syntax, roles, rounds, artifact contracts, validation, resume behavior, cancel behavior, and final output.

## Coordinator Checklist

1. Parse the requested CCC action: `run`, `resume`, or `cancel`.
2. Resolve the explicit output folder.
3. Create the run folder, `artifacts/`, and `state/` if needed.
4. For a new `run`, confirm the installed Codex plugin supports the required `--wait` and `--base` flags, or initialize the run as blocked.
5. For a new `run`, write `task.md` and initialize `run.md`, including the git baseline required by the protocol.
6. Determine the next stage from `.done` files and artifact verdicts.
7. For driver stages, perform the matching stage skill directly.
8. For reviewer stages, print the exact `/codex:... --wait` slash command for the user to run in the same Claude Code session, then continue from the plugin output.
9. Validate the artifact, write the `.done` file, update `run.md`, and continue until complete, blocked, canceled, or max rounds are reached.

## Codex Plugin Handoff

Do not assume this skill can programmatically type Claude Code slash commands. Reviewer stages are a foreground handoff unless the environment explicitly exposes plugin tools:

```text
1. Print the exact /codex:... --wait command.
2. Wait for the user to run it and continue/resume CCC with the output.
3. Save the raw output to state/<review-stage>.codex.raw.md.
4. Write the CCC review artifact as an attested summary of that raw output.
```

Assume the plugin returns output inline in the Claude Code conversation; copy that inline output into the raw transcript file before normalizing it.

For plan reviews, use `state/plan_vN_review.codex.raw.md`.

For code reviews, use `state/review_vN.codex.raw.md`.

If the plugin output is ambiguous, unsupported by the raw transcript, or does not clearly support a verdict, stop with `Status: blocked`.

## Stage Skills

```text
ccc-plan
ccc-plan-review
ccc-code
ccc-code-review
```

Only this coordinator skill writes `.done` files.
