---
name: ccc-plan-review
description: CCC plan review stage. Review plan_vN.md and decide whether planning is approved, needs revision, or is blocked. Use only inside CCC.
---
# Skill: CCC Plan Review

Use this skill only inside a CCC run.

## Inputs

```text
<RUN>/task.md
<RUN>/artifacts/plan_vN.md
```

For `plan_v1+`, also read previous plan review context when available:

```text
<RUN>/artifacts/plan_v{N-1}.md
<RUN>/artifacts/plan_v{N-1}_review.md
```

## Output

```text
<RUN>/artifacts/plan_vN_review.md
```

Do not write `.done`.

## Required Structure

```text
# Plan vN Review
## Summary
## Findings
### Finding N
**Severity:** Critical / High / Medium / Low
**Issue:**
**Why it matters:**
**Suggested revision:**
## Questions
## Verdict
VERDICT: APPROVE / NEEDS_REVISION / BLOCKER
```

## Rules

* Do not edit code.
* Judge whether the plan is clear, scoped, verifiable, and responsive to the task.
* For `plan_v1+`, focus on whether prior plan review findings were addressed.
* Use `VERDICT: APPROVE` only when the plan is ready for implementation.
* Use `VERDICT: NEEDS_REVISION` when `a1` should revise the plan within the current round limit.
* Use `VERDICT: BLOCKER` when the task cannot proceed without user direction or missing external information.
* Write exactly one valid `VERDICT:` line.
* Do not write `.done`.
