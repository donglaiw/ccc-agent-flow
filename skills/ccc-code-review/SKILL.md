---
name: ccc-code-review
description: CCC code review stage. The configured planner reviews code_vN.md and actual repository changes against the CCC git baseline. Use only inside CCC.
---
# Skill: CCC Code Review

Use this skill only inside a CCC run. Read `<CCC_HOME>/protocol/CCC_PROTOCOL.md` first and follow its artifact contract for `review_vN.md`.

## CCC Home

This skill ships the protocol next to itself. Resolve `<CCC_HOME>` before reading anything else: `$CCC_HOME` when set, otherwise this skill's own directory, otherwise a `ccc-duet` checkout root — whichever first contains `protocol/CCC_PROTOCOL.md`. If none resolves, stop as blocked and report the broken install; never reconstruct the protocol or a prompt template from memory. `<CCC_HOME>` is not the target repository — companion CLI calls still run from the target repository root.

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

* The configured planner owns this stage.
* If the planner is the current session's agent, perform the review directly.
* If the planner is `codex` and `HEAD` equals `run_start_ref`, run `codex exec --sandbox read-only --output-last-message <RUN>/state/review_vN.review.raw.md -` from the repository root.
* If `HEAD` differs from `run_start_ref`, stop as blocked because commits are not allowed during a CCC run.
* If the planner is `codex` and the baseline is empty-tree, use the same `codex exec --sandbox read-only` reviewer command and include the protocol's fallback prompt and diff commands.
* If the planner is `claude`, run `claude --print --output-format text --no-session-persistence --tools ""` from the repository root and capture stdout to `state/review_vN.review.raw.md`.
* In all configurations, include the complete required artifacts and relevant git outputs in the prompt. Compute the UTF-8 byte length of the exact reviewer stdin payload. If it would exceed `CCC_REVIEW_PROMPT_MAX_BYTES` (default `200000`), stop as blocked instead of silently truncating.
* Use the code-review prompt template from `<CCC_HOME>/protocol/CCC_PROTOCOL.md`.
* Tell the reviewer to evaluate only the artifacts and diffs included in the prompt, without inspecting other repository files.
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
