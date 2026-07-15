#!/usr/bin/env bash
# new_adr.sh — create a new ADR with the next sequential number.
# Usage: new_adr.sh "Short imperative title" [adr-directory]
set -euo pipefail

TITLE="${1:?Usage: new_adr.sh \"Title\" [adr-dir]}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../assets/template.md"

# Resolve ADR directory: explicit arg > .adr-dir > common conventions > default
if [ "${2:-}" != "" ]; then
  ADR_DIR="$2"
elif [ -f .adr-dir ]; then
  ADR_DIR="$(cat .adr-dir)"
else
  ADR_DIR=""
  for d in docs/adr docs/decisions adr doc/adr; do
    [ -d "$d" ] && ADR_DIR="$d" && break
  done
  [ -z "$ADR_DIR" ] && ADR_DIR="docs/adr"
fi
mkdir -p "$ADR_DIR"

# Next 4-digit number (10#$n avoids octal parsing of e.g. 0008)
LAST=$(find "$ADR_DIR" -maxdepth 1 -name '[0-9][0-9][0-9][0-9]-*.md' \
  | sed -E 's|.*/([0-9]{4})-.*|\1|' | sort -n | tail -1)
NEXT=$(printf "%04d" $(( 10#${LAST:-0} + 1 )))

# Kebab-case slug
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')

FILE="$ADR_DIR/$NEXT-$SLUG.md"
[ -e "$FILE" ] && { echo "Refusing to overwrite $FILE" >&2; exit 1; }

if [ -f "$TEMPLATE" ]; then
  sed -e "s/^# NNNN\..*/# $NEXT. $TITLE/" \
      -e "s/YYYY-MM-DD/$(date +%F)/" "$TEMPLATE" > "$FILE"
else
  printf '# %s. %s\n\n**Status**: Proposed\n**Date**: %s\n\n## Context\n\n## Decision\n\n## Alternatives considered\n\n## Consequences\n\n## References\n' \
    "$NEXT" "$TITLE" "$(date +%F)" > "$FILE"
fi

echo "$FILE"
