#!/usr/bin/env bash
# inventory.sh — read-only inventory of a repo's Claude Code harness surfaces.
#
# Usage: inventory.sh [repo-root]     (default: current directory)
# Output: JSON on stdout describing seven surfaces.
# Exit: 0 on success; 1 if repo-root is not a directory; 127 if python3 is
#       missing (required — stdlib json is used to keep output always valid).
#
# This script reports FACTS ONLY. It never judges. Classification into
# present/gap/not-applicable is the skill's job, not the script's.
#
# Robustness notes (this runs against arbitrary, possibly messy, repos):
# - Every JSON string value (repo_root, verify_gate.source) is produced via
#   python's json.dumps, never by hand-quoting a bash variable into a JSON
#   literal — so quotes/backslashes/spaces/newlines in a repo path can never
#   corrupt the output.
# - Every python helper takes its path via argv (heredoc + "$@"), never by
#   interpolating the path into the python source text, so a path containing
#   a single quote cannot break out of the embedded script.
# - Malformed JSON in composer.json/package.json/settings.json is treated as
#   "absent/not configured", not a crash — caught explicitly, never left to
#   an uncaught traceback.
set -euo pipefail

command -v python3 >/dev/null 2>&1 || {
  echo "ERROR: python3 not found — required to emit valid JSON." >&2
  echo "Install Python 3: https://www.python.org/downloads/" >&2
  exit 127
}

ROOT="${1:-.}"
[ -d "$ROOT" ] || { echo "ERROR: not a directory: $ROOT" >&2; exit 1; }
ROOT=$(cd "$ROOT" && pwd)

# JSON-encode a single string (with surrounding quotes) via argv — never
# via source-text interpolation, so arbitrary bytes in the input are safe.
json_str() {
  python3 - "$1" <<'PY'
import json, sys
print(json.dumps(sys.argv[1]))
PY
}

# JSON array of a directory's visible entry basenames; "[]" if absent or
# unreadable. Always prints valid JSON, even on a permission error.
list_names() {
  python3 - "$1" <<'PY'
import json, os, sys
d = sys.argv[1]
try:
    if os.path.isdir(d):
        print(json.dumps(sorted(e for e in os.listdir(d) if not e.startswith('.'))))
    else:
        print('[]')
except OSError:
    print('[]')
PY
}

# "true"/"false": whether <file> parses as JSON and its top-level <key> is truthy.
# Any parse error, missing file, or falsy/missing key -> "false". Never raises.
json_key_truthy() {
  python3 - "$1" "$2" <<'PY'
import json, sys
path, key = sys.argv[1], sys.argv[2]
try:
    with open(path) as f:
        d = json.load(f)
    print('true' if isinstance(d, dict) and d.get(key) else 'false')
except Exception:
    print('false')
PY
}

# "true"/"false": whether <file> parses as JSON and has a top-level
# "scripts"."test" key (npm/composer convention). Never raises.
has_scripts_test() {
  python3 - "$1" <<'PY'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        d = json.load(f)
    scripts = d.get('scripts') if isinstance(d, dict) else None
    print('true' if isinstance(scripts, dict) and 'test' in scripts else 'false')
except Exception:
    print('false')
PY
}

# --- Surface 1: CLAUDE.md ---
CLAUDE_MD="$ROOT/CLAUDE.md"
if [ -f "$CLAUDE_MD" ] && [ -r "$CLAUDE_MD" ]; then
  CM_EXISTS=true
  CM_LINES=$(wc -l < "$CLAUDE_MD" 2>/dev/null | tr -d ' ')
  case "$CM_LINES" in ''|*[!0-9]*) CM_LINES=0 ;; esac
else
  CM_EXISTS=false
  CM_LINES=0
fi

# --- Surfaces 2, 3, 5: skills, agents, commands ---
SKILLS=$(list_names "$ROOT/.claude/skills")
AGENTS=$(list_names "$ROOT/.claude/agents")
COMMANDS=$(list_names "$ROOT/.claude/commands")
[ -n "$SKILLS" ] || SKILLS='[]'
[ -n "$AGENTS" ] || AGENTS='[]'
[ -n "$COMMANDS" ] || COMMANDS='[]'

# --- Surface 4: hooks ---
SETTINGS="$ROOT/.claude/settings.json"
HOOKS_FILE=false
HOOKS_CONFIGURED=false
if [ -f "$SETTINGS" ]; then
  HOOKS_FILE=true
  HOOKS_CONFIGURED=$(json_key_truthy "$SETTINGS" hooks)
fi

# --- Surface 6: MCP ---
MCP_FILE=false
[ -f "$ROOT/.mcp.json" ] && MCP_FILE=true

# --- Surface 7: verify gate ---
# A verify gate is any declared way to run the test suite.
GATE_DETECTED=false
GATE_SOURCE=""
if [ -f "$ROOT/composer.json" ] && [ "$(has_scripts_test "$ROOT/composer.json")" = true ]; then
  GATE_DETECTED=true; GATE_SOURCE="composer.json scripts.test"
elif [ -f "$ROOT/package.json" ] && [ "$(has_scripts_test "$ROOT/package.json")" = true ]; then
  GATE_DETECTED=true; GATE_SOURCE="package.json scripts.test"
elif [ -f "$ROOT/Makefile" ] && grep -qE '^test:' "$ROOT/Makefile" 2>/dev/null; then
  GATE_DETECTED=true; GATE_SOURCE="Makefile test target"
elif [ -d "$ROOT/.github/workflows" ] && grep -rqlE 'run:.*(test|pest|phpunit|vitest|jest)' "$ROOT/.github/workflows" 2>/dev/null; then
  GATE_DETECTED=true; GATE_SOURCE="GitHub Actions workflow"
fi

GATE_SOURCE_JSON=$(json_str "$GATE_SOURCE")

cat <<JSON
{
  "claude_md": { "exists": $CM_EXISTS, "lines": $CM_LINES },
  "skills": $SKILLS,
  "agents": $AGENTS,
  "commands": $COMMANDS,
  "hooks": { "settings_file": $HOOKS_FILE, "configured": $HOOKS_CONFIGURED },
  "mcp": { "config_file": $MCP_FILE },
  "verify_gate": { "detected": $GATE_DETECTED, "source": $GATE_SOURCE_JSON }
}
JSON
