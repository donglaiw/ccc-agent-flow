---
name: ccc-plan-review
description: CCC plan review stage. Invoke the Codex plugin from Claude Code to review plan_vN.md and produce plan_vN_review.md. Use only inside CCC.
---
# Skill: CCC Plan Review

Use this skill only inside a CCC run. Read `protocol/CCC_PROTOCOL.md` first and follow its artifact contract for `plan_vN_review.md`.

## Inputs

```text
<RUN>/task.md
<RUN>/artifacts/plan_vN.md
```

For `plan_v1+`, also include previous plan review context when available:

```text
<RUN>/artifacts/plan_v{N-1}.md
<RUN>/artifacts/plan_v{N-1}_review.md
```

## Output

```text
<RUN>/artifacts/plan_vN_review.md
```

Do not write `.done`.

## Rules

* Invoke Codex from Claude Code with `/codex:adversarial-review --wait`.
* Ask Codex to review the plan against the task and return the CCC plan-review structure with exactly one valid verdict line.
* Do not let Codex edit code during plan review.
* Preserve Codex findings faithfully when writing the artifact.
* If Codex output lacks a valid verdict, ask for clarification or stop as blocked.
* Do not write code artifacts.
