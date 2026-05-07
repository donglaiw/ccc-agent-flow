---
name: ccc-code
description: CCC code stage. Implement or revise code_vN.md from the approved plan and prior review. Use only inside CCC.
---
# Skill: CCC Code

Use this skill only inside a CCC run.

## Inputs

For `code_v0`:

```text
<RUN>/task.md
<RUN>/artifacts/plan_vN.md
<RUN>/artifacts/plan_vN_review.md
```

For `code_v1+`:

```text
<RUN>/task.md
<RUN>/artifacts/code_v{N-1}.md
<RUN>/artifacts/review_v{N-1}.md
```

## Output

```text
<RUN>/artifacts/code_vN.md
```

Do not write `.done`.

## Required Structure

```text
# Code vN
## Overview
Briefly describe the implemented or revised change.
## What Changed
List behavior, API, UI, system, or test changes.
## Implementation Details
Explain important technical changes.
## Files Changed
| File | Purpose |
|---|---|
## Verification
List exact commands run and results.
## Review Focus
Tell `a2` what to scrutinize.
## Risks and Unknowns
List assumptions, skipped checks, or known risks.
## Changes Since Previous Code Version
For `code_v0`, write: Initial implementation.
For `code_v1+`, summarize what changed in response to the previous review.
```

## Rules

* `code_v0` means implement, verify, and summarize.
* `code_v1+` means revise according to the previous review, verify, and summarize.
* Keep changes scoped.
* Triage review findings before fixing.
* Do not silently ignore review findings.
* Do not claim tests passed unless commands actually ran.
* Summarize the actual diff, not intent.
* Do not write review artifacts.
* Do not write `.done`.
