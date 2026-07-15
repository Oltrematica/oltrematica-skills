#!/usr/bin/env bash
# record_activity.sh — PostToolUse recorder for the verification hook.
#
# Wired to two matchers: Bash (did the tests run?) and Write|Edit|NotebookEdit
# (was source changed?). Writes timestamps into the session state file.
#
# ALWAYS exits 0. A recorder must never block anything: if it cannot do its
# job the Stop hook fails open, which is the correct direction to fail.
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/state.sh
. "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || exit 0

GATE_LIB="${CLAUDE_PLUGIN_ROOT:-$SCRIPT_DIR/../..}/skills/harness/harness-audit/scripts/lib/verify_gate.sh"
# shellcheck source=/dev/null
. "$GATE_LIB" 2>/dev/null || exit 0

PAYLOAD=$(cat 2>/dev/null || true)
[ -n "$PAYLOAD" ] || exit 0

field() {  # field <dotted.path>
  # PAYLOAD is passed as argv, not piped on stdin: mixing a pipe with a
  # heredoc on the same command is a bash trap (confirmed empirically) — the
  # heredoc silently wins/mixes with the piped stdin depending on shell and
  # buffering, so the JSON never reliably reaches python. Passing it as
  # argv[2] sidesteps stdin redirection entirely.
  python3 - "$1" "$PAYLOAD" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.loads(sys.argv[2])
except Exception:
    sys.exit(0)
cur = d
for part in sys.argv[1].split("."):
    if not isinstance(cur, dict):
        sys.exit(0)
    cur = cur.get(part)
    if cur is None:
        sys.exit(0)
print(cur)
PY
}

SESSION=$(field session_id); [ -n "$SESSION" ] || exit 0
CWD=$(field cwd);           [ -n "$CWD" ]     || CWD="$PWD"
TOOL=$(field tool_name);    [ -n "$TOOL" ]    || exit 0
NOW=$(date +%s)

case "$TOOL" in
  Bash)
    CMD=$(field tool_input.command)
    [ -n "$CMD" ] || exit 0
    IS_TEST=0
    if is_test_command "$CWD" "$CMD"; then
      # Why "passed" and not merely "ran": Claude Code documents PostToolUse
      # as firing only after a tool call SUCCEEDS, with a separate
      # PostToolUseFailure event for failures. A Bash PostToolUse hook is
      # therefore never invoked when the underlying command exits non-zero
      # — confirmed empirically (tests/harness/notes.md, 2026-07-14
      # tool_response probe): `true` fires this hook, `false` does not, in
      # isolation, in both orderings, and with realistic failing-test-runner
      # stdout, six runs, zero exceptions. There is also no exit-code field
      # on tool_response to check even if we wanted one — its observed shape
      # is {stdout, stderr, interrupted, isImage, noOutputExpected}, none of
      # which encode success/failure. So: if this script is running at all
      # for a command that matches the test-runner pattern, that command
      # already exited zero — the tests passed. Do NOT "fix" this by adding
      # an exit-code check (there is none to add) and do NOT grep stdout for
      # strings like "FAILURES!" to infer pass/fail — a fragile heuristic
      # dressed up as evidence is exactly what this repo exists to prevent.
      state_set "$SESSION" last_test_pass "$NOW"
      state_set "$SESSION" test_evidence "passed"
      IS_TEST=1
    fi
    # FINDING 1 (adversarial review): a source edit made THROUGH Bash — `sed
    # -i`, `cat > file`, a heredoc, `tee`, `cp`, `mv`, `patch`, `dd`,
    # `install`, `truncate`, a `python3 -c` one-liner that writes — used to
    # be invisible here, because only Write|Edit|NotebookEdit ever set
    # last_source_edit. See lib/source_mutation.py for the detection and
    # docs/harness/verification-gate.md for the residual gap this does not
    # close (an exotic Bash mutation can still slip through a pure text
    # heuristic — documented there, not just here).
    if python3 "$SCRIPT_DIR/lib/source_mutation.py" "$CMD" "$IS_TEST" 2>/dev/null; then
      state_set "$SESSION" last_source_edit "$NOW"
    fi
    ;;
  Write|Edit|NotebookEdit)
    FP=$(field tool_input.file_path)
    [ -n "$FP" ] || exit 0
    case "$FP" in
      *.md|*/LICENSE|LICENSE) exit 0 ;;
      */docs/*|docs/*)        exit 0 ;;
    esac
    state_set "$SESSION" last_source_edit "$NOW"
    ;;
esac

exit 0
