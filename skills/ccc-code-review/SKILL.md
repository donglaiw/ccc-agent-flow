---
name: ccc-code-review
description: CCC code review stage. Review code_vN.md and actual repository changes against the CCC git baseline. Reviewer-only; do not edit code.
---
# Skill: CCC Code Review

Use this skill only inside a CCC run. Read `protocol/CCC_PROTOCOL.md` first and follow its artifact contract for `review_vN.md`.

## Inputs

```text
<RUN>/task.md
<RUN>/run.md
<RUN>/artifacts/code_vN.md
```

For `review_v1+`, also read:

```text
<RUN>/artifacts/review_v{N-1}.md
<RUN>/artifacts/code_v{N-1}.md
```

## Output

```text
<RUN>/artifacts/review_vN.md
```

Do not write `.done`.

## Rules

* Do not edit code.
* Inspect the actual git diff using the `run_start_ref` from `run.md`.
* Do not trust `code_vN.md` alone.
* For `review_v1+`, focus on whether prior findings were fixed and whether new issues were introduced.
* Use only protocol-approved verdict lines.
