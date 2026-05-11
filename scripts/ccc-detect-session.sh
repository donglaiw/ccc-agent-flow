#!/usr/bin/env bash
set -euo pipefail

detect_agent_cli() {
  local is_claude=0
  local is_codex=0

  if [ "${CLAUDECODE:-}" = "1" ] || [ -n "${CLAUDE_CODE_SESSION_ID:-}" ]; then
    is_claude=1
  fi

  if [ "${CODEX_CI:-}" = "1" ]; then
    is_codex=1
  fi

  if [ "$is_claude" -eq 1 ] && [ "$is_codex" -eq 1 ]; then
    echo "unknown"
  elif [ "$is_claude" -eq 1 ]; then
    echo "claude"
  elif [ "$is_codex" -eq 1 ]; then
    echo "codex"
  else
    echo "unknown"
  fi
}

detect_agent_cli
