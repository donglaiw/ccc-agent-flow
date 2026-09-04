---
name: ccc-plan-review
description: CCC plan review stage. The configured coder reviews plan_vN.md and produces plan_vN_review.md. Use only inside CCC.
---
# Skill: CCC Plan Review

Use this skill only inside a CCC run. Read `<CCC_HOME>/protocol/CCC_PROTOCOL.md` first and follow its artifact contract for `plan_vN_review.md`.

## CCC Home

This skill ships the protocol next to itself. Resolve `<CCC_HOME>` before reading anything else: `$CCC_HOME` when set, otherwise this skill's own directory, otherwise a `ccc-duet` checkout root — whichever first contains `protocol/CCC_PROTOCOL.md`. If none resolves, stop as blocked and report the broken install; never reconstruct the protocol or a prompt template from memory. `<CCC_HOME>` is not the target repository — companion CLI calls still run from the target repository root.

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
<RUN>/state/plan_vN_review.review.raw.md
<RUN>/artifacts/plan_vN_review.md
```

Do not write `.done`.

## Rules

* The configured coder owns this stage.
* If the coder is the current session's agent, perform the review directly.
* If the coder is `codex`, run `codex exec --sandbox read-only --output-last-message <RUN>/state/plan_vN_review.review.raw.md -` from the repository root.
* If the coder is `claude`, run `claude --print --output-format text --no-session-persistence --tools ""` from the repository root and capture stdout to `state/plan_vN_review.review.raw.md`.
* In all configurations, include the complete required artifacts in the prompt. Compute the UTF-8 byte length of the exact reviewer stdin payload. If it would exceed `CCC_REVIEW_PROMPT_MAX_BYTES` (default `200000`), stop as blocked instead of silently truncating.
* Use the plan-review prompt template from `<CCC_HOME>/protocol/CCC_PROTOCOL.md`.
* Tell the reviewer to evaluate only the artifacts and text included in the prompt, without inspecting other repository files.
* Ask the reviewer for findings tagged `[minor]` or `[major]`, questions, and whether the plan appears ready for implementation.
* Do not let the reviewer edit code during plan review.
* Save the raw reviewer output to `state/plan_vN_review.review.raw.md` before writing the review artifact.
* Preserve reviewer findings faithfully when writing the artifact.
* The coordinator may write the final CCC `VERDICT:` line after interpreting reviewer output, but must not soften or discard material findings.
* If the coordinator uses `VERDICT: APPROVE_AUTO_OVERRIDE`, include exactly one `AUTO OVERRIDE:` line in `## Summary`.
* Treat ambiguous finding severity as major.
* If reviewer output does not clearly support a verdict, append a clarification call to the same raw transcript or stop as blocked.
* Do not write code artifacts.
