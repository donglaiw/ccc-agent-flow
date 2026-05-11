#!/usr/bin/env bash
set -euo pipefail

detect_agent_cli() {
  if [ "${CLAUDECODE:-}" = "1" ] || [ -n "${CLAUDE_CODE_SESSION_ID:-}" ]; then
    echo "claude"
  elif [ "${CODEX_CI:-}" = "1" ]; then
    echo "codex"
  else
    echo "unknown"
  fi
}

detect_agent_cli
