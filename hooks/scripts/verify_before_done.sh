#!/usr/bin/env bash
# verify_before_done.sh — Stop hook.
#
# Blocks the agent from ending a turn claiming the work is done when the
# tests are STALE: a source file was modified after the last test run.
#
# Enforces the CLAUDE.md rule that is otherwise the most ignored:
#   "Never declare a task complete without proving it works."
#
# EXIT CODES — the only two this script may ever use:
#   2 -> BLOCK. stderr is fed back to the model as the reason.
#   0 -> allow.
# Exit 1 is NON-BLOCKING in Claude Code: it would fail open silently while
# appearing to work. It is never used here.
#
# Fails OPEN on everything it does not understand. A hook that blocks
# because it is broken gets uninstalled, and then enforces nothing forever.
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || exit 0
GATE_LIB="${CLAUDE_PLUGIN_ROOT:-$SCRIPT_DIR/../..}/skills/harness/harness-audit/scripts/lib/verify_gate.sh"
. "$GATE_LIB" 2>/dev/null || exit 0

PAYLOAD=$(cat 2>/dev/null || true)
[ -n "$PAYLOAD" ] || exit 0

field() {  # field <dotted.path>
  # PAYLOAD is passed as argv, not piped on stdin: mixing a pipe with a
  # heredoc on the same command is a bash trap — the heredoc consumes
  # stdin, so a piped payload never reliably reaches python. Passing it as
  # argv[2] sidesteps stdin redirection entirely. (Same pattern as
  # record_activity.sh's field() — reused deliberately, not reinvented.)
  python3 - "$1" "$PAYLOAD" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.loads(sys.argv[2])
except Exception:
    sys.exit(0)
v = d.get(sys.argv[1])
if v is None:
    sys.exit(0)
print(v)
PY
}

# --- loop guard: we are already looping, stand down ---
# stop_hook_active arrives as a JSON boolean (true/false); some paths render
# it as Python-ish "True" — handle both spellings.
case "$(field stop_hook_active)" in
  true|True) exit 0 ;;
esac

SESSION=$(field session_id); [ -n "$SESSION" ] || exit 0
CWD=$(field cwd);            [ -n "$CWD" ]     || CWD="$PWD"
MSG=$(field last_assistant_message)

LAST_EDIT=$(state_get "$SESSION" last_source_edit)
LAST_TEST=$(state_get "$SESSION" last_test_pass)
[ -n "$LAST_EDIT" ] || LAST_EDIT=0
[ -n "$LAST_TEST" ] || LAST_TEST=0

# --- state is not a well-formed number: cannot compare, do not enforce ---
case "$LAST_EDIT" in ''|*[!0-9]*) exit 0 ;; esac
case "$LAST_TEST" in ''|*[!0-9]*) exit 0 ;; esac

# --- no source touched this session: nothing to verify ---
[ "$LAST_EDIT" -eq 0 ] && exit 0

# --- no completion claim: a question or a partial report is a fine way to stop ---
printf '%s' "$MSG" | python3 "$SCRIPT_DIR/lib/claims.py" || exit 0

# --- tests are fresh: the claim is earned ---
[ "$LAST_TEST" -ge "$LAST_EDIT" ] && exit 0

# --- the repo declares no test command: we cannot enforce. Warn ONCE, allow. ---
TEST_CMD=$(detect_verify_gate "$CWD" 2>/dev/null | grep '^command=' | cut -d= -f2-)
if [ -z "$TEST_CMD" ]; then
  if [ "$(state_get "$SESSION" warned_no_gate)" != "true" ]; then
    state_set "$SESSION" warned_no_gate true
    echo "verify-before-done: this repo declares no test command, so completion claims cannot be checked. Run the 'harness-audit' skill to add a verify gate." >&2
  fi
  exit 0
fi

# --- BLOCK ---
cat >&2 <<EOF
Verification gate: you claimed this work is done, but the tests are stale.

A source file was modified after the last test run, so the last green result
does not describe the code you are about to hand over.

Run the test suite and report the actual output:

    $TEST_CMD

If it passes, say so and finish. If it fails, fix it. Do not restate that the
work is complete without running it.
EOF
exit 2
