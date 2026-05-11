# CCC Protocol

This file is the canonical CCC workflow specification. README files and skills should point here instead of repeating these rules.

CCC is a single-session coordinator workflow. The active session owns the run, writes plan/code artifacts, and invokes the other agent synchronously for review stages.

Do not use `.ccc/current_run`; the output folder is always explicit.

## Requirements

CCC supports two workflows:

```text
claude-first  Claude Code is the driver; Codex CLI is the reviewer.
codex-first   Codex is the driver; Claude Code CLI is the reviewer.
```

For `claude-first`, install and authenticate the Codex CLI:

```text
codex login
codex login status
codex --version
codex exec --help
codex exec review --help
```

For `codex-first`, install and authenticate the Claude Code CLI:

```text
claude --version
claude --help
claude --print --output-format text --no-session-persistence --tools "" "Return READY"
```

CCC uses non-interactive reviewer calls. It must not ask the user to run `/codex:` or `/claude:` slash commands.

The `claude-first` workflow targets `codex-cli 0.128.0` or newer and requires `codex login status`, `codex exec`, `codex exec review`, `--uncommitted`, and `--output-last-message`. If the installed CLI version differs, verify those commands before starting a CCC run.

The `codex-first` workflow requires `claude --print`, `--output-format text`, `--no-session-persistence`, and `--tools ""`. If compatibility or authentication cannot be confirmed, initialize the run as `Status: blocked` and stop before writing stage artifacts.

## Syntax

```text
/ccc run <output_folder> "<task>" [plan_rounds,revision_rounds] [manual|normal|auto] [claude-first|codex-first|auto-detect]
/ccc resume <output_folder> [manual|normal|auto] [claude-first|codex-first|auto-detect]
/ccc cancel <output_folder> "<reason>"
```

If rounds are omitted, use `2,2`. If mode is omitted, use `normal`. If workflow is omitted, use `auto-detect`. Optional arguments may appear in any order: parse `manual`, `normal`, or `auto` as mode; `claude-first`, `codex-first`, or `auto-detect` as workflow; and `N,M` as rounds. Reject the command if two optional arguments of the same type are provided.

On parse errors or failed workflow detection, print the error and stop without creating or modifying the run folder.

Mode is not persisted in `run.md`; `/ccc resume <output_folder>` defaults to `normal` unless `manual` or `auto` is passed again.

Workflow is persisted in `run.md`. `/ccc resume <output_folder>` uses the persisted workflow unless `claude-first` or `codex-first` is passed explicitly. If the current session is detected and does not match the persisted workflow driver, stop before writing artifacts.

Workflow detection:

```text
1. If the command includes claude-first or codex-first, use it.
2. Else, if CCC_WORKFLOW is claude-first or codex-first, use it.
3. Else, run scripts/ccc-detect-session.sh.
4. If detection prints claude, use claude-first.
5. If detection prints codex, use codex-first.
6. If still unknown, stop and ask the user to rerun with claude-first or codex-first.
```

Detection uses agent-provided environment markers first:

```text
CLAUDECODE=1 or CLAUDE_CODE_SESSION_ID present -> claude
CODEX_CI=1 -> codex
otherwise -> unknown
```

Shell environment markers are best-effort and are not guaranteed in every app. Explicit workflow arguments are authoritative. Do not rely on parent-process names except as a future fallback; wrappers, sandboxes, tmux, and login shells make process-name detection unstable.

Mode behavior:

```text
manual  complete one stage, write its artifact and .done file, update run.md, then stop for user approval before the next stage
normal  run stages until complete, blocked, or canceled; unresolved major reviewer disagreement waits for a human decision
auto    run stages until complete, blocked by hard failure, or canceled; unresolved reviewer disagreement does not require human approval
```

Mode decisions:

