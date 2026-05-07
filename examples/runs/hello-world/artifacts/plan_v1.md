# Plan v1

## Summary

Add a minimal module with CLI execution and a smoke test.

## Scope

Create one command module and one test.

## Proposed Changes

Add `src/hello.py` with a `main()` function that prints `hello, world`, and support `python -m src.hello`.

## Files and Areas

`src/hello.py` and `tests/test_hello.py`.

## Verification Plan

Run `pytest tests/test_hello.py` and `python -m src.hello`.

## Risks and Questions

No product risk; this is a small illustrative example.

## Changes Since Previous Plan Version

Clarified the CLI invocation path requested by `plan_v0_review.md`.
