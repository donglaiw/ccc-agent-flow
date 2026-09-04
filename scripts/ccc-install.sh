#!/usr/bin/env bash
set -euo pipefail

# Install the five CCC skills so each installed skill dir carries the protocol
# and scripts it references. Without this, `<CCC_HOME>/protocol/CCC_PROTOCOL.md`
# does not resolve from an installed skill.

CCC_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS=(ccc ccc-plan ccc-plan-review ccc-code ccc-code-review)
DEST="${HOME}/.claude/skills"
MODE="link"
FORCE=0

usage() {
  cat <<'USAGE'
Usage: ccc-install.sh [--dest DIR] [--link|--copy] [--force]

  --dest DIR   skills directory to install into (default: ~/.claude/skills)
  --link       symlink each skill to this checkout, so edits take effect
               immediately and protocol/scripts resolve through the checkout
               (default)
  --copy       copy each skill, dereferencing the bundled protocol/ and
               scripts/ into real files, for a checkout-independent install
  --force      replace existing entries at the destination
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dest) [ "$#" -ge 2 ] || { echo "ccc-install: --dest needs a directory" >&2; exit 2; }
            DEST="$2"; shift 2 ;;
    --link) MODE="link"; shift ;;
    --copy) MODE="copy"; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ccc-install: unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ -f "$CCC_ROOT/protocol/CCC_PROTOCOL.md" ] || {
  echo "ccc-install: not a ccc-duet checkout: $CCC_ROOT" >&2; exit 1; }

mkdir -p "$DEST"

for skill in "${SKILLS[@]}"; do
  src="$CCC_ROOT/skills/$skill"
  dst="$DEST/$skill"

  [ -f "$src/SKILL.md" ] || { echo "ccc-install: missing $src/SKILL.md" >&2; exit 1; }

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ "$FORCE" -eq 1 ]; then
      rm -rf "$dst"
    else
      echo "ccc-install: $dst exists; re-run with --force to replace" >&2
      exit 1
    fi
  fi

  case "$MODE" in
    link) ln -s "$src" "$dst" ;;
    copy) cp -RL "$src" "$dst" ;;
  esac
  echo "ccc-install: $MODE $skill -> $dst"
done

echo
"$CCC_ROOT/scripts/ccc-check-install.sh" "$DEST"
