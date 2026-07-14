#!/usr/bin/env bash
# gen_sbom.sh — generate a CycloneDX JSON SBOM for a repository using syft.
#
# Usage: gen_sbom.sh [repo-dir] [ref-label]
#   repo-dir   directory to scan (default: .)
#   ref-label  label for the output file, e.g. a tag (default: git describe,
#              falling back to "unversioned")
#
# Output: <repo-dir>/compliance/sbom/<ref-label>.cdx.json
# Prints the output path on stdout (last line) so callers can chain it.
set -euo pipefail

REPO_DIR="${1:-.}"
[ -d "$REPO_DIR" ] || { echo "ERROR: not a directory: $REPO_DIR" >&2; exit 2; }

REF="${2:-$(git -C "$REPO_DIR" describe --tags --always 2>/dev/null || echo unversioned)}"
SAFE_REF="${REF//\//-}"

if ! command -v syft >/dev/null 2>&1; then
  echo "ERROR: syft not found — required to generate the SBOM." >&2
  echo "Install: brew install syft   (or see https://github.com/anchore/syft#installation)" >&2
  exit 127
fi

OUT_DIR="$REPO_DIR/compliance/sbom"
mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/$SAFE_REF.cdx.json"

syft scan "dir:$REPO_DIR" -o "cyclonedx-json=$OUT_FILE" --quiet
echo "SBOM: $(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(len(d.get('components',[])))" "$OUT_FILE") components" >&2
echo "$OUT_FILE"
