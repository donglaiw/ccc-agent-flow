#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <done-file>" >&2
  exit 2
fi

done_file="$1"

while [ ! -f "$done_file" ]; do
  sleep 1
done

printf '%s\n' "$done_file"
