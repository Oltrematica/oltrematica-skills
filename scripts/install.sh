#!/usr/bin/env bash
# install.sh — copy one or more skills from this repo into a target repo's
# .claude/skills/ directory.
#
# Usage: scripts/install.sh <skill-name>... --to <target-repo>
#
# Skills live under skills/<track>/<name>/ here, but always install to the flat
# path .claude/skills/<name>/ — Claude Code requires .claude/skills/<name>/SKILL.md
# and knows nothing about tracks.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

usage() {
  cat >&2 <<EOF
Usage: scripts/install.sh <skill-name>... --to <target-repo>

Available skills:
$(available | sed 's/^/  - /')
EOF
  exit 2
}

available() {
  find "$REPO_ROOT/skills" -mindepth 2 -maxdepth 2 -type d -exec basename {} \; | sort
}

SKILLS=()
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --to) [ $# -ge 2 ] || usage; TARGET="$2"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "ERROR: unknown option: $1" >&2; usage ;;
    *) SKILLS+=("$1"); shift ;;
  esac
done

[ ${#SKILLS[@]} -gt 0 ] || usage
[ -n "$TARGET" ] || usage

if [ -e "$TARGET" ] && [ ! -d "$TARGET" ]; then
  echo "ERROR: target repo path exists but is not a directory: $TARGET" >&2
  exit 2
fi
[ -d "$TARGET" ] || { echo "ERROR: target repo not found: $TARGET" >&2; exit 2; }

for name in "${SKILLS[@]}"; do
  src=$(find "$REPO_ROOT/skills" -mindepth 2 -maxdepth 2 -type d -name "$name" | head -1)
  if [ -z "$src" ]; then
    echo "ERROR: no skill named '$name' in this repo." >&2
    echo "Available skills:" >&2
    available | sed 's/^/  - /' >&2
    exit 1
  fi
  dest="$TARGET/.claude/skills/$name"
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  cp -R "$src" "$dest"
  echo "installed $name -> $dest"
done

echo
echo "Done. Restart Claude Code in $TARGET and run /skills to verify."
