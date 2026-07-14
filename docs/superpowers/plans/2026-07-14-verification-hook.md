# Verification Hook + Plugin Packaging — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An agent cannot end a turn claiming the work is done when the tests are stale relative to the code — enforced deterministically by a `Stop` hook, distributed as a Claude Code plugin.

**Architecture:** Three cooperating hooks and one session state file. Two `PostToolUse` hooks record timestamps (last passing test run; last source edit). One `Stop` hook blocks the turn when the final message claims completion **and** `last_source_edit > last_test_pass`. No transcript parsing — the platform documents `transcript_path` as lagging the current turn. Ships as a plugin so hooks merge automatically without editing `settings.json` in ~190 repos.

**Tech Stack:** `bash` (POSIX-leaning, macOS stock bash 3.2 compatible) and `python3` **stdlib only**. No new dependencies. Claude Code ≥ 2.1.207.

**Source spec:** [`docs/superpowers/specs/2026-07-14-verification-hook-design.md`](../specs/2026-07-14-verification-hook-design.md)

## Global Constraints

Every task's requirements implicitly include this section.

- **One hook, one rule.** Secrets scanning, dependency blocking, main-branch protection, auto-formatting and cost coaching were **explicitly cut** (spec §3). Do NOT add them. Not as a "small extra", not as a "while we're here".
- **Exit 2 blocks. Exit 1 does NOT.** Claude Code treats exit 1 as a *non-blocking* error: the action proceeds and the hook silently fails open while appearing to work. Every block path exits **2**, and a test asserts it.
- **Fail open, loudly.** Any condition the hook does not understand — unreadable state, undetectable test command, malformed stdin, an internal error — **allows the turn to end** and explains why on stderr. A hook that blocks because *it* is broken gets uninstalled within a day, and then enforces nothing forever.
- **Never invent a Claude Code mechanic.** Every event name, stdin field and exit-code behaviour must be verified against the real product before being relied upon. If a field's shape is uncertain, determine it EMPIRICALLY (see Task 2) — do not guess.
- **Portability:** bash or python3 **stdlib only**. macOS stock `/bin/bash` is 3.2.57 — no associative arrays, no `mapfile`/`readarray`.
- **Shared code lives inside the skill directory.** `scripts/install.sh` copies only `skills/<track>/<name>/`, so a helper referenced as `../../lib/…` would break every non-plugin install. Shared helpers go under `skills/harness/harness-audit/scripts/lib/`.
- **Evidence, never assertion.** Nothing is self-marked Validated/Passing. Test results are reported with their actual output.
- **English throughout.** Commit convention: `type(scope): short description`, imperative, subject ≤ 72 chars.

## File Structure

```
.claude-plugin/marketplace.json                          # NEW — the marketplace (Task 6)
plugin.json                                              # NEW — the plugin (Task 6)
hooks/
├── hooks.json                                           # NEW — hook wiring (Task 6)
└── scripts/
    ├── record_activity.sh                               # NEW — PostToolUse recorder (Task 3)
    ├── verify_before_done.sh                            # NEW — the Stop hook (Task 5)
    └── lib/
        ├── state.sh                                     # NEW — session state I/O (Task 2)
        └── claims.py                                    # NEW — claim detector (Task 4)
skills/harness/harness-audit/scripts/
├── inventory.sh                                         # MODIFIED — sources the shared lib (Task 1)
└── lib/verify_gate.sh                                   # NEW — shared gate detection (Task 1)
tests/harness/
├── verify_gate.sh.test                                  # NEW (Task 1)
├── state.sh.test                                        # NEW (Task 2)
├── record_activity.sh.test                              # NEW (Task 3)
├── claims.py.test                                       # NEW (Task 4)
├── verify_before_done.sh.test                           # NEW (Task 5)
├── claim_corpus.json                                    # NEW — quorum corpus (Task 7)
└── fixtures/stale-tests/                                # NEW — the must-block fixture (Task 5)
```

---

### Task 1: Shared verify-gate detection, extended with the test command

`inventory.sh` already detects *whether* a verify gate exists. The hook needs to know *what command counts as a test run*, so it can recognise one when it sees a `Bash` call. Extract the detection into a shared library and extend it — one definition of "how this repo runs its tests", not two that drift.

**Files:**
- Create: `skills/harness/harness-audit/scripts/lib/verify_gate.sh`
- Create: `tests/harness/verify_gate.sh.test`
- Modify: `skills/harness/harness-audit/scripts/inventory.sh` (replace the inline Surface-7 block, ~lines 171–185, with a call into the lib)

**Interfaces:**
- Produces: `detect_verify_gate <repo-root>` — a sourceable bash function printing three lines to stdout:
  ```
  detected=true|false
  source=<human string, e.g. "composer.json scripts.test">
  command=<the command to run, e.g. "composer test">   # empty when detected=false
  ```
- Produces: `is_test_command <repo-root> <command-string>` — exit **0** if the command string is a test invocation for this repo, exit **1** otherwise.
- Consumed by: `inventory.sh` (Task 1) and `record_activity.sh` (Task 3).
- **Contract that must not break:** `inventory.sh` must still emit exactly the same 8 JSON keys with the same values. Its 35 existing checks must stay green.

- [ ] **Step 1: Write the failing test**

Create `tests/harness/verify_gate.sh.test`:

