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
#
# ECOSYSTEM COVERAGE. This repo is distributed as a general-purpose skill, not
# a PHP/Node-only tool, so both functions must work for any mainstream stack:
# PHP (composer/pest/phpunit), JS/TS (npm/yarn/pnpm/vitest/jest), a bare
# Makefile, Python (pyproject.toml/tox.ini/setup.py/Pipfile — pytest/tox/nox/
# poetry/hatch/uv/unittest), Go (go.mod), Rust (Cargo.toml), Ruby (Gemfile/
# Rakefile — rspec/rake/minitest), Java/Kotlin (pom.xml/build.gradle[.kts]),
# .NET (*.csproj/*.sln), and Elixir (mix.exs).
#
# DETECTION PRECEDENCE (deliberate, not filesystem luck — many real repos are
# polyglot, e.g. a Python backend with a package.json only for a docs/lint
# toolchain, so which check wins first is a real, user-visible decision):
#
#   1. An explicitly DECLARED test script (composer.json scripts.test,
#      package.json scripts.test, a Makefile `test:` target). A declared
#      script is the project's own stated answer to "how do I run the
#      tests?" — nothing this library infers from a bare manifest's mere
#      *presence* should be allowed to outrank what the project itself wrote
#      down, so these are checked first regardless of language.
#   2. Failing that, single-purpose LANGUAGE ECOSYSTEM manifests, in a fixed
#      order: Python, Go, Rust, Ruby, Java/Kotlin, .NET, Elixir. Rationale
#      for the order: Python is checked first among the "no declared script"
#      tier because pyproject.toml/setup.py/tox.ini/Pipfile are the most
#      likely of this group to appear as a *secondary* file in a polyglot
#      repo (docs tooling, pre-commit, a small helper script) rather than as
#      the project's real test surface, so it is deliberately given first
#      refusal rather than being outranked by something checked later for no
#      documented reason. The remaining manifests (go.mod, Cargo.toml,
#      Gemfile/Rakefile, pom.xml/build.gradle*, *.csproj/*.sln, mix.exs) are
#      each essentially unique to their own ecosystem — a repo very rarely
#      carries two of them for unrelated reasons — so the exact order among
#      THEM matters far less than it being fixed; they are listed in roughly
#      decreasing general adoption. Whatever the order, only the FIRST match
#      wins: this library reports one gate, not a list.
#   3. Failing that, a GitHub Actions workflow that clearly runs tests (no
#      reliable local command to match against, so `command=` stays empty).
#
# None of this affects is_test_command's ACCEPT allowlist below, which is
# deliberately broader than what detect_verify_gate would ever report as
# `command=`: an agent might legitimately run `pytest -k foo` in a repo whose
# declared gate is `tox`, and that must still count as a real test run.

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

# _vg_detect_python <root> -> prints "source|command", or nothing if no
# Python test-gate manifest is present.
#
# pyproject.toml is checked for tool-specific sections so the reported
# `command=` matches how the project actually invokes its tests; a
# pyproject.toml with no recognised tool section still counts (pytest is the
# de-facto default), as do tox.ini/setup.py/Pipfile with no further
# introspection — is_test_command's allowlist below is what actually accepts
# real invocations, so an imprecise `command=` here never causes a rejection.
_vg_detect_python() {
  local root="$1" pp="$root/pyproject.toml"
  if [ -f "$pp" ]; then
    if grep -qE '^\[tool\.poetry(\.|\])' "$pp" 2>/dev/null; then
      printf '%s|%s' "pyproject.toml [tool.poetry]" "poetry run pytest"; return
    fi
    if grep -qE '^\[tool\.hatch' "$pp" 2>/dev/null; then
      printf '%s|%s' "pyproject.toml [tool.hatch]" "hatch test"; return
    fi
    printf '%s|%s' "pyproject.toml" "pytest"; return
  fi
  if [ -f "$root/tox.ini" ]; then
    printf '%s|%s' "tox.ini" "tox"; return
  fi
  if [ -f "$root/setup.py" ]; then
    printf '%s|%s' "setup.py" "pytest"; return
  fi
  if [ -f "$root/Pipfile" ]; then
    printf '%s|%s' "Pipfile" "pytest"; return
  fi
}