| Situation | manual | normal | auto |
|---|---|---|---|
| Any stage completes | Stop for user approval before the next stage. | Continue. | Continue. |
| Review approves | Continue, subject to the manual approval stop above. | Continue. | Continue. |
| Review requests changes and another version is allowed | Stop for user approval before the next stage. | Write the next version. | Write the next version. |
| Review reports `BLOCKER` and another version is allowed | Block unless the user explicitly directs a clear fix. | Block unless the user explicitly directs a clear fix. | Treat as reviewer disagreement and write the next version, unless it is a hard failure. |
| No version remains and unresolved findings are minor-only | Complete or advance with `VERDICT: APPROVE_WITH_MINOR_COMMENTS`. | Complete or advance with `VERDICT: APPROVE_WITH_MINOR_COMMENTS`. | Complete or advance with `VERDICT: APPROVE_AUTO_OVERRIDE`. |
| No version remains and unresolved findings are major or `BLOCKER` | Block for human decision. | Block for human decision. | Complete or advance with `VERDICT: APPROVE_AUTO_OVERRIDE`, unless it is a hard failure. |
| Hard failure | Block. | Block. | Block. |

Hard failures are infrastructure or protocol failures: invalid CLI or auth state, failed commands, missing raw transcripts, validation failure, repository mutation, `HEAD` divergence, invalid baseline, parse errors, and user cancellation. In `auto` mode, content-level findings cannot block the run by themselves, including security findings, data-corruption risks, public contract breaks, or user-visible behavior concerns. They must be preserved in the review artifact and marked as an auto override.

## Roles

```text
driver    current interactive session; writes task, run, plan, code, state, verdicts, and done files
reviewer  non-interactive companion agent; provides review findings and review signal
```

Workflow actors:

```text
claude-first  driver: claude-code; reviewer: codex-cli
codex-first   driver: codex; reviewer: claude-code-cli
```

Driver stages must not create git commits during a CCC run. Keep changes in the working tree and commit only after the workflow reaches a terminal state. This keeps `codex exec review --uncommitted` aligned with the run baseline.

Stage ownership:

```text
plan_vN          driver
plan_vN_review   reviewer, invoked by driver
code_vN          driver
review_vN        reviewer, invoked by driver
```

The coordinator runs these stages sequentially in one driver session using the mode decision table above.

CCC has no multi-session safety layer. Exactly one coordinator session may be active for a given `<output_folder>` at a time. Starting a second coordinator on the same run can race artifact, `.done`, and `run.md` writes.

## Rounds

CCC uses zero-based versions. The two numeric arguments are maximum version indexes, equivalent to the number of allowed revisions after the initial `v0`.

Example `2,2` allows these artifacts:

```text
plan_v0 -> plan_v0_review -> plan_v1 -> plan_v1_review -> plan_v2
code_v0 -> review_v0 -> code_v1 -> review_v1 -> code_v2
```

This is three possible plan artifacts and three possible code artifacts. The final artifact at the maximum version is a decision point, not automatically an approval in `manual` or `normal` mode. `auto` mode may override unresolved reviewer disagreement at this point.

## Output Folder

The coordinator creates the run folder if needed:

```text
<output_folder>/
  task.md
  run.md
  artifacts/
  state/
```

## Run File

When starting a new run, the coordinator writes `<output_folder>/task.md`, captures the run baseline files, and initializes `<output_folder>/run.md`.

`run.md` must include:

```text
# CCC Run

## Description
## Runtime
## Rounds
## Task Summary
## Git Baseline
## Workflow State
## Status
```

`## Description` is free-form text for humans.

`## Runtime` records the selected workflow:

```text
workflow: <claude-first|codex-first>
driver: <claude-code|codex>
reviewer: <codex-cli|claude-code-cli>
session_detected: <claude|codex|unknown>
```

For `claude-first`, `driver` must be `claude-code` and `reviewer` must be `codex-cli`.

For `codex-first`, `driver` must be `codex` and `reviewer` must be `claude-code-cli`.

`session_detected` records the best-effort `scripts/ccc-detect-session.sh` result at run start. It may be `unknown` when shell markers are unavailable or the user selected the workflow explicitly.

`## Rounds` uses machine-readable fields:

```text
plan_rounds: <N>
revision_rounds: <M>
```

`## Git Baseline` records the review base before code changes:

```text
run_start_ref: <git sha or 4b825dc642cb6eb9a060e54bf8d69288fbee4904>
run_start_ref_kind: head | empty_tree
run_start_status_file: state/run_start.status
run_start_unstaged_diff: state/run_start.diff
run_start_staged_diff: state/run_start_cached.diff
```