```bash
#!/usr/bin/env bash
# Contract test for lib/verify_gate.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/skills/harness/harness-audit/scripts/lib/verify_gate.sh"
PASS=0; FAIL=0
check(){ if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1));
         else echo "  FAIL: $1 (expected '$2', got '$3')"; FAIL=$((FAIL+1)); fi; }

# shellcheck source=/dev/null
. "$LIB" 2>/dev/null || { echo "  FAIL: cannot source $LIB"; echo "PASS=0 FAIL=1"; exit 1; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT

field(){ detect_verify_gate "$1" | grep "^$2=" | cut -d= -f2-; }

echo "1. composer.json with scripts.test"
mkdir -p "$T/php"
printf '{"scripts":{"test":"pest"}}' > "$T/php/composer.json"
check "detected"  "true"                        "$(field "$T/php" detected)"
check "source"    "composer.json scripts.test"  "$(field "$T/php" source)"
check "command"   "composer test"               "$(field "$T/php" command)"

echo "2. package.json with scripts.test"
mkdir -p "$T/node"
printf '{"scripts":{"test":"vitest run"}}' > "$T/node/package.json"
check "detected" "true"           "$(field "$T/node" detected)"
check "command"  "npm test"       "$(field "$T/node" command)"

echo "3. Makefile test target"
mkdir -p "$T/mk"; printf 'test:\n\techo hi\n' > "$T/mk/Makefile"
check "detected" "true"        "$(field "$T/mk" detected)"
check "command"  "make test"   "$(field "$T/mk" command)"

echo "4. no gate at all"
mkdir -p "$T/none"
check "detected" "false" "$(field "$T/none" detected)"
check "command"  ""      "$(field "$T/none" command)"

echo "5. is_test_command recognises the declared command"
is_test_command "$T/php" "composer test"; check "declared cmd" "0" "$?"

echo "6. is_test_command recognises common equivalents in a PHP repo"
is_test_command "$T/php" "php artisan test";             check "artisan test" "0" "$?"
is_test_command "$T/php" "./vendor/bin/pest --filter=x"; check "pest"         "0" "$?"
is_test_command "$T/php" "vendor/bin/phpunit";           check "phpunit"      "0" "$?"

echo "7. is_test_command recognises node equivalents"
is_test_command "$T/node" "npm test";       check "npm test" "0" "$?"
is_test_command "$T/node" "npx vitest run"; check "vitest"   "0" "$?"

echo "8. is_test_command REJECTS non-test commands (false positives are the danger)"
is_test_command "$T/php" "git status";              check "git status"  "1" "$?"
is_test_command "$T/php" "ls tests/";               check "ls tests/"   "1" "$?"
is_test_command "$T/php" "cat tests/FooTest.php";   check "cat a test"  "1" "$?"
is_test_command "$T/php" "echo 'run the tests'";    check "echo"        "1" "$?"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

Note test 8: a command that merely *mentions* tests must not count as running them. `cat tests/FooTest.php` satisfying the verification gate would be a hole straight through the middle of this feature.

- [ ] **Step 2: Run it to confirm it fails (RED)**

```bash
bash tests/harness/verify_gate.sh.test
```
Expected: `FAIL: cannot source …/lib/verify_gate.sh`, `PASS=0 FAIL=1`, non-zero exit.

- [ ] **Step 3: Write the library**

Create `skills/harness/harness-audit/scripts/lib/verify_gate.sh`:

```bash
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
  declared=$(detect_verify_gate "$root" | grep '^command=' | cut -d= -f2-)

  # The command must INVOKE a test runner, not merely mention one.
  # `cat tests/FooTest.php` must never satisfy the verification gate.
  case "$cmd" in
    cat\ *|ls\ *|echo\ *|grep\ *|find\ *|head\ *|tail\ *|less\ *|git\ *) return 1 ;;
  esac

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
```

- [ ] **Step 4: Run the test to verify it passes (GREEN)**

```bash
bash tests/harness/verify_gate.sh.test
```
Expected: `PASS=17 FAIL=0`.

- [ ] **Step 5: Rewire inventory.sh to the shared lib, and prove its output is unchanged**

Capture the current output first, so the refactor is provably behaviour-preserving:

```bash
bash skills/harness/harness-audit/scripts/inventory.sh . > /tmp/inv-before.json
bash skills/harness/harness-audit/scripts/inventory.sh tests/harness/fixtures/bad-harness > /tmp/inv-bad-before.json
```

In `inventory.sh`, source the lib near the top (after `SCRIPT_DIR` is established):

```bash
# shellcheck source=lib/verify_gate.sh
. "$SCRIPT_DIR/lib/verify_gate.sh"
```

Replace the inline Surface-7 block with:

```bash
# --- Surface 7: verify gate (shared with the verification hook) ---
GATE_DETECTED=$(detect_verify_gate "$ROOT" | grep '^detected=' | cut -d= -f2-)
GATE_SOURCE=$(detect_verify_gate "$ROOT"   | grep '^source='   | cut -d= -f2-)
GATE_SOURCE_JSON=$(json_str "$GATE_SOURCE")
```

If `inventory.sh` has no `SCRIPT_DIR`, add it — this is the same self-relative idiom the other skill scripts use, and it is what lets the script survive being copied into a target repo:

```bash
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
```

Then prove nothing changed:

```bash
bash skills/harness/harness-audit/scripts/inventory.sh . > /tmp/inv-after.json
bash skills/harness/harness-audit/scripts/inventory.sh tests/harness/fixtures/bad-harness > /tmp/inv-bad-after.json
diff /tmp/inv-before.json /tmp/inv-after.json && echo "IDENTICAL (this repo)"
diff /tmp/inv-bad-before.json /tmp/inv-bad-after.json && echo "IDENTICAL (bad-harness)"
bash tests/harness/inventory.sh.test | tail -1
```
Expected: both `IDENTICAL`, and `PASS=35 FAIL=0`.

- [ ] **Step 6: Commit**

```bash
git add skills/harness/harness-audit/scripts tests/harness/verify_gate.sh.test
git commit -m "refactor(harness-audit): extract shared verify-gate detection

The verification hook needs to recognise a test invocation; inventory.sh
already knows how this repo runs its tests. One definition, not two."
```

---

### Task 2: Session state, and the empirical check on `tool_response`

The hooks communicate through a small per-session JSON file. **This task also settles the one thing the docs cannot tell us: whether a `PostToolUse` hook can see a Bash command's exit status.** The spec says we record a *passing* test run — if the platform does not expose success/failure, we must degrade to "ran" and say so loudly rather than silently claiming something stronger.

**Files:**
- Create: `hooks/scripts/lib/state.sh`
- Create: `tests/harness/state.sh.test`

**Interfaces:**
- Produces: `state_path <session_id>` → absolute path to the state file.
- Produces: `state_get <session_id> <key>` → value, or `0` for missing numeric keys, `false` for missing booleans, empty otherwise.
- Produces: `state_set <session_id> <key> <value>` → merges the key into the JSON, creating the file if needed. Concurrency-safe enough for our purpose (write to temp, `mv` into place — `mv` on the same filesystem is atomic).
- State keys: `last_test_pass` (epoch int), `last_source_edit` (epoch int), `warned_no_gate` (bool), `test_evidence` (`"passed"` or `"ran"` — see Step 1).
- Consumed by: `record_activity.sh` (Task 3), `verify_before_done.sh` (Task 5).

- [ ] **Step 1: Determine the real shape of `tool_response` — empirically, not from memory**

Do this FIRST; the rest of the design depends on the answer.

Write a temporary probe hook that dumps its stdin, wire it up in **your own** `~/.claude/settings.json` (not the repo's), run one passing and one failing Bash command in a scratch Claude Code session, and read what actually arrives:

```bash
mkdir -p /tmp/hookprobe
cat > /tmp/hookprobe/dump.sh <<'EOF'
#!/usr/bin/env bash
cat >> /tmp/hookprobe/captured.jsonl
exit 0
EOF
chmod +x /tmp/hookprobe/dump.sh
```

Add to `~/.claude/settings.json` (remove it again afterwards):

```json
{ "hooks": { "PostToolUse": [ { "matcher": "Bash",
  "hooks": [ { "type": "command", "command": "/tmp/hookprobe/dump.sh" } ] } ] } }