_vg_detect_go() {
  [ -f "$1/go.mod" ] && printf '%s|%s' "go.mod" "go test ./..."
}

_vg_detect_rust() {
  [ -f "$1/Cargo.toml" ] && printf '%s|%s' "Cargo.toml" "cargo test"
}

# _vg_detect_ruby <root> -> prints "source|command", or nothing.
# A Gemfile declaring the rspec gem outranks a bare Gemfile (rspec is the
# de-facto Ruby test-framework default); a Rakefile with no Gemfile falls
# back to `rake test`.
_vg_detect_ruby() {
  local root="$1"
  if [ -f "$root/Gemfile" ]; then
    if grep -qE "gem[[:space:]]+['\"]rspec" "$root/Gemfile" 2>/dev/null; then
      printf '%s|%s' "Gemfile (rspec)" "bundle exec rspec"; return
    fi
    printf '%s|%s' "Gemfile" "bundle exec rspec"; return
  fi
  if [ -f "$root/Rakefile" ]; then
    printf '%s|%s' "Rakefile" "rake test"; return
  fi
}

# _vg_detect_java <root> -> prints "source|command", or nothing. Maven wins
# over Gradle when both are present (pom.xml is the least ambiguous single
# signal); a Gradle wrapper script is preferred over a bare `gradle` since a
# checked-in wrapper is how most Gradle projects actually pin their build.
_vg_detect_java() {
  local root="$1"
  if [ -f "$root/pom.xml" ]; then
    printf '%s|%s' "pom.xml" "mvn test"; return
  fi
  if [ -f "$root/build.gradle.kts" ]; then
    if [ -x "$root/gradlew" ]; then
      printf '%s|%s' "build.gradle.kts" "./gradlew test"; return
    fi
    printf '%s|%s' "build.gradle.kts" "gradle test"; return
  fi
  if [ -f "$root/build.gradle" ]; then
    if [ -x "$root/gradlew" ]; then
      printf '%s|%s' "build.gradle" "./gradlew test"; return
    fi
    printf '%s|%s' "build.gradle" "gradle test"; return
  fi
}

# .NET has no single canonical manifest filename, so this looks for any
# *.csproj/*.sln up to two levels deep (root, and root/<project-dir>/file —
# the common single-project layout) rather than a full recursive scan, to
# stay cheap on large repos.
_vg_detect_dotnet() {
  local root="$1"
  if find "$root" -maxdepth 2 \( -name '*.csproj' -o -name '*.sln' \) 2>/dev/null | grep -q .; then
    printf '%s|%s' "*.csproj/*.sln" "dotnet test"
  fi
}

_vg_detect_elixir() {
  [ -f "$1/mix.exs" ] && printf '%s|%s' "mix.exs" "mix test"
}