The coordinator writes those `state/run_start.*` files at run start. `state/run_start.status` is canonical for run-start status; do not duplicate that status inline in `run.md`.

`state/run_start.status` is the exact stdout of `git status --short` at run start. An empty file means the run started clean.

`state/run_start.diff` is the exact stdout of `git diff` at run start.

`state/run_start_cached.diff` is the exact stdout of `git diff --cached` at run start.

For normal repositories, `run_start_ref` is the output of `git rev-parse --verify HEAD` and `run_start_ref_kind` is `head`.

For fresh repositories with no commits, `run_start_ref` is the Git empty-tree SHA `4b825dc642cb6eb9a060e54bf8d69288fbee4904` and `run_start_ref_kind` is `empty_tree`.

If `run_start_ref` is neither a valid git ref nor the empty-tree SHA, code review must use `VERDICT: BLOCKER` unless the user provides another explicit diff base.

`## Workflow State` is machine-readable. Do not rely on prose parsing:

```text
current_stage: <stage|none>
latest_artifact: <artifact path|none>
latest_verdict: <APPROVE|APPROVE_WITH_MINOR_COMMENTS|APPROVE_AUTO_OVERRIDE|NEEDS_CHANGES|BLOCKER|none>
next_action: <stage|complete|blocked|max-rounds-reached|canceled>
```

Field values are constrained:

```text
current_stage: none | plan_vN | plan_vN_review | code_vN | review_vN
latest_artifact: none | artifacts/plan_vN.md | artifacts/plan_vN_review.md | artifacts/code_vN.md | artifacts/review_vN.md
latest_verdict: APPROVE | APPROVE_WITH_MINOR_COMMENTS | APPROVE_AUTO_OVERRIDE | NEEDS_CHANGES | BLOCKER | none
next_action: plan_vN | plan_vN_review | code_vN | review_vN | complete | blocked | max-rounds-reached | canceled
```

`## Status` must contain exactly one of:

```text
active
complete
blocked
max-rounds-reached
canceled
```

Status semantics:

```text
active    the single-session coordinator is still running or resumable
complete  the workflow has an approving code review verdict
blocked   the workflow has a BLOCKER verdict, invalid reviewer output, failed validation, or needs user direction
max-rounds-reached  reserved defensive status for max-version exhaustion without a mode decision
canceled  the user canceled the run
```

`max-rounds-reached` is reserved for defensive consistency and has no normal coordinator path. The mode decision table routes max-version disagreement to `complete`, `blocked`, or `APPROVE_AUTO_OVERRIDE`; hard failures use `blocked`.

All `run.md` writes use a temporary file in the same directory, then an atomic rename.

## Reviewer Calls

### Invocation Mechanism

Reviewer stages run the companion agent from the shell. The coordinator provides the review prompt on stdin and captures the final reviewer message:

```text
1. Build a reviewer prompt from task.md, the relevant artifacts, and git baseline data.
2. Run the workflow-specific non-interactive reviewer command from the repository root.
3. Write the final reviewer message directly to state/<stage>.review.raw.md.
4. Normalize that raw message into the CCC review artifact.
```

All reviewer commands must run with `cwd` set to the repository root. Output paths may be repository-relative or absolute, but they must resolve to the active run folder.

If the reviewer command exits non-zero, the raw transcript is missing, or the raw transcript is empty, stop with `Status: blocked`.

In `claude-first`, plan review uses `codex exec` in read-only mode:

```text
codex exec --sandbox read-only --output-last-message <output_folder>/state/plan_vN_review.review.raw.md -
```

In `codex-first`, plan review uses `claude --print` with tools disabled. Capture stdout to `state/plan_vN_review.review.raw.md.tmp`, then atomically rename it:

```text
claude --print --output-format text --no-session-persistence --tools ""
```

The stdin prompt must ask the reviewer to review `<output_folder>/artifacts/plan_vN.md` against `<output_folder>/task.md`, avoid code edits, and return findings, questions, and whether the plan appears ready for implementation. For `plan_v1+`, include the previous plan and review in the prompt. In `codex-first`, Claude reviewer tools are disabled, so include the referenced file contents in the prompt instead of relying on file access.

Use this prompt shape:

