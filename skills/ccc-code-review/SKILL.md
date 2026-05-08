---
name: ccc-code-review
description: CCC code review stage. Invoke the Codex plugin from Claude Code to review code_vN.md and actual repository changes against the CCC git baseline. Use only inside CCC.
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
<RUN>/state/review_vN.codex.raw.md
<RUN>/artifacts/review_vN.md
```

Do not write `.done`.

## Rules

* Print the exact `/codex:review --wait --base <run_start_ref>` command for the user to run in Claude Code, unless the environment explicitly exposes the plugin as a callable tool.
* Use `/codex:adversarial-review --wait --base <run_start_ref>` only when focused challenge review is needed.
* Inspect the actual git diff using the `run_start_ref` from `run.md`.
* Do not trust `code_vN.md` alone.
* For `review_v1+`, focus on whether prior findings were fixed and whether new issues were introduced.
* Save the raw plugin output to `state/review_vN.codex.raw.md` before writing the review artifact.
* Preserve Codex findings faithfully when writing the artifact.
* The coordinator may write the final CCC `VERDICT:` line after interpreting Codex output, but must not soften or discard material findings.
* If Codex output lacks a clear verdict, ask for clarification or stop as blocked.
