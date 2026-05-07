#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: ccc-wait-done.sh [--timeout SECONDS | --no-timeout] [--interval SECONDS] <done-file>

Wait for a CCC .done file.

Defaults:
  --timeout 300
  --interval 1

Exit codes:
  0    file appeared
  2    usage error
  124  timeout
USAGE
}

timeout_seconds=300
interval_seconds=1
no_timeout=0
timeout_seen=0
no_timeout_seen=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --timeout|-t)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      [ "$no_timeout_seen" -eq 0 ] || { usage; exit 2; }
      timeout_seconds="$2"
      no_timeout=0
      timeout_seen=1
      shift 2
      ;;
    --no-timeout)
      [ "$timeout_seen" -eq 0 ] || { usage; exit 2; }
      no_timeout=1
      no_timeout_seen=1
      shift
      ;;
    --interval|-i)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      interval_seconds="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      usage
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

[ "$#" -eq 1 ] || { usage; exit 2; }

if [ "$no_timeout" -eq 0 ]; then
  case "$timeout_seconds" in
    ''|*[!0-9]*)
      usage
      exit 2
      ;;
  esac

  [ "$timeout_seconds" -gt 0 ] || { usage; exit 2; }
fi

case "$interval_seconds" in
  ''|*[!0-9]*)
    usage
    exit 2
    ;;
esac

[ "$interval_seconds" -gt 0 ] || { usage; exit 2; }

done_file="$1"
start_time="$(date +%s)"

while [ ! -f "$done_file" ]; do
  now="$(date +%s)"
  elapsed=$((now - start_time))

  if [ "$no_timeout" -eq 0 ] && [ "$elapsed" -ge "$timeout_seconds" ]; then
    echo "Timed out waiting for $done_file after ${timeout_seconds}s" >&2
    exit 124
  fi

  sleep "$interval_seconds"
done

printf '%s\n' "$done_file"
