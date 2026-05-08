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
<RUN>/state/plan_vN_review.codex.raw.md
<RUN>/artifacts/plan_vN_review.md
```

Do not write `.done`.

## Rules

* Print the exact `/codex:adversarial-review --wait ...` command for the user to run in Claude Code, unless the environment explicitly exposes the plugin as a callable tool.
* Ask Codex for findings, questions, and whether the plan appears ready for implementation.
* Do not let Codex edit code during plan review.
* Save the raw plugin output to `state/plan_vN_review.codex.raw.md` before writing the review artifact.
* Preserve Codex findings faithfully when writing the artifact.
* The coordinator may write the final CCC `VERDICT:` line after interpreting Codex output, but must not soften or discard material findings.
* If Codex output does not clearly support a verdict, ask for clarification or stop as blocked.
* Do not write code artifacts.
