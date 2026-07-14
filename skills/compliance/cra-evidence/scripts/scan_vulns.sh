#!/usr/bin/env bash
# scan_vulns.sh — scan a CycloneDX SBOM for known vulnerabilities.
#
# Usage: scan_vulns.sh SBOM_FILE [output.json]
#   Uses grype when available (primary), osv-scanner as fallback.
#   Default output: alongside the SBOM, extension .vulns.json.
#
# Prints the output path on stdout (last line). The scanner used is
# reported on stderr. Exit: 0 on completed scan (even with findings),
# 2 on usage error, 127 when no scanner is installed.
set -euo pipefail

SBOM="${1:?Usage: scan_vulns.sh SBOM_FILE [output.json]}"
[ -f "$SBOM" ] || { echo "ERROR: SBOM file not found: $SBOM" >&2; exit 2; }
OUT="${2:-${SBOM%.cdx.json}.vulns.json}"

if command -v grype >/dev/null 2>&1; then
  grype "sbom:$SBOM" -o json --quiet > "$OUT"
  echo "scanner: grype $(grype version 2>/dev/null | awk '/^Version:/{print $2}')" >&2
elif command -v osv-scanner >/dev/null 2>&1; then
  # osv-scanner exits 1 when vulnerabilities are found — that is a completed
  # scan, not an error. Only propagate exits > 1.
  set +e
  osv-scanner --sbom="$SBOM" --format json > "$OUT"
  RC=$?
  set -e
  [ "$RC" -le 1 ] || { echo "ERROR: osv-scanner failed (exit $RC)" >&2; exit "$RC"; }
  echo "scanner: osv-scanner (fallback — grype not installed)" >&2
else
  echo "ERROR: no vulnerability scanner found (looked for: grype, osv-scanner)." >&2
  echo "Install the primary scanner: brew install grype   (https://github.com/anchore/grype#installation)" >&2
  echo "Or the fallback:            brew install osv-scanner (https://google.github.io/osv-scanner/)" >&2
  exit 127
fi

echo "$OUT"