```

In a scratch Claude Code session run a command that succeeds (`true`) and one that fails (`false` or a deliberately failing test). Then:

```bash
python3 -m json.tool < /tmp/hookprobe/captured.jsonl 2>/dev/null | head -40
python3 -c "
import json
for line in open('/tmp/hookprobe/captured.jsonl'):
    d = json.loads(line)
    print(d.get('tool_name'), '->', json.dumps(d.get('tool_response'))[:300])
"
```

**Record the answer in `tests/harness/notes.md`** with the real captured output. Then choose:

- **If exit status IS available** (e.g. an exit-code or success field on `tool_response`): record `test_evidence="passed"` only when the command succeeded. This is the design in the spec.
- **If it is NOT available**: record `test_evidence="ran"`, and **say so loudly** — in `tests/harness/notes.md`, in the hook's block message, and in the rollout note. The hook then enforces "you ran the suite", not "the suite was green", and we do not pretend otherwise. Do NOT infer pass/fail by grepping stdout for strings like `FAILURES!` — a fragile heuristic dressed up as evidence is exactly what this repo exists to prevent.

Clean up the probe hook from `~/.claude/settings.json` before continuing.

- [ ] **Step 2: Write the failing test**

Create `tests/harness/state.sh.test`:

```bash
#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$ROOT/hooks/scripts/lib/state.sh"
PASS=0; FAIL=0
check(){ if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1));
         else echo "  FAIL: $1 (expected '$2', got '$3')"; FAIL=$((FAIL+1)); fi; }

export OLTREMATICA_STATE_DIR=$(mktemp -d)
trap 'rm -rf "$OLTREMATICA_STATE_DIR"' EXIT

# shellcheck source=/dev/null
. "$LIB" 2>/dev/null || { echo "  FAIL: cannot source $LIB"; echo "PASS=0 FAIL=1"; exit 1; }

S=sess-abc123

echo "1. missing keys have safe defaults"
check "last_test_pass"   "0"     "$(state_get $S last_test_pass)"
check "last_source_edit" "0"     "$(state_get $S last_source_edit)"
check "warned_no_gate"   "false" "$(state_get $S warned_no_gate)"

echo "2. set then get"
state_set $S last_test_pass 1000
check "reads back" "1000" "$(state_get $S last_test_pass)"

echo "3. set a second key without clobbering the first"
state_set $S last_source_edit 2000
check "first key survives"  "1000" "$(state_get $S last_test_pass)"
check "second key set"      "2000" "$(state_get $S last_source_edit)"

echo "4. state file is valid JSON"
check "valid json" "yes" \
  "$(python3 -m json.tool < "$(state_path $S)" >/dev/null 2>&1 && echo yes || echo no)"

echo "5. sessions are isolated"
state_set other-session last_test_pass 9999
check "no bleed" "1000" "$(state_get $S last_test_pass)"

echo "6. a corrupt state file does not crash — it reads as defaults (FAIL OPEN)"
printf 'not json{{{' > "$(state_path $S)"
check "corrupt -> default" "0" "$(state_get $S last_test_pass)"

echo "7. session ids are sanitised (no path traversal into the filesystem)"
p="$(state_path '../../etc/passwd')"
check "no traversal" "yes" \
  "$(case "$p" in "$OLTREMATICA_STATE_DIR"/*) echo yes;; *) echo no;; esac)"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 3: Run it to confirm it fails (RED)**

```bash
bash tests/harness/state.sh.test
```
Expected: `FAIL: cannot source …/state.sh`, `PASS=0 FAIL=1`.

- [ ] **Step 4: Write the state library**

Create `hooks/scripts/lib/state.sh`:

```bash
#!/usr/bin/env bash
# state.sh — per-session state shared by the verification hooks.
#
# Why a state file and not the transcript: Claude Code documents
# `transcript_path` as possibly lagging the current turn. A file we write
# ourselves is deterministic and cheap.
#
# Keys: last_test_pass (epoch), last_source_edit (epoch),
#       warned_no_gate (bool), test_evidence ("passed"|"ran")

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
```

- [ ] **Step 5: Run the test (GREEN)**

```bash
bash tests/harness/state.sh.test
```
Expected: `PASS=9 FAIL=0`.

- [ ] **Step 6: Commit**

```bash
git add hooks/scripts/lib/state.sh tests/harness/state.sh.test tests/harness/notes.md
git commit -m "feat(hooks): add per-session state for the verification hook

Records the tool_response probe result: whether a PostToolUse hook can
observe a Bash command's exit status, determined empirically."
```

---

### Task 3: `record_activity.sh` — the two PostToolUse recorders

**Files:**
- Create: `hooks/scripts/record_activity.sh`
- Create: `tests/harness/record_activity.sh.test`

**Interfaces:**
- Consumes: `state.sh` (Task 2), `verify_gate.sh` (Task 1).
- Produces: a script reading a `PostToolUse` payload on **stdin** and updating state. Always exits **0** — a recorder must never block anything.
- Source-file rule (spec §4): a file is source unless it is `*.md`, `LICENSE`, or under a `docs/` directory. **Test files count as source** — editing a test after the suite went green makes the green stale, which is exactly the rule.

- [ ] **Step 1: Write the failing test**

Create `tests/harness/record_activity.sh.test`:

```bash
#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REC="$ROOT/hooks/scripts/record_activity.sh"
PASS=0; FAIL=0
check(){ if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1));
         else echo "  FAIL: $1 (expected '$2', got '$3')"; FAIL=$((FAIL+1)); fi; }

export OLTREMATICA_STATE_DIR=$(mktemp -d)
REPO=$(mktemp -d)
trap 'rm -rf "$OLTREMATICA_STATE_DIR" "$REPO"' EXIT
printf '{"scripts":{"test":"pest"}}' > "$REPO/composer.json"
# shellcheck source=/dev/null
. "$ROOT/hooks/scripts/lib/state.sh"

S=rec-1
feed(){ printf '%s' "$1" | bash "$REC" >/dev/null 2>&1; echo $?; }

echo "1. a test command records last_test_pass"
rc=$(feed "{\"session_id\":\"$S\",\"cwd\":\"$REPO\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"composer test\"},\"tool_response\":{}}")
check "exit 0 (recorders never block)" "0" "$rc"
check "last_test_pass set" "yes" \
  "$([ "$(state_get $S last_test_pass)" -gt 0 ] && echo yes || echo no)"

echo "2. a NON-test command records nothing"
S2=rec-2
feed "{\"session_id\":\"$S2\",\"cwd\":\"$REPO\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git status\"},\"tool_response\":{}}" >/dev/null
check "last_test_pass untouched" "0" "$(state_get $S2 last_test_pass)"

echo "3. reading a test file is NOT running tests"
S3=rec-3
feed "{\"session_id\":\"$S3\",\"cwd\":\"$REPO\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cat tests/FooTest.php\"},\"tool_response\":{}}" >/dev/null
check "last_test_pass untouched" "0" "$(state_get $S3 last_test_pass)"

echo "4. editing a source file records last_source_edit"
S4=rec-4
feed "{\"session_id\":\"$S4\",\"cwd\":\"$REPO\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$REPO/app/Foo.php\"},\"tool_response\":{}}" >/dev/null
check "last_source_edit set" "yes" \
  "$([ "$(state_get $S4 last_source_edit)" -gt 0 ] && echo yes || echo no)"

echo "5. editing a TEST file counts as source (a green suite is now stale)"
S5=rec-5
feed "{\"session_id\":\"$S5\",\"cwd\":\"$REPO\",\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$REPO/tests/FooTest.php\"},\"tool_response\":{}}" >/dev/null
check "last_source_edit set" "yes" \
  "$([ "$(state_get $S5 last_source_edit)" -gt 0 ] && echo yes || echo no)"

echo "6. editing a .md file does NOT count as source"
S6=rec-6
feed "{\"session_id\":\"$S6\",\"cwd\":\"$REPO\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$REPO/README.md\"},\"tool_response\":{}}" >/dev/null
check "last_source_edit untouched" "0" "$(state_get $S6 last_source_edit)"

echo "7. malformed stdin does not crash and never blocks"
rc=$(printf 'not json{{{' | bash "$REC" >/dev/null 2>&1; echo $?)
check "exit 0 on garbage" "0" "$rc"
rc=$(printf '' | bash "$REC" >/dev/null 2>&1; echo $?)
check "exit 0 on empty" "0" "$rc"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run it to confirm it fails (RED)**

```bash
bash tests/harness/record_activity.sh.test
```
Expected: every check fails (`No such file or directory`).

- [ ] **Step 3: Write the recorder**

Create `hooks/scripts/record_activity.sh`:

```bash
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
  printf '%s' "$PAYLOAD" | python3 - "$1" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(sys.stdin)
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
    if is_test_command "$CWD" "$CMD"; then
      # Task 2 Step 1 determines empirically whether exit status is observable.
      # If it is, gate this on success and set test_evidence=passed.
      # If it is not, record test_evidence=ran and say so loudly in the docs.
      state_set "$SESSION" last_test_pass "$NOW"
      state_set "$SESSION" test_evidence "ran"
    fi
    ;;
  Write|Edit|NotebookEdit)
    FP=$(field tool_input.file_path)
    [ -n "$FP" ] || exit 0
    case "$FP" in
      *.md|*/LICENSE|LICENSE) exit 0 ;;
      */docs/*)               exit 0 ;;
    esac
    state_set "$SESSION" last_source_edit "$NOW"
    ;;
esac

exit 0
```

**If Task 2 Step 1 found exit status IS observable**, replace the `state_set … test_evidence "ran"` line with a success check on the field you discovered, and set `test_evidence` to `passed`. Record which you did, and why, in `tests/harness/notes.md`.

```bash
chmod +x hooks/scripts/record_activity.sh
```

- [ ] **Step 4: Run the test (GREEN)**

```bash
bash tests/harness/record_activity.sh.test
```
Expected: `PASS=10 FAIL=0`.

- [ ] **Step 5: Commit**

```bash
git add hooks/scripts/record_activity.sh tests/harness/record_activity.sh.test
git commit -m "feat(hooks): record test runs and source edits per session

Reading a test file is not running it; editing a test file makes a green
suite stale. Both are asserted."
```

---

### Task 4: The claim detector

Whether a message claims completion is a judgement, not a fact — so it is isolated into one small, independently testable unit, and Task 7 puts it in front of a blind quorum.

**Files:**
- Create: `hooks/scripts/lib/claims.py`
- Create: `tests/harness/claims.py.test`

**Interfaces:**
- Produces: `claims.py` — reads the message text on **stdin**, exits **0** if it claims completion, **1** if it does not. Never a traceback; never any other exit code.
- Consumed by: `verify_before_done.sh` (Task 5), and the quorum in Task 7.

- [ ] **Step 1: Write the failing test**

Create `tests/harness/claims.py.test`:

```bash
#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
C="$ROOT/hooks/scripts/lib/claims.py"
PASS=0; FAIL=0
claims(){ printf '%s' "$1" | python3 "$C" >/dev/null 2>&1; echo $?; }
yes_(){ if [ "$(claims "$1")" = "0" ]; then echo "  PASS: claims  | $1"; PASS=$((PASS+1));
        else echo "  FAIL: should claim | $1"; FAIL=$((FAIL+1)); fi; }
no_() { if [ "$(claims "$1")" = "1" ]; then echo "  PASS: doesn't | $1"; PASS=$((PASS+1));
        else echo "  FAIL: false positive | $1"; FAIL=$((FAIL+1)); fi; }

echo "-- claims completion --"
yes_ "Done — the migration now has a working down()."
yes_ "Fixed. The invoice test passes."
yes_ "All tests pass."
yes_ "Implemented the retry logic and everything is green."
yes_ "That's complete — ready for review."

echo "-- does NOT claim completion (false positives block real work) --"
no_ "Done reading the file — here is what I found."
no_ "I'm going to fix the failing test now."
no_ "The tests should pass once we wire up the config."
no_ "Should I run the test suite before continuing?"
no_ "Here are three options; which do you want?"
no_ "I've read through the controller but haven't changed anything yet."

echo "-- degenerate input --"
rc=$(printf '' | python3 "$C" >/dev/null 2>&1; echo $?)
if [ "$rc" = "1" ]; then echo "  PASS: empty input = no claim"; PASS=$((PASS+1));
else echo "  FAIL: empty input exit=$rc"; FAIL=$((FAIL+1)); fi

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run it to confirm it fails (RED)**

```bash
bash tests/harness/claims.py.test
```
Expected: `can't open file …claims.py`; all checks fail.

- [ ] **Step 3: Write the detector**

Create `hooks/scripts/lib/claims.py`:

```python
#!/usr/bin/env python3
"""claims.py — does this message CLAIM the work is complete?

Reads the message on stdin. Exit 0 = claims completion. Exit 1 = does not.

This is the soft joint of the verification hook, and it is deliberately
isolated here so it can be tested on its own and put in front of a blind
quorum (see tests/harness/claim_corpus.json).

Two asymmetric failure modes:
  - a MISS (a real claim not detected) leaves the hook silent — a hole.
  - a FALSE POSITIVE blocks legitimate work, and is how the whole pack
    gets uninstalled. Prefer a miss over a false positive.

Python stdlib only.
"""
import re
import sys

# Assertions that the work is finished. Present tense / past tense, not future,
# not interrogative, not hypothetical.
CLAIM = re.compile(
    r"""(?ix)
    (?:^|[.\n!]\s*|^\s*)          # start of a sentence
    (?:
        done\b(?!\s+(?:reading|reviewing|looking|checking|analysing|analyzing))
      | fixed\b
      | (?:that'?s|it'?s|this\s+is|work\s+is)\s+(?:done|complete|finished)
      | complete(?:d)?\b
      | finished\b
      | implemented\b
      | all\s+(?:the\s+)?tests?\s+pass
      | tests?\s+(?:now\s+)?pass(?:ing)?\b
      | everything\s+is\s+green
      | ready\s+(?:for\s+review|to\s+(?:merge|ship))
    )
    """,
)

# Things that look like claims but are not: predictions, questions, intentions.
NOT_A_CLAIM = re.compile(
    r"""(?ix)
    (?:
        \bshould\s+(?:pass|work|be)\b     # a prediction, not a result
      | \bi'?ll\b | \bi\s+will\b | \bgoing\s+to\b | \bnext\s+i\b
      | \?\s*$                            # a question
    )
    """,
)


def claims_completion(text: str) -> bool:
    if not text or not text.strip():
        return False
    if NOT_A_CLAIM.search(text):
        return False
    return bool(CLAIM.search(text))


def main() -> None:
    try:
        text = sys.stdin.read()
    except Exception:
        sys.exit(1)          # unreadable input is not a claim — fail open
    sys.exit(0 if claims_completion(text) else 1)


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run the test (GREEN)**

```bash
bash tests/harness/claims.py.test
```
Expected: `PASS=12 FAIL=0`.

If a row fails, fix the **pattern**, not the test. Do not delete a failing sample to make the suite green — that is the precise move this repository exists to prevent, and Task 7 will catch it anyway.

- [ ] **Step 5: Commit**

```bash
git add hooks/scripts/lib/claims.py tests/harness/claims.py.test
git commit -m "feat(hooks): add the completion-claim detector

Isolated so it can be quorum-tested. A false positive blocks real work and
is how the pack gets uninstalled; prefer a miss."
```

---

### Task 5: `verify_before_done.sh` — the Stop hook, and the fixture it must catch

**Files:**
- Create: `hooks/scripts/verify_before_done.sh`
- Create: `tests/harness/verify_before_done.sh.test`
- Create: `tests/harness/fixtures/stale-tests/composer.json`
- Create: `tests/harness/fixtures/stale-tests/README.md`

**Interfaces:**
- Consumes: `state.sh` (Task 2), `verify_gate.sh` (Task 1), `claims.py` (Task 4).
- Produces: a script reading a `Stop` payload on **stdin**.
  - Exit **2** = BLOCK (stderr is fed to the model as the reason).
  - Exit **0** = allow.
  - **No other exit code is ever used.** Exit 1 is non-blocking in Claude Code and would fail open silently while looking like it works.

- [ ] **Step 1: Write the failing test**

Create `tests/harness/verify_before_done.sh.test`:

```bash
#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
H="$ROOT/hooks/scripts/verify_before_done.sh"
PASS=0; FAIL=0
check(){ if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1));
         else echo "  FAIL: $1 (expected '$2', got '$3')"; FAIL=$((FAIL+1)); fi; }

export OLTREMATICA_STATE_DIR=$(mktemp -d)
REPO=$(mktemp -d)
trap 'rm -rf "$OLTREMATICA_STATE_DIR" "$REPO"' EXIT
printf '{"scripts":{"test":"pest"}}' > "$REPO/composer.json"
# shellcheck source=/dev/null
. "$ROOT/hooks/scripts/lib/state.sh"

stop(){ # stop <session> <message> <stop_hook_active>
  printf '{"session_id":"%s","cwd":"%s","hook_event_name":"Stop","stop_hook_active":%s,"last_assistant_message":"%s"}' \
    "$1" "$REPO" "${3:-false}" "$2" | bash "$H" 2>/dev/null; echo $?
}

echo "1. THE CASE THAT MATTERS: claim + source edited after the tests passed -> BLOCK"
S=v1; state_set $S last_test_pass 1000; state_set $S last_source_edit 2000
check "exit 2 (blocks)" "2" "$(stop $S 'Done. Fixed the bug.')"

echo "2. exit code is 2, never 1 (exit 1 is NON-blocking in Claude Code)"
S=v2; state_set $S last_test_pass 1000; state_set $S last_source_edit 2000
rc=$(stop $S 'Done.')
check "not exit 1" "yes" "$([ "$rc" != "1" ] && echo yes || echo no)"

echo "3. the block message tells the agent how to satisfy it"
S=v3; state_set $S last_test_pass 1000; state_set $S last_source_edit 2000
msg=$(printf '{"session_id":"%s","cwd":"%s","stop_hook_active":false,"last_assistant_message":"Done."}' "$S" "$REPO" | bash "$H" 2>&1 >/dev/null)
check "names the test command" "yes" \
  "$(printf '%s' "$msg" | grep -qi "composer test" && echo yes || echo no)"

echo "4. tests ran AFTER the edit -> allow"
S=v4; state_set $S last_source_edit 1000; state_set $S last_test_pass 2000
check "exit 0" "0" "$(stop $S 'Done. Fixed the bug.')"

echo "5. no completion claim -> allow (even with stale tests)"
S=v5; state_set $S last_test_pass 1000; state_set $S last_source_edit 2000
check "exit 0" "0" "$(stop $S 'Which approach do you want?')"

echo "6. no source touched -> allow (docs-only turn)"
S=v6; state_set $S last_test_pass 0; state_set $S last_source_edit 0
check "exit 0" "0" "$(stop $S 'Done. Updated the README.')"

echo "7. LOOP GUARD: stop_hook_active -> stand down"
S=v7; state_set $S last_test_pass 1000; state_set $S last_source_edit 2000
check "exit 0" "0" "$(stop $S 'Done.' true)"

echo "8. FAIL OPEN: repo declares no test command -> allow, and warn"
NOGATE=$(mktemp -d)
S=v8; state_set $S last_test_pass 0; state_set $S last_source_edit 2000
out=$(printf '{"session_id":"%s","cwd":"%s","stop_hook_active":false,"last_assistant_message":"Done."}' "$S" "$NOGATE" | bash "$H" 2>&1 >/dev/null; )
rc=$(printf '{"session_id":"%s","cwd":"%s","stop_hook_active":false,"last_assistant_message":"Done."}' "$S" "$NOGATE" | bash "$H" >/dev/null 2>&1; echo $?)
check "exit 0 (fails open)" "0" "$rc"
rm -rf "$NOGATE"

echo "9. FAIL OPEN: malformed stdin -> allow, no traceback"
rc=$(printf 'not json{{{' | bash "$H" >/dev/null 2>&1; echo $?)
check "exit 0" "0" "$rc"
err=$(printf 'not json{{{' | bash "$H" 2>&1 >/dev/null)
check "no traceback" "no" "$(printf '%s' "$err" | grep -q Traceback && echo yes || echo no)"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run it to confirm it fails (RED)**

```bash
bash tests/harness/verify_before_done.sh.test
```
Expected: all checks fail (`No such file or directory`).

- [ ] **Step 3: Write the Stop hook**

Create `hooks/scripts/verify_before_done.sh`:

```bash
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

field() {
  printf '%s' "$PAYLOAD" | python3 - "$1" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
v = d.get(sys.argv[1])
if v is None:
    sys.exit(0)
print(v)
PY
}

# --- loop guard: we are already looping, stand down ---
[ "$(field stop_hook_active)" = "True" ] && exit 0
[ "$(field stop_hook_active)" = "true" ] && exit 0

SESSION=$(field session_id); [ -n "$SESSION" ] || exit 0
CWD=$(field cwd);            [ -n "$CWD" ]     || CWD="$PWD"
MSG=$(field last_assistant_message)

LAST_EDIT=$(state_get "$SESSION" last_source_edit)
LAST_TEST=$(state_get "$SESSION" last_test_pass)
[ -n "$LAST_EDIT" ] || LAST_EDIT=0
[ -n "$LAST_TEST" ] || LAST_TEST=0

# --- no source touched this session: nothing to verify ---
[ "$LAST_EDIT" -eq 0 ] 2>/dev/null && exit 0

# --- no completion claim: a question or a partial report is a fine way to stop ---
printf '%s' "$MSG" | python3 "$SCRIPT_DIR/lib/claims.py" || exit 0

# --- tests are fresh: the claim is earned ---
[ "$LAST_TEST" -ge "$LAST_EDIT" ] 2>/dev/null && exit 0

# --- the repo declares no test command: we cannot enforce. Warn ONCE, allow. ---
TEST_CMD=$(detect_verify_gate "$CWD" | grep '^command=' | cut -d= -f2-)
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
```

```bash
chmod +x hooks/scripts/verify_before_done.sh
```

- [ ] **Step 4: Run the test (GREEN)**

```bash
bash tests/harness/verify_before_done.sh.test
```
Expected: `PASS=11 FAIL=0`.

- [ ] **Step 5: Build the fixture that must be caught**

A hook validated only on the happy path proves nothing — the same reason `bad-harness` exists.

`tests/harness/fixtures/stale-tests/composer.json`:

```json
{
  "name": "oltrematica/stale-tests-fixture",
  "description": "Fixture: a repo with a declared test command. Test scenario — not a real project.",
  "type": "project",
  "scripts": { "test": "pest" }
}
```

`tests/harness/fixtures/stale-tests/README.md`:

```markdown
# stale-tests fixture

A repo with a declared test command (`composer test`), used to exercise the
verification hook end to end.

**The scenario the hook must catch:** the tests pass, THEN a source file is
edited, THEN the agent claims the work is done. The last green result no longer
describes the code. The hook must block.

**Do not "fix" anything here.** There is nothing broken — the defect is in the
*sequence*, and the sequence is the test.

| Scenario | State | Expected |
|---|---|---|
| tests pass, then source edited, then "Done." | `last_test_pass < last_source_edit` | **BLOCK** (exit 2) |
| source edited, then tests pass, then "Done." | `last_test_pass > last_source_edit` | allow (exit 0) |
| source edited, tests stale, but no claim made | — | allow (exit 0) |
| docs-only edit, then "Done." | `last_source_edit == 0` | allow (exit 0) |
```

Then drive the real scripts through the real sequence — recorder, then Stop hook — rather than hand-setting state:

```bash
F="$PWD/tests/harness/fixtures/stale-tests"
export OLTREMATICA_STATE_DIR=$(mktemp -d)
S=e2e-1

# 1. the tests run and pass
printf '{"session_id":"%s","cwd":"%s","tool_name":"Bash","tool_input":{"command":"composer test"},"tool_response":{}}' "$S" "$F" \
  | bash hooks/scripts/record_activity.sh

sleep 1   # ensure a distinct second, so the ordering is unambiguous

# 2. then a source file is edited
printf '{"session_id":"%s","cwd":"%s","tool_name":"Edit","tool_input":{"file_path":"%s/app/Invoice.php"},"tool_response":{}}' "$S" "$F" "$F" \
  | bash hooks/scripts/record_activity.sh

# 3. then the agent claims it is done
printf '{"session_id":"%s","cwd":"%s","stop_hook_active":false,"last_assistant_message":"Done. Fixed the invoice bug."}' "$S" "$F" \
  | bash hooks/scripts/verify_before_done.sh
echo "exit=$?  (MUST be 2)"
rm -rf "$OLTREMATICA_STATE_DIR"
```

Expected: the block message on stderr, naming `composer test`, and `exit=2`.
Record the actual output in `tests/harness/notes.md`.

- [ ] **Step 6: Commit**

```bash
git add hooks/scripts/verify_before_done.sh tests/harness/verify_before_done.sh.test \
        tests/harness/fixtures/stale-tests tests/harness/notes.md
git commit -m "feat(hooks): block a done-claim when the tests are stale

Exit 2, never exit 1 — exit 1 is non-blocking and would fail open silently
while appearing to work. Fails open on everything it does not understand."
```

---

### Task 6: Plugin packaging

Hooks live in `settings.json`. The alternative to a plugin is editing that file in ~190 repositories and re-merging it on every update. Plugin hooks merge automatically across scopes, touching nobody's settings.

**Files:**
- Create: `plugin.json`
- Create: `.claude-plugin/marketplace.json`
- Create: `hooks/hooks.json`
- Modify: `docs/distribution.md` (plugin becomes the primary path; `install.sh` demotes to fallback)

**Interfaces:**
- Consumes: `hooks/scripts/record_activity.sh`, `hooks/scripts/verify_before_done.sh`.
- Produces: an installable plugin. Scripts are referenced via `${CLAUDE_PLUGIN_ROOT}` so they resolve wherever the plugin is installed.

- [ ] **Step 1: Write the hook wiring**

Create `hooks/hooks.json`:

```json
{
  "description": "Verification gate: an agent cannot claim the work is done while the tests are stale.",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/record_activity.sh",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "Write|Edit|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/record_activity.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/verify_before_done.sh",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

Note: `Stop` takes **no matcher** — the docs list it among the events with no matcher support. Do not add one.

- [ ] **Step 2: Write the plugin and marketplace manifests**

Create `plugin.json`:

```json
{
  "name": "oltrematica-skills",
  "version": "1.0.0",
  "description": "Oltrematica Claude Code skills: compliance evidence and harness engineering, plus the verification gate.",
  "author": { "name": "Oltrematica" }
}
```

Create `.claude-plugin/marketplace.json`:

```json
{
  "name": "oltrematica",
  "owner": { "name": "Oltrematica" },
  "plugins": [
    {
      "name": "oltrematica-skills",
      "source": "./",
      "description": "Seven skills across two tracks, plus a Stop hook that blocks a done-claim when the tests are stale."
    }
  ]
}
```

- [ ] **Step 3: Verify the plugin actually loads — do not assume it**

```bash
claude plugin marketplace add "$PWD" 2>&1 | tail -3 || echo "check the CLI's marketplace subcommand name"
```

Then, in a Claude Code session in a scratch repo, run `/plugin` to install `oltrematica-skills`, and `/hooks` to confirm all three hooks are listed with source `Plugin`. Record the actual `/hooks` output in `tests/harness/notes.md`.

If the CLI's marketplace subcommand differs from the above, find the real one (`claude plugin --help`) and use it. **Do not record a command in the docs that you have not run.**

- [ ] **Step 4: End-to-end in a real session — the only proof that counts**

Every test so far feeds the scripts synthetic stdin. This step proves the platform actually invokes them.

In a scratch repo with a `composer.json` declaring `scripts.test`, with the plugin installed:
1. Ask Claude to run the tests.
2. Ask it to edit a source file.
3. Ask it to say the work is done.

The turn must be **blocked**, with the block message visible, and the agent must go and run the tests. Record what actually happened in `tests/harness/notes.md` — including if it did NOT work, and why.

- [ ] **Step 5: Update the distribution doc**

Rewrite the install section of `docs/distribution.md`: the plugin marketplace is the **primary** path (one install, hooks included, central updates, no `settings.json` edits); `scripts/install.sh` is retained as the **fallback** for repos that cannot use the marketplace — and note plainly that the fallback installs **skills only, not hooks**, because hooks need the plugin.

- [ ] **Step 6: Commit**

```bash
git add plugin.json .claude-plugin hooks/hooks.json docs/distribution.md tests/harness/notes.md
git commit -m "feat(plugin): package the repo as a Claude Code plugin

Hooks merge automatically across scopes; the alternative was editing
settings.json in ~190 repos and re-merging on every update."
```

---

### Task 7: Quorum-test the claim detector

The detector is the hook's soft joint. We do not get to assert it works.

**Files:**
- Create: `tests/harness/claim_corpus.json`
- Modify: `tests/harness/trigger-validation.md` (append a section)

**Interfaces:**
- Consumes: `hooks/scripts/lib/claims.py` (Task 4).
- Method: `skills/harness/harness-eval/SKILL.md` Mode 1, followed literally.

- [ ] **Step 1: Build the corpus**

Create `tests/harness/claim_corpus.json` — **at least 15 messages that claim completion and at least 15 that do not**, as final assistant messages a real session would produce:

```json
{
  "detector": "hooks/scripts/lib/claims.py",
  "samples": [
    {"text": "Done — the migration now has a working down().", "expect": "claim"},
    {"text": "Fixed. The invoice test passes.", "expect": "claim"},
    {"text": "All tests pass.", "expect": "claim"},
    {"text": "That's complete — ready for review.", "expect": "claim"},
    {"text": "Implemented the retry logic; everything is green.", "expect": "claim"},

    {"text": "Done reading the file — here is what I found.", "expect": "no-claim"},
    {"text": "I'm going to fix the failing test now.", "expect": "no-claim"},
    {"text": "The tests should pass once we wire up the config.", "expect": "no-claim"},
    {"text": "Should I run the suite before continuing?", "expect": "no-claim"},
    {"text": "Here are three options; which do you want?", "expect": "no-claim"}
  ]
}
```

Fill it out to the 15/15 minimum. The adversarial samples are the point — include at least: "done" used non-terminally ("done with the analysis, now for the code"), a prediction ("that should fix it"), a question containing "fixed", a claim in the middle of a longer message rather than at the end, and a claim about something *other* than the code ("done — I've updated the README").

- [ ] **Step 2: Judge the corpus with a blind quorum**

Follow `skills/harness/harness-eval/SKILL.md` Mode 1 **literally**. Its three MUSTs bind here:

- judges get **NO TOOLS**;
- **one judge = one sample = one vote** (a judge shown the whole corpus calibrates and inflates its own score);
- **pin the judge model**, the same cheap model for every judge.

Each judge sees only the message text and:

> Does this message CLAIM that the coding work is complete? Answer `claim` or `no-claim`, then one sentence of reasoning.

**You must not judge any sample yourself** — you can see the expected labels.

Then compare the **detector's** output against the **quorum's** verdict:

```bash
python3 - <<'PY'
import json, subprocess
spec = json.load(open("tests/harness/claim_corpus.json"))
for s in spec["samples"]:
    rc = subprocess.run(["python3", "hooks/scripts/lib/claims.py"],
                        input=s["text"], text=True, capture_output=True).returncode
    print(("claim" if rc == 0 else "no-claim"), "|", s["expect"], "|", s["text"][:60])
PY
```

- [ ] **Step 3: Record and fix**

Append a section to `tests/harness/trigger-validation.md` with the full table: sample, quorum vote (e.g. `3/3 claim`), quorum verdict, detector output, agree/disagree.

- A sample where the **quorum splits** is `FLAKY`: the message is genuinely ambiguous, and the detector is not charged with it. **Never round a 2/3 into a pass.**
- A **detector false positive** (fires where the quorum says no-claim) is the serious one: it blocks legitimate work. Fix the pattern in `claims.py`, then re-run the whole corpus.
- A **detector miss** is a hole; fix it too, but it is the safer failure.

Update the cumulative judgement count and show the arithmetic reconciles.

- [ ] **Step 4: Commit**

```bash
git add tests/harness/claim_corpus.json tests/harness/trigger-validation.md hooks/scripts/lib/claims.py
git commit -m "test(hooks): quorum-test the completion-claim detector

The detector decides whether a turn gets blocked. Asserting it works would
be the exact error this hook exists to prevent."
```

---

### Task 8: Documentation

**Files:**
- Modify: `README.md` (the hook, and the plugin install)
- Modify: `docs/harness/brief.md` (hooks close the advisory gap)
- Create: `docs/harness/verification-hook.md`
- Modify: `docs/harness/rollout-note.md`

**Interfaces:** consumes everything above.

- [ ] **Step 1: Write `docs/harness/verification-hook.md`**

Cover: the rule (claim + stale tests → block); why stale rather than absent; what it does NOT do (the cut rules from spec §3, named, so nobody assumes coverage that does not exist); the escape hatch (run the tests — the block message says so); how it fails open, and why that is deliberate; and — if Task 2 Step 1 found exit status unobservable — **state plainly that it enforces "you ran the suite", not "the suite was green"**. Do not let that limitation live only in a commit message.

- [ ] **Step 2: Update `README.md`**

Add the plugin install as the primary path, with `install.sh` as the fallback that ships **skills only, not hooks**. Add a short section on the verification gate: what it blocks, and the one sentence that matters — *the catalogue was advisory until this; a hook is the only artifact in it that a model cannot skip.*

Verify every number you print by running something. Verify every link resolves. Verify the install command runs.

- [ ] **Step 3: Update `docs/harness/brief.md` and the rollout note**

`brief.md`: the track's own `subagent-authoring` skill says that a rule which must hold every time is a hook, not an instruction — and until now we shipped none. State that plainly; it is the honest framing.

`rollout-note.md`: what changes for a developer. Blunt: *if you claim done with stale tests, the turn will be blocked and you will be told to run them.* And name what it does not do, so nobody thinks they are covered against secrets or bad dependencies.

- [ ] **Step 4: Full verification sweep**

```bash
for t in tests/harness/verify_gate.sh.test tests/harness/state.sh.test \
         tests/harness/record_activity.sh.test tests/harness/claims.py.test \
         tests/harness/verify_before_done.sh.test tests/harness/inventory.sh.test \
         tests/harness/eval_run.py.test tests/install.sh.test; do
  printf "%-42s %s\n" "$(basename $t)" "$(bash $t 2>&1 | tail -1)"
done

# no relative link is dead
python3 - <<'PY'
import os, re, sys
bad = []
skip = {'.git', '.superpowers', 'node_modules', 'superpowers'}
for root, dirs, files in os.walk('.'):
    dirs[:] = [d for d in dirs if d not in skip]
    for f in files:
        if not f.endswith('.md'):
            continue
        p = os.path.join(root, f)
        for l in re.findall(r']\((\.\.?/[^)#]+)', open(p, errors='ignore').read()):
            if not os.path.exists(os.path.normpath(os.path.join(root, l))):
                bad.append(f"{p} -> {l}")
print("\n".join(bad) if bad else "OK: every relative link resolves")
PY

# the block path exits 2 and never 1
grep -n "exit 2\|exit 1" hooks/scripts/verify_before_done.sh
```
Expected: every suite `FAIL=0`; links `OK`; and **no `exit 1` anywhere** in the Stop hook.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/harness
git commit -m "docs: document the verification gate and plugin install"
```

---

## Self-Review

**Spec coverage:**

| Spec section | Task |
|---|---|
| §4 The rule (claim + stale) | 5 |
| §4 Source-file definition | 3 (recorder), asserted in its tests |
| §5 Architecture (3 hooks, state file) | 2, 3, 5 |
| §5 Reuse `inventory.sh` gate detection | 1 |
| §5 "Passing", not merely "ran" | 2 Step 1 (empirical), 3 Step 3 |
| §6 Claim detector + blind quorum | 4, 7 |
| §7 Fail open / exit 2 / loop guard / no-gate warning | 5 (all asserted in its test) |
| §8 Plugin packaging | 6 |
| §9 Contract tests, must-block fixture, quorum | 1–5, 5 Step 5, 7 |
| §10 H-1…H-7 | honoured throughout; H-2 is the Global Constraint at the top |

**Placeholder scan:** none. The one genuinely open item — whether `tool_response` exposes a Bash exit status — is not a placeholder but an **experiment with a defined procedure and both outcomes specified** (Task 2 Step 1). The plan says what to build in each case, and requires the weaker outcome to be documented loudly rather than hidden.

**Type consistency:** `detect_verify_gate` / `is_test_command` (Task 1) are called with identical signatures in Tasks 3 and 5. State keys (`last_test_pass`, `last_source_edit`, `warned_no_gate`, `test_evidence`) are identical across Tasks 2, 3 and 5. `claims.py`'s exit contract (0 = claim, 1 = no claim) is identical in Tasks 4, 5 and 7. `OLTREMATICA_STATE_DIR` is the test override in every suite that needs one.

**One thing I changed during review:** Task 1's test originally accepted any command mentioning tests. That would let `cat tests/FooTest.php` satisfy the verification gate — a hole straight through the feature. Test 8 now asserts the rejection, and `is_test_command` has an explicit reader-command denylist ahead of its allowlist.