```text
You are the CCC plan reviewer for <stage>.
Read <output_folder>/task.md and <output_folder>/artifacts/plan_vN.md.
For plan_v1+, also read <output_folder>/artifacts/plan_v{N-1}.md and <output_folder>/artifacts/plan_v{N-1}_review.md.

Do not edit files.
Review whether the plan is correct, complete, scoped, and ready to implement.
Return:
## Summary
## Findings
Tag each finding as [minor] or [major].
## Questions
## Readiness
READY: yes|no
```

The coordinator maps readiness to CCC verdicts: `READY: yes` with no material findings becomes `VERDICT: APPROVE`; `READY: yes` with only minor findings becomes `VERDICT: APPROVE_WITH_MINOR_COMMENTS`; `READY: no` with fixable findings becomes `VERDICT: NEEDS_CHANGES`; `READY: no` because of an external blocker or unsafe uncertainty becomes `VERDICT: BLOCKER`.

The coordinator saves the unnormalized reviewer output for each plan review at:

```text
state/plan_vN_review.review.raw.md
```

In `claude-first`, code review uses `codex exec review --uncommitted` when `HEAD` has not moved since run start:

```text
codex exec review --uncommitted --output-last-message <output_folder>/state/review_vN.review.raw.md -
```

Before using this command, confirm `run_start_ref_kind: head` and `git rev-parse HEAD` equals `run_start_ref`. In that normal case, `--uncommitted` is exhaustive because the run baseline is the current `HEAD`; it covers staged, unstaged, and untracked working-tree changes. If `HEAD` has moved, stop with `Status: blocked`; the run has a mid-run commit or external repository mutation and no longer satisfies the CCC review baseline. To recover, restore `HEAD` to `run_start_ref` and resume, or cancel the run and start a new one.

In `codex-first`, code review uses `claude --print` with tools disabled. The driver must include the relevant task, run, code artifact, previous review context, and git diff outputs in the prompt because the reviewer has no tool access:

```text
claude --print --output-format text --no-session-persistence --tools ""
```

The stdin prompt must ask the reviewer to review the actual repository changes, include prior review context for `review_v1+`, and return findings, questions, tests to add, and whether the code appears ready. In `codex-first`, Claude reviewer tools are disabled, so include the referenced artifact contents and git diff outputs in the prompt instead of relying on file access.

`codex exec review` does not accept `--sandbox`; CCC relies on the dedicated review subcommand and must not pass `--dangerously-bypass-approvals-and-sandbox`. To guard tracked and staged repository content, capture `git diff` and `git diff --cached` immediately before and after any code-review command. If the before/after outputs differ, stop with `Status: blocked`, report the mutation diff to the user, and require the user to restore or stash those changes before resuming.

Use this prompt shape:

```text
You are the CCC code reviewer for <stage>.
Read <output_folder>/task.md, <output_folder>/run.md, and <output_folder>/artifacts/code_vN.md.
For review_v1+, also read <output_folder>/artifacts/code_v{N-1}.md and <output_folder>/artifacts/review_v{N-1}.md.

Review the actual repository changes, not only code_vN.md.
Baseline: <run_start_ref>
For the normal path, HEAD equals the baseline, so review staged, unstaged, and untracked working-tree changes.
Do not edit files.
Return:
## Summary
## Findings
Tag each finding as [minor] or [major].
## Tests to Add
## Questions
## Readiness
READY: yes|no
```

The coordinator maps readiness to CCC verdicts: `READY: yes` with no material findings becomes `VERDICT: APPROVE`; `READY: yes` with only minor findings becomes `VERDICT: APPROVE_WITH_MINOR_COMMENTS`; `READY: no` with fixable findings becomes `VERDICT: NEEDS_CHANGES`; `READY: no` because of an external blocker or unsafe uncertainty becomes `VERDICT: BLOCKER`.

If `run_start_ref_kind` is `empty_tree` in `claude-first`, use `codex exec --sandbox read-only` instead because `codex exec review --uncommitted` only covers changes against current `HEAD`. Include the relevant diff commands from `Git Review Baseline` in the prompt:

```text
codex exec --sandbox read-only --output-last-message <output_folder>/state/review_vN.review.raw.md -
```

Use this fallback prompt shape:

```text
You are the CCC code reviewer for <stage>.
Read <output_folder>/task.md, <output_folder>/run.md, and <output_folder>/artifacts/code_vN.md.
For review_v1+, also read <output_folder>/artifacts/code_v{N-1}.md and <output_folder>/artifacts/review_v{N-1}.md.

Review the actual repository changes, not only code_vN.md.
Baseline: <run_start_ref>
Use the empty-tree diff commands from Git Review Baseline to inspect the repository state.
Do not edit files.
Return:
## Summary
## Findings
Tag each finding as [minor] or [major].
## Tests to Add
## Questions
## Readiness
READY: yes|no
```

The coordinator must copy or summarize reviewer output into the required review artifact, preserving findings and producing exactly one valid CCC verdict line. If reviewer output does not clearly support a protocol verdict, the coordinator asks the reviewer for clarification with another non-interactive call or stops with `Status: blocked`.

Clarification output must not overwrite the first raw transcript. Append clarification calls to the same `state/<stage>.review.raw.md` file under a clear separator such as `--- Clarification 1 ---`, then normalize from the combined raw transcript.

The coordinator saves the unnormalized reviewer output for each code review at:

```text
state/review_vN.review.raw.md
```

The CCC review artifact is an attested summary of the raw reviewer output, not a replacement for it. The coordinator may write the final `VERDICT:` line itself after interpreting the raw output, but it must not silently soften or discard material findings. If the raw output does not clearly support one protocol verdict, stop with `Status: blocked`.

## Git Review Baseline

`ccc-code-review` must inspect the actual repository, not only `code_vN.md`.

When `run_start_ref_kind` is `head`, use `run_start_ref` as the baseline:

```text
git status --short
git diff --stat <run_start_ref>...HEAD
git diff <run_start_ref>...HEAD
git diff --cached
git diff
```

When `run_start_ref_kind` is `empty_tree`, compare the empty tree to `HEAD` without triple-dot merge-base syntax:

```text
git status --short
git diff --stat 4b825dc642cb6eb9a060e54bf8d69288fbee4904 HEAD
git diff 4b825dc642cb6eb9a060e54bf8d69288fbee4904 HEAD
git diff --cached
git diff
```

Driver commits during a run are not allowed. The intended review surface is the working tree relative to `run_start_ref`; `git diff --cached` and `git diff` catch staged and unstaged tracked changes that are not in `HEAD`.

If the run started dirty, compare current status and diffs against `state/run_start.status`, `state/run_start.diff`, and `state/run_start_cached.diff` before assigning findings to the CCC run.

Each `code_vN.md` must include the run baseline and current `HEAD` under `## Git Baseline`.

Each `review_vN.md` must include the `run_start_ref` from `run.md` under `## Diff Baseline`. Validation must confirm the Diff Baseline SHA equals `run_start_ref`.

## Verdicts

All review artifacts use the same verdict vocabulary:

```text
VERDICT: APPROVE
VERDICT: APPROVE_WITH_MINOR_COMMENTS
VERDICT: APPROVE_AUTO_OVERRIDE
VERDICT: NEEDS_CHANGES
VERDICT: BLOCKER
```

Validation must match exactly one whole line with this regex:

```text
^VERDICT: (APPROVE|APPROVE_WITH_MINOR_COMMENTS|APPROVE_AUTO_OVERRIDE|NEEDS_CHANGES|BLOCKER)$
```

Do not use substring matching.

`APPROVE`, `APPROVE_WITH_MINOR_COMMENTS`, and `APPROVE_AUTO_OVERRIDE` allow the workflow to advance.

`APPROVE_AUTO_OVERRIDE` is machine-readable evidence that the coordinator proceeded in `auto` mode despite unresolved reviewer disagreement. It must include an `AUTO OVERRIDE:` line in the artifact's `## Summary`.

Validation must reject `APPROVE_AUTO_OVERRIDE` without `AUTO OVERRIDE:` in `## Summary`, and must reject `AUTO OVERRIDE:` when the verdict is not `APPROVE_AUTO_OVERRIDE`.

`NEEDS_CHANGES` asks the driver for the next plan or code version, if another version is allowed.

`BLOCKER` follows the mode decision table.

