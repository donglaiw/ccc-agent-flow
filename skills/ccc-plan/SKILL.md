---
name: ccc-plan
description: CCC planning stage. Write or revise plan_vN.md from the task and prior plan review. Use only inside CCC.
---
# Skill: CCC Plan

Use this skill only inside a CCC run.

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

## Required Structure

```text
# Plan vN
## Summary
## Scope
## Proposed Changes
## Files and Areas
## Verification Plan
## Risks and Questions
## Changes Since Previous Plan Version
```

For `plan_v0`, write `Initial plan.` under `Changes Since Previous Plan Version`.

For `plan_v1+`, summarize what changed in response to the previous plan review.

## Rules

* Do not edit code during planning.
* Keep the plan scoped to the task.
* Address prior review findings directly.
* Do not silently ignore plan review findings.
* Include concrete verification steps.
* Do not write review artifacts.
* Do not write `.done`.
