# CCC Run

## Description

Example run showing a small `claude-first` CCC flow with reviewer stages.

This example uses repository SHA `81e5af01a21287343e988d57809bb371e3ad0419` for illustration. Real runs should replace it with the output of `git rev-parse HEAD` at run start.

## Runtime

workflow: claude-first
driver: claude-code
reviewer: codex-cli
session_detected: claude

## Rounds

plan_rounds: 2
revision_rounds: 2

## Task Summary

Add and verify a small `hello` command.

## Git Baseline

run_start_ref: 81e5af01a21287343e988d57809bb371e3ad0419
run_start_ref_kind: head
run_start_status_file: state/run_start.status
run_start_unstaged_diff: state/run_start.diff
run_start_staged_diff: state/run_start_cached.diff

## Workflow State

current_stage: review_v1
latest_artifact: artifacts/review_v1.md
latest_verdict: APPROVE_WITH_MINOR_COMMENTS
next_action: complete

## Status

complete
