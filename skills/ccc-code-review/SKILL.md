---
name: ccc-code-review
description: CCC code review stage. Run the workflow-specific reviewer CLI to review code_vN.md and actual repository changes against the CCC git baseline. Use only inside CCC.
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
<RUN>/state/review_vN.review.raw.md
<RUN>/artifacts/review_vN.md
```

Do not write `.done`.

## Rules

* In `claude-first`, if `HEAD` equals `run_start_ref`, run `codex exec --sandbox read-only --output-last-message <RUN>/state/review_vN.review.raw.md -` from the repository root.
* If `HEAD` differs from `run_start_ref`, stop as blocked because driver commits are not allowed during a CCC run.
* In `claude-first`, if the baseline is empty-tree, use the same `codex exec --sandbox read-only` reviewer command and include the protocol's fallback prompt and diff commands.
* In `codex-first`, run `claude --print --output-format text --no-session-persistence --tools ""` from the repository root and capture stdout to `state/review_vN.review.raw.md`.
* In both workflows, include the complete required artifacts and relevant git outputs in the prompt. If the prompt would exceed `CCC_REVIEW_PROMPT_MAX_BYTES` (default `200000`), stop as blocked instead of silently truncating.
* Use the code-review prompt template from `protocol/CCC_PROTOCOL.md`.
* For Codex reviewer commands, do not pass `--dangerously-bypass-approvals-and-sandbox`.
* Capture `git diff` and `git diff --cached` before and after reviewer commands; stop as blocked if they differ.
* Inspect the actual git diff using the `run_start_ref` from `run.md`.
* Do not trust `code_vN.md` alone.
* For `review_v1+`, focus on whether prior findings were fixed and whether new issues were introduced.
* Save the raw reviewer output to `state/review_vN.review.raw.md` before writing the review artifact.
* Preserve reviewer findings faithfully when writing the artifact.
* The coordinator may write the final CCC `VERDICT:` line after interpreting reviewer output, but must not soften or discard material findings.
* If the coordinator uses `VERDICT: APPROVE_AUTO_OVERRIDE`, include exactly one `AUTO OVERRIDE:` line in `## Summary`.
* Treat ambiguous finding severity as major.
* If reviewer output does not clearly support a verdict, append a clarification call to the same raw transcript or stop as blocked.
