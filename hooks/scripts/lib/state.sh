#!/usr/bin/env bash
# state.sh — per-session state shared by the verification hooks.
#
# Why a state file and not the transcript: Claude Code documents
# `transcript_path` as possibly lagging the current turn. A file we write
# ourselves is deterministic and cheap.
#
# Keys: last_test_pass (epoch), last_source_edit (epoch),
#       warned_no_gate (bool), test_evidence ("passed"|"ran")
#
# Empirical note (see tests/harness/notes.md, 2026-07-14 tool_response probe):
# a Bash PostToolUse hook is NOT invoked at all when the underlying command
# exits non-zero — there is no exit-code/success field on tool_response to
# read. record_activity.sh (Task 3) relies on hook-firing itself as the
# pass signal; this library only stores whatever value it is given.

_state_dir() {
  printf '%s' "${OLTREMATICA_STATE_DIR:-${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}/oltrematica-verify}"
}

state_path() {
  # Sanitise: a session id must never escape the state directory.
  local sid
  sid=$(printf '%s' "${1:-unknown}" | tr -c 'A-Za-z0-9._-' '_')
  local dir; dir="$(_state_dir)"
  mkdir -p "$dir" 2>/dev/null || true
  printf '%s/%s.json' "$dir" "$sid"
}

state_get() {
  local f; f="$(state_path "$1")"
  python3 - "$f" "$2" <<'PY' 2>/dev/null || printf '0'
import json, sys
path, key = sys.argv[1], sys.argv[2]
defaults = {"last_test_pass": 0, "last_source_edit": 0,
            "warned_no_gate": "false", "test_evidence": ""}
try:
    d = json.load(open(path))
    if not isinstance(d, dict):
        raise ValueError
except Exception:
    d = {}
v = d.get(key, defaults.get(key, ""))
if isinstance(v, bool):
    v = "true" if v else "false"
print(v)
PY
}

state_set() {
  local f; f="$(state_path "$1")"
  python3 - "$f" "$2" "$3" <<'PY' 2>/dev/null
import json, os, sys, tempfile
path, key, val = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    d = json.load(open(path))
    if not isinstance(d, dict):
        d = {}
except Exception:
    d = {}
if val in ("true", "false"):
    d[key] = (val == "true")
else:
    try:
        d[key] = int(val)
    except ValueError:
        d[key] = val
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
with os.fdopen(fd, "w") as fh:
    json.dump(d, fh)
os.replace(tmp, path)   # atomic on the same filesystem
PY
}