Minor issues are non-material comments, nits, or follow-up suggestions that do not affect correctness, safety, data integrity, public contracts, user-visible behavior, or verification. Major issues affect one of those areas or make the result unsafe to judge. Findings must be tagged `[minor]` or `[major]` in raw reviewer output, and the coordinator must preserve those tags in the normalized artifact's `## Findings` body. If severity is ambiguous, treat it as major.

When no further plan or code version is allowed, follow the mode decision table. `normal` mode may override unresolved minor-only findings to `VERDICT: APPROVE_WITH_MINOR_COMMENTS`; major unresolved findings block. `auto` mode may override unresolved reviewer disagreement to `VERDICT: APPROVE_AUTO_OVERRIDE`; hard failures still block.

## Planning Transitions

If no plan exists:

```text
driver writes artifacts/plan_v0.md
coordinator writes state/plan_v0.done
```

If `plan_vN.done` exists and `plan_vN_review.done` does not exist:

```text
driver runs the workflow-specific reviewer command for plan review
driver writes state/plan_vN_review.review.raw.md from reviewer output
driver writes artifacts/plan_vN_review.md from reviewer output
coordinator writes state/plan_vN_review.done
```

If `plan_vN_review.md` says `VERDICT: APPROVE`, `VERDICT: APPROVE_WITH_MINOR_COMMENTS`, or `VERDICT: APPROVE_AUTO_OVERRIDE`, planning is approved and the driver may write `artifacts/code_v0.md`.

If `plan_vN_review.md` says `VERDICT: NEEDS_CHANGES`, the driver writes `artifacts/plan_v{N+1}.md`, unless `N` already equals `plan_rounds`.

If `N` already equals `plan_rounds`, follow the mode decision table.

If `plan_vN_review.md` says `VERDICT: BLOCKER`, follow the mode decision table.

In `manual` or `normal` mode, if the final allowed plan version has been written and still is not approved, do not mark the workflow complete. Stop and report:

```text
Max plan version reached; latest artifact is plan_vN.md and is not approved.
```

## Code and Review Transitions

After planning is approved:

```text
driver writes artifacts/code_v0.md
coordinator writes state/code_v0.done
```

If `code_vN.done` exists and `review_vN.done` does not exist:

```text
driver runs the workflow-specific reviewer command for code review
driver writes state/review_vN.review.raw.md from reviewer output
driver writes artifacts/review_vN.md from reviewer output
coordinator writes state/review_vN.done
```

If `review_vN.md` says `VERDICT: APPROVE`, `VERDICT: APPROVE_WITH_MINOR_COMMENTS`, or `VERDICT: APPROVE_AUTO_OVERRIDE`, the workflow is complete.

If `review_vN.md` says `VERDICT: NEEDS_CHANGES`, the driver writes `artifacts/code_v{N+1}.md`, unless `N` already equals `revision_rounds`.

If `N` already equals `revision_rounds`, follow the mode decision table.

If `review_vN.md` says `VERDICT: BLOCKER`, follow the mode decision table.

In `manual` or `normal` mode, if the final allowed code version has been written and still is not approved, do not mark the workflow complete. Stop and report:

```text
Max code version reached; latest artifact is code_vN.md and is not approved.
```

## Artifact Contracts

`plan_vN.md` required sections:

```text
# Plan vN
## Summary
## Scope
## Proposed Changes
## Files and Areas
## Verification Plan
## Risks and Questions
## Changes Since Previous Plan Version
```

`plan_v0.md` must write `Initial plan.` in `Changes Since Previous Plan Version`.

`plan_v1+` must summarize what changed in response to `plan_v{N-1}_review.md`.

`plan_vN_review.md` required sections:

```text
# Plan vN Review
## Summary
## Findings
## Questions
## Verdict
One protocol-approved verdict line.
```

Each `plan_vN_review.md` must have a corresponding non-empty raw transcript:

```text
state/plan_vN_review.review.raw.md
```

`code_vN.md` required sections:

```text
# Code vN
## Overview
## What Changed
## Implementation Details
## Files Changed
| File | Purpose |
|---|---|
## Git Baseline
## Verification
## Review Focus
## Risks and Unknowns
## Changes Since Previous Code Version
```

`## Git Baseline` must include:

```text
run_start_ref: <sha>
current_head: <sha|none>
```

`code_v0.md` must write `Initial implementation.` in `Changes Since Previous Code Version`.

