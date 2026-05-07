---
name: ccc
description: Coordinate the CCC two-agent workflow interactively using a1/a2 roles, explicit output folders, protocol-defined artifacts, and .done sentinels.
---
# Skill: CCC Coordinator

Use this skill to coordinate a CCC run from an interactive Claude Code or Codex session.

Before doing anything else, read `protocol/CCC_PROTOCOL.md`. It is the canonical source for syntax, roles, rounds, artifact contracts, validation, locking, waiting, cancel behavior, and final output.

## Coordinator Checklist

1. Parse the requested CCC action: `a1`, `a2`, or `cancel`.
2. Resolve the explicit output folder.
3. Create the run folder, `artifacts/`, `state/`, and `state/locks/` if needed.
4. For a new `a1` run, write `task.md` and initialize `run.md`, including the git baseline required by the protocol.
5. Determine the next stage from `.done` files and artifact verdicts.
6. If the next stage belongs to this session, acquire the stage lock, perform the matching stage skill, validate the artifact, then write the `.done` file.
7. If the next stage belongs to the other role, do not perform it; report the exact `.done` file this session is waiting for.
8. Never poll inside the model. Use `scripts/ccc-wait-done.sh` externally when waiting is needed.

## Stage Skills

```text
ccc-plan
ccc-plan-review
ccc-code
ccc-code-review
```

Only this coordinator skill writes `.done` files.