detect_verify_gate() {
  local root="$1" detected=false source="" command="" pair=""

  if [ -f "$root/composer.json" ] && [ "$(_vg_has_scripts_test "$root/composer.json")" = true ]; then
    detected=true; source="composer.json scripts.test"; command="composer test"
  elif [ -f "$root/package.json" ] && [ "$(_vg_has_scripts_test "$root/package.json")" = true ]; then
    detected=true; source="package.json scripts.test"; command="npm test"
  elif [ -f "$root/Makefile" ] && grep -qE '^test:' "$root/Makefile" 2>/dev/null; then
    detected=true; source="Makefile test target"; command="make test"
  elif pair=$(_vg_detect_python "$root") && [ -n "$pair" ]; then
    detected=true; source="${pair%%|*}"; command="${pair#*|}"
  elif pair=$(_vg_detect_go "$root") && [ -n "$pair" ]; then
    detected=true; source="${pair%%|*}"; command="${pair#*|}"
  elif pair=$(_vg_detect_rust "$root") && [ -n "$pair" ]; then
    detected=true; source="${pair%%|*}"; command="${pair#*|}"
  elif pair=$(_vg_detect_ruby "$root") && [ -n "$pair" ]; then
    detected=true; source="${pair%%|*}"; command="${pair#*|}"
  elif pair=$(_vg_detect_java "$root") && [ -n "$pair" ]; then
    detected=true; source="${pair%%|*}"; command="${pair#*|}"
  elif pair=$(_vg_detect_dotnet "$root") && [ -n "$pair" ]; then
    detected=true; source="${pair%%|*}"; command="${pair#*|}"
  elif pair=$(_vg_detect_elixir "$root") && [ -n "$pair" ]; then
    detected=true; source="${pair%%|*}"; command="${pair#*|}"
  elif [ -d "$root/.github/workflows" ] && \
       grep -rqlE 'run:.*(test|pest|phpunit|vitest|jest|rspec)' "$root/.github/workflows" 2>/dev/null; then
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

# Runner allowlist, one pattern per ecosystem group, ORed together via
# multiple `grep -E -e` patterns rather than one giant alternation — kept
# as an array (not an associative array: this must run under macOS's stock
# bash 3.2) purely for readability/maintainability as the list grows.
# EVERY pattern here is anchored with `^...` and terminated with
# `([[:space:]]|$)` so it can only match at the START of an
# already-trimmed, already-comment-stripped execution segment — never as a
# substring anywhere else in the command line. This is what makes `cat
# tests/foo_test.go`, `echo go test`, `# cargo test` and `grep -r "go test"
# .` correctly rejected: none of them, after trimming, START with a runner
# name.
_VG_RUNNER_PATTERNS=(
  # PHP
  '^(composer[[:space:]]+test)([[:space:]]|$)'
  '^(php[[:space:]]+artisan[[:space:]]+test)([[:space:]]|$)'
  # JS/TS
  '^(npm[[:space:]]+(run[[:space:]]+)?test)([[:space:]]|$)'
  '^(yarn[[:space:]]+test)([[:space:]]|$)'
  '^(pnpm[[:space:]]+test)([[:space:]]|$)'
  # generic build tool
  '^(make[[:space:]]+test)([[:space:]]|$)'
  # bare test-runner binaries, optionally path-prefixed (./vendor/bin/pest,
  # ./node_modules/.bin/jest, etc.) — these are dedicated test runners, so
  # running the bare binary with no further args already runs the suite.
  '^([[:alnum:]_./-]*/)?(pest|phpunit|vitest|jest|pytest|rspec|minitest)([[:space:]]|$)'
  # Python
  '^(python3?[[:space:]]+-m[[:space:]]+(pytest|unittest))([[:space:]]|$)'
  '^(poetry[[:space:]]+run[[:space:]]+pytest)([[:space:]]|$)'
  '^(hatch[[:space:]]+test)([[:space:]]|$)'
  '^(uv[[:space:]]+run[[:space:]]+pytest)([[:space:]]|$)'
  '^(tox|nox)([[:space:]]|$)'
  # Go
  '^(go[[:space:]]+test)([[:space:]]|$)'
  # Rust
  '^(cargo[[:space:]]+(test|nextest[[:space:]]+run))([[:space:]]|$)'
  # Ruby
  '^(bundle[[:space:]]+exec[[:space:]]+(rspec|rake[[:space:]]+test))([[:space:]]|$)'
  '^(rake[[:space:]]+test)([[:space:]]|$)'
  # Java/Kotlin — `mvn`/`gradle` alone build/compile; the `test` goal/task is
  # required, so these do NOT belong in the bare-binary group above.
  '^(mvn[[:space:]]+test)([[:space:]]|$)'
  '^((\./)?gradlew|gradle)[[:space:]]+test([[:space:]]|$)'
  # .NET
  '^(dotnet[[:space:]]+test)([[:space:]]|$)'
  # Elixir
  '^(mix[[:space:]]+test)([[:space:]]|$)'
)

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
  local seg="$1" declared="$2" pat

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
  for pat in "${_VG_RUNNER_PATTERNS[@]}"; do
    printf '%s\n' "$seg" | grep -qE "$pat" && return 0
  done
  return 1
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
