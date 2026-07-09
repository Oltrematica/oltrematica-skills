#!/usr/bin/env bash
# a11y_scan.sh — run axe-core (WCAG automated checks) against a list of routes.
#
# Usage: a11y_scan.sh BASE_URL OUT_DIR ROUTE [ROUTE...]
#   e.g.: a11y_scan.sh https://staging.example.com compliance/a11y / /login /contact
#
# Writes one axe-<route-slug>.json per route into OUT_DIR and prints OUT_DIR
# on stdout (last line). Requires Node (npx) and a Chrome/Chromium available
# to @axe-core/cli's webdriver. A route that fails to scan logs a WARN and
# does not abort the remaining routes.
#
# NOTE: automated checks cover only part of WCAG 2.1 AA — see
# references/eaa_wcag_checklist.md for the manual-verification items.
set -euo pipefail

BASE_URL="${1:?Usage: a11y_scan.sh BASE_URL OUT_DIR ROUTE [ROUTE...]}"
OUT_DIR="${2:?Usage: a11y_scan.sh BASE_URL OUT_DIR ROUTE [ROUTE...]}"
shift 2
[ "$#" -ge 1 ] || { echo "ERROR: at least one route required (e.g. /)" >&2; exit 2; }

if ! command -v npx >/dev/null 2>&1; then
  echo "ERROR: npx (Node.js) not found — required to run @axe-core/cli." >&2
  echo "Install Node.js: brew install node   (https://nodejs.org)" >&2
  exit 127
fi

mkdir -p "$OUT_DIR"
FAILED=0
for ROUTE in "$@"; do
  SLUG=$(printf '%s' "$ROUTE" | sed -E 's|[^a-zA-Z0-9]+|-|g; s/^-+//; s/-+$//')
  SLUG="${SLUG:-root}"
  if ! npx --yes @axe-core/cli "$BASE_URL$ROUTE" --save "$OUT_DIR/axe-$SLUG.json" >&2; then
    echo "WARN: axe scan failed for $ROUTE (browser/webdriver missing or page unreachable) — continuing" >&2
    FAILED=$((FAILED + 1))
  fi
done
[ "$FAILED" -eq "$#" ] && { echo "ERROR: all $# route scans failed." >&2; exit 1; }
echo "$OUT_DIR"
