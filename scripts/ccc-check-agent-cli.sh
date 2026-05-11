#!/usr/bin/env bash
set -euo pipefail

CCC_CHECK_TMPDIR=""
cleanup() {
  if [ -n "$CCC_CHECK_TMPDIR" ]; then
    rm -rf "$CCC_CHECK_TMPDIR"
  fi
}
trap cleanup EXIT

usage() {
  echo "Usage: ccc-check-agent-cli.sh <claude|codex|all>" >&2
}

require_help_flag() {
  local haystack=$1
  local needle=$2
  if ! grep -F -- "$needle" >/dev/null <<<"$haystack"; then
    echo "ccc-check-agent-cli: missing required help flag: $needle" >&2
    exit 1
  fi
}

check_codex() {
  command -v codex >/dev/null
  codex login status >/dev/null

  local exec_help
  exec_help=$(codex exec --help)
  require_help_flag "$exec_help" "--sandbox"
  require_help_flag "$exec_help" "--output-last-message"

  echo "codex agent OK: codex exec supports required flags and auth is active"
}

check_claude() {
  command -v claude >/dev/null

  local help
  help=$(claude --help)
  require_help_flag "$help" "--print"
  require_help_flag "$help" "--output-format"
  require_help_flag "$help" "--no-session-persistence"
  require_help_flag "$help" "--tools"

  local ready
  ready=$(printf 'Return READY only.\n' | claude --print --output-format text --no-session-persistence --tools "")
  if ! grep -F "READY" >/dev/null <<<"$ready"; then
    echo "ccc-check-agent-cli: claude stdin smoke test did not return READY" >&2
    exit 1
  fi

  CCC_CHECK_TMPDIR=$(mktemp -d)

  local sentinel_file="$CCC_CHECK_TMPDIR/sentinel.txt"
  local sentinel="CCC_SENTINEL_${RANDOM}_${RANDOM}_${RANDOM}"
  printf '%s\n' "$sentinel" >"$sentinel_file"

  local response
  response=$(
    printf 'Tools should be disabled. Do not guess. If you can read %s, print its contents. If you cannot read it, print CANNOT_READ_SENTINEL only.\n' "$sentinel_file" |
      claude --print --output-format text --no-session-persistence --tools ""
  )

  rm -rf "$CCC_CHECK_TMPDIR"
  CCC_CHECK_TMPDIR=""

  # The security property is non-disclosure: the sentinel must not leak.
  # The exact refusal text may vary across Claude CLI versions.
  if grep -F "$sentinel" >/dev/null <<<"$response"; then
    echo "ccc-check-agent-cli: claude --tools \"\" exposed a sentinel file" >&2
    exit 1
  fi

  echo "claude agent OK: claude accepts required flags and did not expose a sentinel file with tools disabled"
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

case "$1" in
  claude)
    check_claude
    ;;
  codex)
    check_codex
    ;;
  all)
    check_claude
    check_codex
    ;;
  *)
    usage
    exit 2
    ;;
esac
