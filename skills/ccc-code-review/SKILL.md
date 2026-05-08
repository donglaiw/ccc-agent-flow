---
name: ccc-code-review
description: CCC code review stage. Run Codex CLI to review code_vN.md and actual repository changes against the CCC git baseline. Use only inside CCC.
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

* Run `codex exec review --base <run_start_ref> --uncommitted --output-last-message <RUN>/state/review_vN.codex.raw.md -` from the repository root.
* For empty-tree baselines, use `codex exec --sandbox read-only --output-last-message <RUN>/state/review_vN.codex.raw.md -` and include the protocol's empty-tree diff commands in the prompt.
* Use the code-review prompt template from `protocol/CCC_PROTOCOL.md`.
* Do not pass `--dangerously-bypass-approvals-and-sandbox`.
* Capture `git diff` and `git diff --cached` before and after `codex exec review`; stop as blocked if they differ.
* Inspect the actual git diff using the `run_start_ref` from `run.md`.
* Do not trust `code_vN.md` alone.
* For `review_v1+`, focus on whether prior findings were fixed and whether new issues were introduced.
* Save the raw Codex output to `state/review_vN.codex.raw.md` before writing the review artifact.
* Preserve Codex findings faithfully when writing the artifact.
* The coordinator may write the final CCC `VERDICT:` line after interpreting Codex output, but must not soften or discard material findings.
* If Codex output does not clearly support a verdict, append a clarification call to the same raw transcript or stop as blocked.