`code_v1+` must summarize what changed in response to `review_v{N-1}.md`.

`review_vN.md` required sections:

```text
# Review vN
## Summary
## Diff Baseline
## Findings
## Tests to Add
## Questions
## Verdict
One protocol-approved verdict line.
```

`## Diff Baseline` must include:

```text
run_start_ref: <sha>
```

Each `review_vN.md` must have a corresponding non-empty raw transcript:

```text
state/review_vN.review.raw.md
```

## Write Ordering

For every stage, write files in this order:

```text
1. For reviewer stages, write state/<stage>.review.raw.md.tmp and atomically rename it to state/<stage>.review.raw.md.
2. Write artifacts/<stage>.md.tmp.
3. Validate the intended final artifact path and required raw transcript, when applicable.
4. Atomically rename artifacts/<stage>.md.tmp to artifacts/<stage>.md.
5. Write state/<stage>.done.tmp.
6. Atomically rename state/<stage>.done.tmp to state/<stage>.done.
7. Update run.md through a same-directory temporary file and atomic rename.
```

The `.done` file is the commit point for a stage. Step 3 is a model-side validation against the would-be final filenames; `scripts/ccc-validate.sh` is a post-hoc run-folder validator and does not validate temporary paths. A coordinator resuming after a crash must ignore partial `*.tmp` files until a human intentionally repairs or removes them. Repair removes only files the user names; never sweep `state/*.tmp` or `artifacts/*.tmp` automatically.

## Validation Before .done

Before writing `.done`, the coordinator validates:

```text
artifact exists
artifact is non-empty
expected top-level heading exists exactly once
required sections exist exactly as listed in Artifact Contracts
review artifacts contain exactly one valid whole-line VERDICT
APPROVE_AUTO_OVERRIDE has "AUTO OVERRIDE:" in ## Summary, and no other verdict uses "AUTO OVERRIDE:"
plan_v0 and code_v0 have required non-empty Changes Since text
plan_v1+ and code_v1+ have non-empty Changes Since sections
code_vN Git Baseline contains run_start_ref and current_head
review_vN Diff Baseline SHA equals run_start_ref from run.md
plan_vN_review and review_vN have non-empty state/<stage>.review.raw.md files
```

Filename-to-heading validation is exact:

```text
plan_v(0|[1-9][0-9]*)\.md          -> # Plan v\1
plan_v(0|[1-9][0-9]*)_review\.md   -> # Plan v\1 Review
code_v(0|[1-9][0-9]*)\.md          -> # Code v\1
review_v(0|[1-9][0-9]*)\.md        -> # Review v\1
```

Versions are decimal integers with no leading zeros except `v0`.

Only the coordinator writes `.done` files. Individual stage skills must not write `.done`.

Done file content:

```text
---
stage: <stage>
artifact: artifacts/<artifact>.md
status: complete
---
Completed by CCC coordinator after artifact validation.
```

## Resume

`/ccc resume <output_folder>` reads `run.md`, `.done` files, artifact verdicts, and the configured rounds, then continues from the next missing stage.

Resume must not infer workflow state only from `run.md`; `.done` files and artifact verdicts are the source of truth.

If an artifact exists without the matching `.done`, the previous stage did not commit. The coordinator must stop and ask the user to choose one repair: rerun the stage and overwrite the artifact, move the artifact aside and resume, or manually validate it and write the `.done` only if it satisfies this protocol. If a `.done` exists without its artifact, the run is invalid and must be repaired before resume.

## Cancel

To abandon a run, use:

```text
/ccc cancel <output_folder> "<reason>"
```

The coordinator writes or updates `run.md` with `Status: canceled`, records the reason, and stops. Cancel does not delete artifacts.

## Validator

Use `scripts/ccc-validate.sh <output_folder>` to mechanically validate `run.md`, artifact headings, required sections, verdict lines, baseline keys, and `.done` references for a CCC run.

## Final Output

Always end with:

```text
CCC run: <output_folder>
Stage completed: <stage|none>
Next action: <stage|complete|blocked|max-rounds-reached|canceled>
```

## Stage Skills

Use these skills:

```text
ccc
ccc-plan
ccc-plan-review
ccc-code
ccc-code-review
```
