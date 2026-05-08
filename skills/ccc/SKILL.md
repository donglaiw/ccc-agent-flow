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
4. For a new `run`, write `task.md` and initialize `run.md`, including the git baseline required by the protocol.
5. Determine the next stage from `.done` files and artifact verdicts.
6. For driver stages, perform the matching stage skill directly.
7. For reviewer stages, invoke the Codex plugin from Claude Code with `--wait`, then write the review artifact from the plugin output.
8. Validate the artifact, write the `.done` file, update `run.md`, and continue until complete, blocked, canceled, or max rounds are reached.

## Stage Skills

```text
ccc-plan
ccc-plan-review
ccc-code
ccc-code-review
```

Only this coordinator skill writes `.done` files.
