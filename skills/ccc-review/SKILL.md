---
name: ccc-review
description: CCC review stage. Review code_vN.md and actual repository changes. Reviewer-only; do not edit code.
---
# Skill: CCC Review

Use this skill only inside a CCC run.

## Inputs

```text
<RUN>/task.md
<RUN>/artifacts/code_vN.md
```

Also inspect live repository state directly:

```text
git status --short
git diff --stat
git diff
```

For `review_v1+`, also read the previous review when available:

```text
<RUN>/artifacts/review_v{N-1}.md
<RUN>/artifacts/code_v{N-1}.md
```

## Output

```text
<RUN>/artifacts/review_vN.md
```

Do not write `.done`.

## Required Structure

```text
# Review vN
## Summary
## Findings
### Finding N
**Severity:** Critical / High / Medium / Low
**Location:**
**Issue:**
**Why it matters:**
**Suggested fix:**
## Tests to Add
## Questions
## Verdict
VERDICT: APPROVE / APPROVE_WITH_MINOR_COMMENTS / NEEDS_CHANGES / BLOCKER
```

## Rules

* Do not edit code.
* Inspect the actual git diff directly.
* Do not trust `code_vN.md` alone.
* For `review_v1+`, focus on whether prior findings were fixed and whether new issues were introduced.
* Write exactly one valid `VERDICT:` line.
* Do not write `.done`.
