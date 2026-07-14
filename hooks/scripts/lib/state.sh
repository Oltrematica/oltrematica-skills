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
# Documented note (see tests/harness/notes.md, 2026-07-14 tool_response probe):
# Claude Code documents `PostToolUse` as firing "after a tool call succeeds",
# with a separate `PostToolUseFailure` event for failures — a Bash
# PostToolUse hook is therefore not invoked when the underlying command
# exits non-zero. This is a documented contract, corroborated (not merely
# suggested) by an empirical probe. record_activity.sh (Task 3) relies on
# hook-firing itself as the pass signal; this library only stores whatever
# value it is given.

_state_dir() {
  printf '%s' "${OLTREMATICA_STATE_DIR:-${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}/oltrematica-verify}"
}

state_path() {
  # Sanitise: a session id must never escape the state directory.
  local sid
  sid=$(printf '%s' "${1:-unknown}" | tr -c 'A-Za-z0-9._-' '_')
  # Truncate: an unreasonably long session id (real Claude Code session ids
  # are UUIDs) could otherwise blow past filesystem filename limits
  # (ENAMETOOLONG) and make state_set silently persist nothing.
  sid="${sid:0:64}"
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
import fcntl, json, os, sys, tempfile, time

path, key, val = sys.argv[1], sys.argv[2], sys.argv[3]

def parse(v):
    if v in ("true", "false"):
        return v == "true"
    try:
        return int(v)
    except ValueError:
        return v

# Whole read-modify-write cycle happens under an exclusive lock on a
# sidecar lock file, so two concurrent state_set calls can never race on
# the same session's read-modify-write and silently drop one update.
#
# Fail open, always: bounded wait for the lock (a few seconds), and if it
# can't be acquired in time, give up quietly rather than hang a hook —
# a missed update is acceptable, a hung hook is not.
lock_fd = None
try:
    lock_fd = os.open(path + ".lock", os.O_CREAT | os.O_RDWR, 0o600)
except OSError:
    lock_fd = None  # can't create a lock file -> proceed unlocked, fail open

locked = False
if lock_fd is not None:
    deadline = time.monotonic() + 3.0
    while time.monotonic() < deadline:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            locked = True
            break
        except OSError:
            time.sleep(0.05)
    if not locked:
        os.close(lock_fd)
        sys.exit(0)  # fail open: give up quietly, do not write, do not hang

try:
    try:
        d = json.load(open(path))
        if not isinstance(d, dict):
            d = {}
    except Exception:
        d = {}
    d[key] = parse(val)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
    with os.fdopen(fd, "w") as fh:
        json.dump(d, fh)
    os.replace(tmp, path)   # atomic on the same filesystem
finally:
    if lock_fd is not None:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
        except OSError:
            pass
        os.close(lock_fd)
PY
}
