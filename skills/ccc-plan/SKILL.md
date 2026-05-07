---
name: ccc-plan
description: CCC planning stage. Write or revise plan_vN.md from the task and prior plan review. Use only inside CCC.
---
# Skill: CCC Plan

Use this skill only inside a CCC run. Read `protocol/CCC_PROTOCOL.md` first and follow its artifact contract for `plan_vN.md`.

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
* Keep the plan scoped to the task.
* For `plan_v1+`, directly address the prior plan review findings in `Changes Since Previous Plan Version`.
* Do not silently ignore review findings.
* Include concrete verification steps.
* Do not write review artifacts.
