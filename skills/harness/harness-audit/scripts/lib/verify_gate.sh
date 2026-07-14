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

is_test_command() {
  local root="$1" cmd="$2" declared

  # The command must INVOKE a test runner, not merely mention one.
  # `cat tests/FooTest.php` must never satisfy the verification gate.
  # This denylist rejects any command whose FIRST word is a reader/lister/
  # search tool, even when a test-runner name appears later in the string
  # (e.g. "grep -r test .", "rg -l test tests/", "cat tests/FooTest.php").
  case "$cmd" in
    cat\ *|ls\ *|echo\ *|grep\ *|find\ *|head\ *|tail\ *|less\ *|more\ *|git\ *|\
    rg\ *|wc\ *|sed\ *|awk\ *|stat\ *|file\ *|which\ *|type\ *|man\ *|tree\ *|diff\ *) return 1 ;;
  esac

  declared=$(detect_verify_gate "$root" | grep '^command=' | cut -d= -f2-)

  if [ -n "$declared" ] && [ "${cmd#*"$declared"}" != "$cmd" ]; then
    return 0
  fi

  # Conservative allowlist of real runner invocations.
  if printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])(composer +test|npm +(run +)?test|yarn +test|pnpm +test|make +test)([[:space:]]|$)'; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE '(^|[;&|/[:space:]])(pest|phpunit|vitest|jest|pytest)([[:space:]]|$)'; then
    return 0
  fi
  if printf '%s' "$cmd" | grep -qE 'artisan +test([[:space:]]|$)'; then
    return 0
  fi
  return 1
}
