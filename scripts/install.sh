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
  # Reject a name of "." or ".." or one containing "/" explicitly, rather than
  # relying on downstream accidents (the ambiguity check tripping because >=2
  # tracks exist, or `rm`/`cp` refusing "."/".."/a path) to catch it.
  case "$name" in
    .|..)
      echo "ERROR: '$name' is not a valid skill name." >&2
      exit 2
      ;;
    */*)
      echo "ERROR: skill name must not contain '/': $name" >&2
      exit 2
      ;;
  esac

  # Match the skill name literally against each track dir's basename — do NOT
  # pass "$name" to `find -name`, which treats it as a shell glob pattern
  # (e.g. '*' would silently match an arbitrary skill).
  MATCHES=()
  for track_dir in "$REPO_ROOT"/skills/*/; do
    [ -d "$track_dir" ] || continue
    candidate="${track_dir}${name}"
    if [ -d "$candidate" ] && [ "$(basename "$candidate")" = "$name" ]; then
      MATCHES+=("$candidate")
    fi
  done

  if [ ${#MATCHES[@]} -eq 0 ]; then
    echo "ERROR: no skill named '$name' in this repo." >&2
    echo "Available skills:" >&2
    available | sed 's/^/  - /' >&2
    exit 1
  fi

  if [ ${#MATCHES[@]} -gt 1 ]; then
    echo "ERROR: skill name '$name' is ambiguous — it exists in more than one track:" >&2
    for m in "${MATCHES[@]}"; do
      echo "  - $(basename "$(dirname "$m")")/$name" >&2
    done
    echo "Resolve by renaming one of the skills so the name is unique." >&2
    exit 1
  fi

  src="${MATCHES[0]}"
  dest="$TARGET/.claude/skills/$name"
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  cp -R "$src" "$dest"
  echo "installed $name -> $dest"
done

echo
echo "Done. Restart Claude Code in $TARGET and run /skills to verify."
