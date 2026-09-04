---
name: ccc-code
description: CCC code stage. The configured coder implements or revises code_vN.md from the approved plan and prior review. Use only inside CCC.
---
# Skill: CCC Code

Use this skill only inside a CCC run. Read `<CCC_HOME>/protocol/CCC_PROTOCOL.md` first and follow its artifact contract for `code_vN.md`.

## CCC Home

This skill ships the protocol next to itself. Resolve `<CCC_HOME>` before reading anything else: `$CCC_HOME` when set, otherwise this skill's own directory, otherwise a `ccc-duet` checkout root — whichever first contains `protocol/CCC_PROTOCOL.md`. If none resolves, stop as blocked and report the broken install; never reconstruct the protocol or a prompt template from memory. `<CCC_HOME>` is not the target repository — companion CLI calls still run from the target repository root.

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
* The configured coder owns this stage.
* Include the protocol-defined git baseline in `code_vN.md`.
* Do not create git commits during a CCC run.
* Keep changes scoped.
* Do not silently ignore review findings.
* Do not claim tests passed unless commands actually ran.
* Summarize the actual diff, not intent.
* Do not write review artifacts.
