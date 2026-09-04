---
name: ccc-plan
description: CCC planning stage. The configured planner writes or revises plan_vN.md from the task and prior plan review. Use only inside CCC.
---
# Skill: CCC Plan

Use this skill only inside a CCC run. Read `<CCC_HOME>/protocol/CCC_PROTOCOL.md` first and follow its artifact contract for `plan_vN.md`.

## CCC Home

This skill ships the protocol next to itself. Resolve `<CCC_HOME>` before reading anything else: `$CCC_HOME` when set, otherwise this skill's own directory, otherwise a `ccc-duet` checkout root — whichever first contains `protocol/CCC_PROTOCOL.md`. If none resolves, stop as blocked and report the broken install; never reconstruct the protocol or a prompt template from memory. `<CCC_HOME>` is not the target repository — companion CLI calls still run from the target repository root.

## Inputs

For `plan_v0`:

```text
<RUN>/task.md
```

For `plan_v1+`:

```text
<RUN>/task.md
<RUN>/artifacts/plan_v{N-1}.md
<RUN>/artifacts/plan_v{N-1}_review.md
```

## Output

```text
<RUN>/artifacts/plan_vN.md
```

Do not write `.done`.

## Rules

* Do not edit code during planning.
* The configured planner owns this stage.
* Keep the plan scoped to the task.
* For `plan_v1+`, directly address the prior plan review findings in `Changes Since Previous Plan Version`.
* Do not silently ignore review findings.
* Include concrete verification steps.
* Do not write review artifacts.
