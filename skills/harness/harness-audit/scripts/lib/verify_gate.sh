#!/usr/bin/env bash
# verify_gate.sh — how does THIS repo run its tests?
#
# Sourceable library. Single definition, used by:
#   - harness-audit's inventory.sh (surface 7: verify_gate)
#   - the verification hook's record_activity.sh (is a Bash call a test run?)
#
# Two functions are exported:
#   detect_verify_gate <root>            -> prints detected=/source=/command= lines
#   is_test_command    <root> <cmdline>  -> exit 0 if cmdline runs this repo's tests
#
# FACTS ONLY. This library never judges whether having a gate is good.

_vg_has_scripts_test() {   # <manifest.json> -> prints true|false
  python3 - "$1" <<'PY' 2>/dev/null || printf 'false'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print("true" if isinstance(d.get("scripts"), dict) and "test" in d["scripts"] else "false")
except Exception:
    print("false")
PY
}

detect_verify_gate() {
  local root="$1" detected=false source="" command=""
  if [ -f "$root/composer.json" ] && [ "$(_vg_has_scripts_test "$root/composer.json")" = true ]; then
    detected=true; source="composer.json scripts.test"; command="composer test"
  elif [ -f "$root/package.json" ] && [ "$(_vg_has_scripts_test "$root/package.json")" = true ]; then
    detected=true; source="package.json scripts.test"; command="npm test"
  elif [ -f "$root/Makefile" ] && grep -qE '^test:' "$root/Makefile" 2>/dev/null; then
    detected=true; source="Makefile test target"; command="make test"
  elif [ -d "$root/.github/workflows" ] && \
       grep -rqlE 'run:.*(test|pest|phpunit|vitest|jest)' "$root/.github/workflows" 2>/dev/null; then
    # CI declares tests but gives us no reliable local command to match against.
    detected=true; source="GitHub Actions workflow"; command=""
  fi
  printf 'detected=%s\n' "$detected"
  printf 'source=%s\n'   "$source"
  printf 'command=%s\n'  "$command"
}

# _vg_strip_comments <cmdline> -> prints cmdline with shell comments removed.
#
# A `#` starts a comment when it begins a word (start of line, or preceded
# by whitespace). We do not track quote state, so a `#` inside a quoted
# string would incorrectly be treated as a comment start too — no test
# command in this repo's contract needs a literal `#` inside quotes, so
# this is a deliberate, documented simplification, not an oversight.
_vg_strip_comments() {
  printf '%s\n' "$1" | sed -E 's/(^|[[:space:]])#.*/\1/'
}

# _vg_segment_runs_tests <segment> <declared> -> exit 0 if this ONE segment,
# on its own, is an invocation of a test runner.
#
# A command only *runs* if it appears at the start of an execution segment
# (after `;`, `&&`, `||`, `|`, `&`, or a newline splits the command line).
# This function trims the segment down to what will actually be executed —
# leading whitespace, leading env-var assignments (`FOO=bar cmd`), and a
# single leading wrapper (`sudo`/`env`/`time`/`nice`/`npx`) — and then
# matches ONLY against what the segment now STARTS with. This is what
# rejects `cat tests/FooTest.php` (starts with `cat`, not a runner) and
# `printf 'composer test'` (starts with `printf`) by construction, instead
# of relying on a denylist of every possible non-runner command.
_vg_segment_runs_tests() {
  local seg="$1" declared="$2"

  seg="${seg#"${seg%%[![:space:]]*}"}"   # trim leading whitespace
  [ -z "$seg" ] && return 1

  # Skip leading environment-variable assignments: `FOO=bar BAZ=qux cmd`.
  while [[ "$seg" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+(.*)$ ]]; do
    seg="${BASH_REMATCH[1]}"
  done

  # Skip a single leading wrapper. `npx` is included alongside the POSIX
  # process wrappers because `npx <runner>` is a common, legitimate way to
  # invoke a JS test runner that isn't on PATH as a bare binary.
  case "$seg" in
    sudo\ *|env\ *|time\ *|nice\ *|npx\ *) seg="${seg#* }" ;;
  esac
  seg="${seg#"${seg%%[![:space:]]*}"}"   # trim again after the wrapper strip
  [ -z "$seg" ] && return 1

  # Belt-and-braces denylist. With the start-of-segment anchoring above,
  # none of these can produce a false accept any more (their first word is
  # never a test-runner name), so this is no longer load-bearing — it's a
  # defense-in-depth backstop in case the allowlist below is ever loosened.
  case "$seg" in
    cat\ *|ls\ *|echo\ *|grep\ *|find\ *|head\ *|tail\ *|less\ *|more\ *|git\ *|\
    rg\ *|wc\ *|sed\ *|awk\ *|stat\ *|file\ *|which\ *|type\ *|man\ *|tree\ *|diff\ *|\
    printf\ *|export\ *|alias\ *) return 1 ;;
  esac

  if [ -n "$declared" ]; then
    case "$seg" in
      "$declared"|"$declared "*) return 0 ;;
    esac
  fi

  # Conservative allowlist of real runner invocations, anchored to the
  # start of the (already-trimmed) segment — never matched as a substring
  # of the whole command line.
  printf '%s\n' "$seg" | grep -qE \
    '^(composer[[:space:]]+test|npm[[:space:]]+(run[[:space:]]+)?test|yarn[[:space:]]+test|pnpm[[:space:]]+test|make[[:space:]]+test|php[[:space:]]+artisan[[:space:]]+test|([[:alnum:]_./-]*/)?(pest|phpunit|vitest|jest|pytest))([[:space:]]|$)'
}

is_test_command() {
  local root="$1" cmd="$2" declared stripped segments seg matched=1

  declared=$(detect_verify_gate "$root" | grep '^command=' | cut -d= -f2-)
  stripped=$(_vg_strip_comments "$cmd")

  # Split on the shell's command separators so each segment can be checked
  # independently. This is also what fixes the multi-line false-reject: a
  # denylisted verb on line 1 no longer poisons a real test run on line 2,
  # because each line becomes its own segment.
  segments=$(printf '%s' "$stripped" | tr ';&|' '\n')

  while IFS= read -r seg; do
    if _vg_segment_runs_tests "$seg" "$declared"; then
      matched=0
      break
    fi
  done <<<"$segments"

  # KNOWN LIMITATION: `false && composer test` is still accepted. Segment
  # splitting sees `composer test` as a segment that starts with a runner
  # invocation and has no way to know the preceding `&&` short-circuited
  # it away at runtime — that requires evaluating the shell, which this
  # library deliberately does not do. This is a deliberate-sabotage shape
  # (an agent hand-crafting a command to defeat the gate), not a realistic
  # accidental shortcut, so it is accepted as a documented gap rather than
  # solved.
  return $matched
}
