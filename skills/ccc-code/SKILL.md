---
name: ccc-code
description: CCC code stage. Implement or revise code_vN.md from the approved plan and prior review. Use only inside CCC.
---
# Skill: CCC Code

Use this skill only inside a CCC run. Read `protocol/CCC_PROTOCOL.md` first and follow its artifact contract for `code_vN.md`.

## Inputs

For `code_v0`:

```text
<RUN>/task.md
<RUN>/run.md
<RUN>/artifacts/plan_vN.md
<RUN>/artifacts/plan_vN_review.md
```

For `code_v1+`:

```text
<RUN>/task.md
<RUN>/run.md
<RUN>/artifacts/code_v{N-1}.md
<RUN>/artifacts/review_v{N-1}.md
```

## Output

```text
<RUN>/artifacts/code_vN.md
```

Do not write `.done`.

## Rules

* `code_v0` means implement, verify, and summarize.
* `code_v1+` means triage the previous review, fix accepted findings, verify, and summarize.
* Include the protocol-defined git baseline in `code_vN.md`.
* Keep changes scoped.
* Do not silently ignore review findings.
* Do not claim tests passed unless commands actually ran.
* Summarize the actual diff, not intent.
* Do not write review artifacts.
