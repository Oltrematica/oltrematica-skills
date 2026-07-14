# Test notes — harness track

Living documentation: evidence from standalone script tests against the fixture in
`tests/harness/fixtures/`. Append a dated section per test run.

## Fixture

`bad-harness` — a repo with five deliberate harness defects (D1–D5). See its
[README](fixtures/bad-harness/README.md). Do not fix the defects; they are the test.

## 2026-07-14 — fixture construction

| Defect | Assertion | Result |
|--------|-----------|--------|
| D1 | `CLAUDE.md` > 200 lines (actual: 227), procedure not policy | ✓ |
| D2 | no `.claude/agents/` | ✓ |
| D3 | no `.claude/settings.json` | ✓ |
| D4 | `composer.json` has no `scripts.test` | ✓ |
| D5 | `do-everything` skill with an any-prompt description | ✓ |

## 2026-07-14 — inventory.sh

**Step 2: RED** — `bash tests/harness/inventory.sh.test` before `inventory.sh`
existed: `PASS=0 FAIL=9`, first failure `exit code 0 on a valid repo (expected
'0', got '127')` (bash reports "No such file or directory" on stderr, no
traceback). Confirms the test fails for the right reason.

**Step 4: GREEN**

| # | Test | Result |
|---|------|--------|
| 1 | Exit 0 + valid JSON on the fixture | ✓ |
| 2 | All seven surfaces present as keys | ✓ |
| 3 | D1 detected (CLAUDE.md > 200 lines) | ✓ |
| 4 | D2 detected (0 agents) | ✓ |
| 5 | D3 detected (hooks not configured) | ✓ |
| 6 | D4 detected (no verify gate) | ✓ |
| 7 | D5 inventoried (`do-everything` in skills) | ✓ |
| 8 | Non-existent repo root → exit 1, no traceback | ✓ |
| 9 | Run against this repo → valid JSON, no crash (proves it doesn't always report gaps) | ✓ |

`bash tests/harness/inventory.sh.test` → `PASS=9 FAIL=0` for the contract
subset above (see the full run below for the extended robustness suite).

**Brief discrepancy found and resolved**: the task-7 brief's own `interfaces`
section and its Step-1 contract test both require *exactly* seven top-level
JSON keys (`claude_md`, `skills`, `agents`, `hooks`, `commands`, `mcp`,
`verify_gate`), but the brief's Step-3 code sample additionally emits an
eighth key, `repo_root`. Implementing the sample verbatim fails the sample's
own test (`FAIL: all seven surfaces reported`, actual keys included
`repo_root`). Resolved in favor of the explicit interface contract and the
test: `repo_root` is not emitted.

**Robustness hardening beyond the brief** — this script runs against
arbitrary, possibly messy repos, so the following were tested and hardened:

| Case | Risk if unhandled | Fix |
|------|--------------------|-----|
| Malformed `composer.json` / `package.json` / `.claude/settings.json` (invalid JSON) | Uncaught `json.JSONDecodeError` traceback, or a crash under `set -e` | Every JSON read goes through a python helper (`json_key_truthy`, `has_scripts_test`) that catches `Exception` and reports the surface as absent/not-configured, never crashes |
| Repo path containing a space, `'`, or `"` | Original brief script interpolated `$SETTINGS`/`$ROOT` directly into Python source text (`open('$SETTINGS')`) — a `'` in the path breaks out of the string literal; interpolating `$ROOT` into the JSON heredoc as `"repo_root": "$ROOT"` breaks the emitted JSON for the same reason | Every path is passed to Python via `argv` (heredoc + `"$@"`), never string-interpolated into source text; the one raw string field (`verify_gate.source`) is emitted via a `json_str()` helper that calls `json.dumps` |
| Unreadable `CLAUDE.md` (permission denied) | `wc -l < file` failing under `set -e` inside a bare assignment can abort the whole script | Added a `[ -r "$CLAUDE_MD" ]` guard and treat unreadable the same as absent |
| Unreadable `.claude/skills` (or agents/commands) directory | `os.listdir` raising `PermissionError`, propagating as an uncaught exception and leaving the bash variable empty (→ invalid JSON, e.g. `"skills": ,`) | `list_names()` wraps the listing in `try/except OSError` → `[]`; callers also fall back to `'[]'` if the substitution is ever empty |
| `python3` missing entirely | `command not found` scattered across every JSON-emitting step, ending in a stack of shell errors and no coherent message | Preflight `command -v python3` check at the top; on failure, one clear stderr message + install hint, exit `127` (matches the `exit 127` convention already used by `cra-evidence`'s scripts for a missing external tool) |

All five cases (plus the missing-`python3` case) were run standalone against
throwaway `mktemp -d` fixtures, confirmed to reproduce the failure against a
naive implementation, fixed, and then folded into
`tests/harness/inventory.sh.test` as permanent regression checks (14 new
assertions) so they can't silently regress.

**Full test run** (`bash tests/harness/inventory.sh.test`):

```
PASS=23 FAIL=0
```

**Collateral fix**: `tests/install.sh.test` scenario 10 (ambiguous skill name
across tracks) built its fixture at `skills/harness/adr-management/` and its
cleanup ran `rm -rf skills/harness` unconditionally. That was safe only while
`skills/harness/` had no real content. Now that this task adds
`skills/harness/harness-audit/`, running that test would have deleted this
skill. Fixed the cleanup to remove only the fixture subdirectory it created;
re-ran `tests/install.sh.test` → `PASS=25 FAIL=0`, and confirmed
`skills/harness/harness-audit/` survives the run.

**Summary**: `inventory.sh` contract verified — facts only, no judgement; all
five fixture defects surfaced in the JSON; error path clean; hardened and
regression-tested against malformed JSON inputs, unreadable files, odd repo
paths, and a missing `python3`.

## 2026-07-14 — addendum: surface and skill counts grew after this entry

The "inventory.sh" entry above (`## 2026-07-14 — inventory.sh`) is left
unedited as the honest record of what was true when it was written: at that
point `inventory.sh` reported **seven** surfaces and the harness track had
**four** skills. Both grew later the same day (Task 13 added `model-routing`
as the fifth harness skill; Task 14 added it as `inventory.sh`'s eighth
audited surface, `model_routing`) — see
`skills/harness/harness-audit/scripts/inventory.sh` (now emits eight JSON
keys) and `tests/harness/trigger-validation.md` (now covers five skills).
Re-running `bash tests/harness/inventory.sh.test` today against current
`main` gives `PASS=35 FAIL=0` (up from the `PASS=23 FAIL=0` recorded above,
reflecting the eighth-surface assertions and their robustness cases added
since). This note documents the growth; it does not retroactively rewrite
the entry above.

## 2026-07-14 — claude-md-authoring (no script; judgement rehearsal)

Ran the SKILL.md diagnostic workflow against the `bad-harness` fixture by hand:

| Step | Check | Result |
|------|-------|--------|
| 1 | `wc -l CLAUDE.md` → over the 200-line threshold | ✓ (actual: 227) |
| 2 | Classify sections: 3 × `## How to ...` = procedure, not policy | ✓ (`grep -c "^## How to"` → 3; sections span lines 3–221, ~194 of 227 lines, ~85% of the file) |
| 3 | Conclusion reached by following the skill literally | ✓ D1 identified as a procedure dump; fix is extraction into three skills (controller scaffold, model scaffold, test-writing), not stronger wording |

Steps 1–2 alone were sufficient to reach the required conclusion, with no need
to consult `references/antipatterns.md` first — the reference stayed useful for
the residual `## Misc` section (`Be careful.` / `Try to write good code.` /
`Don't break things.`), which is a third case the diagnostic workflow's binary
policy-vs-procedure framing doesn't name directly: it is antipattern #2
(unverifiable exhortation), not procedure. This didn't block or mislead the
rehearsal — the dominant defect (three How-to sections) was unambiguous well
before reaching that edge case — so no change was made to the skill; noted here
as the one rough edge found.

SKILL.md is 99 lines, under the 500-line ceiling; frontmatter well-formed
(`name:` and `description:` present). No script — this skill is pure judgement
and has nothing deterministic to extract.

## 2026-07-14 — subagent-authoring (no script; selector validation)

Artifact selector walked against the brief's four cases; each landed on exactly
one row:

| Case | Selected | Ambiguous? |
|------|----------|------------|
| "Format every file after editing" | Hook | no — "every" is decisive, and the trigger (`PostToolUse` on `Edit`/`Write`) is mechanical |
| "Survey auth across 40 files" | Subagent | no — conclusion, not work |
| "Draft an ADR when a decision is made" | Skill | no, but only after a table fix — see below |
| "Fire a release checklist on demand" | Slash command | no — human-triggered |

**Table fix made before this passed cleanly**: the brief's original hook
criterion was "must happen every time" alone. Walking the ADR case
("whenever we make an architectural decision") against that single-part test
was genuinely ambiguous: "whenever" satisfies "must happen every time" just as
well as the formatting case does, which would pull it toward Hook — the wrong
answer, since detecting "an architectural decision was made" takes judgment no
hook can perform. Added a second, mandatory part to the hook test: the trigger
must be a mechanical event the harness can observe without judgment (file
saved, tool called, session start/stop). Both parts must hold. This closed the
ambiguity: the ADR case fails part 2, so it is a skill; the formatting case
passes both, so it is a hook. Worked the contrast explicitly in the SKILL.md
prose so the next reader doesn't rediscover the same trap.

**Two additional hard cases invented (not in the brief), walked after the fix**:

| Case | Selected | Ambiguous? |
|------|----------|------------|
| "Before merging, always double-check the PR description matches the diff" | Subagent | no, but non-obvious — see below |
| "Whenever a PR touches payments, ping the payments team lead" | Out of scope (none of the four) | no, once the scope boundary is stated |

- The PR-description case is a trap in the *other* direction from the ADR case:
  "always" tempts a hasty reader toward Hook, but comparing free-text meaning is
  judgment, so it fails part 2 of the hook test and is not a hook. Applying the
  skill-vs-subagent decisive question ("work or conclusion?") resolves it
  cleanly: the caller only needs a verdict (match / mismatch + reason), so it's
  a review-type Subagent, not a Skill. In practice this case decomposes into two
  artifacts — a Subagent that renders the verdict, and (separately) a Hook that
  gates the merge on that verdict — which the table handles by being applied
  twice, not by adding a fifth row.
- The payments-PR case exposed a real gap in the original four rows: "PR
  opened" is mechanical in principle but is a GitHub/GitLab event, not
  something a Claude Code `settings.json` hook can observe — the four rows are
  scoped to Claude Code session artifacts. Added an explicit scope-boundary
  sentence to SKILL.md so this resolves as a decisive "none of the four, here's
  where it actually belongs" rather than a forced, wrong pick.

**Handoff check**: both `harness-audit` and `claude-md-authoring` hand off "a
subagent, a command, or a hook" decision to this skill by name. The shipped
SKILL.md originally (per the brief) only detailed subagent authoring; slash
commands were named in this skill's own trigger description ("add a /deploy
command") but had no authoring section, which would have been a dead-end
handoff. Added an "Authoring a slash command" section (`.claude/commands/`
frontmatter + body shape) so all three referenced artifacts are actually
deliverable here, not just decided.

SKILL.md is 135 lines, under the 500-line ceiling; hooks handed off to
`update-config` (never hand-edited); least-privilege tool guidance present
(`Read, Grep, Glob, Bash` — no `Write`/`Edit` — for research/review agents).
`assets/agent_template.md` matches the brief's template exactly.

## 2026-07-14 — eval_run.py

**Step 2: RED** — `skills/harness/harness-eval/scripts/eval_run.py` did not
exist yet: `PASS=4 FAIL=6`, exit 1 (python3 itself produced exit 2 for the
missing/thin/dupe/unreadable cases by accident of `python3: can't open file`,
which is why 4 checks passed before any implementation existed — the table and
5/5-minimum/duplicate-naming checks correctly failed, since there was nothing
to produce that output). ✓ confirmed red for the right reason.

**Step 5: GREEN** — after writing `eval_run.py` per the brief, with the
`sys.exit(2)` correction applied to both `load()` branches (see deviation
note below):

| # | Test | Result |
|---|------|--------|
| 1 | Shipped example spec validates | ✓ exit 0 |
| 2 | Under-5-prompts spec rejected, explains the minimum | ✓ exit 2 |
| 3 | Duplicate prompts rejected by name | ✓ exit 2 |
| 4 | Missing spec file → exit 2, no traceback | ✓ |
| 5 | `--emit-table` renders a markdown table with a blank Verdict/Judges column | ✓ |

`PASS=10 FAIL=0` — matches the brief's stated expectation exactly.

**Summary**: eval_run.py does the deterministic half only — spec validation and
table rendering. It deliberately does NOT judge whether a skill fired; that is the
model's job via fresh subagents (SKILL.md Mode 1 step 2). A script that pretended
to judge would produce confident, wrong evidence.

Deviation from the design spec: the eval spec is **JSON, not YAML**. python3 stdlib
has `json` and not `yaml`; YAML would require PyYAML, and this repo adds no
dependencies.

**Bug in the brief, fixed per the brief's own instructions**: the brief's
initial `load()` draft used `sys.exit(f"ERROR: ...")` for both the
`FileNotFoundError` and `JSONDecodeError` branches, which prints to stderr and
exits **1** — but the brief's own contract test (case 4) asserts exit **2** for
a missing spec. Implemented per the brief's correction: both branches now do
`print(..., file=sys.stderr); sys.exit(2)` explicitly.

**Robustness beyond the brief** — `eval_run.py` reads arbitrary user-authored
JSON, so `tests/harness/eval_run.py.test` was extended with 13 additional
cases (26 checks) covering shapes the brief's four cases don't exercise. None
may produce a traceback; all must produce an actionable stderr message and
exit 2 (or, where the input is actually fine, must not corrupt the table):

| # | Case | Why it's dangerous if unhandled |
|---|------|----------------------------------|
| 6 | Spec is JSON `null` | `spec.get(...)` on `None` → `AttributeError` traceback |
| 7 | Spec is a bare JSON list | `spec.get(...)` on a `list` → `AttributeError` traceback |
| 8 | `"skills"` is a string, not a list | Already guarded by the brief's `isinstance` check; confirmed no crash |
| 9 | A `skills[i]` entry is not an object (e.g. a string) | `skill.get("name")` on a `str` → `AttributeError` traceback |
| 10 | `"prompts"` key missing entirely | Already guarded (`isinstance(prompts, list)` is `False` for `None`); confirmed |
| 11 | `"expect"` misspelled (`"triggered"`) | Confirmed rejected by name, not silently coerced to `trigger`/`no-trigger` |
| 12 | Empty `"prompt"` string | Confirmed caught (falsy-string check), distinct from a missing key |
| 13 | A prompt containing a literal `\|` | Would corrupt the markdown table's column count — confirmed escaped (`\\|`) and the table still has exactly 10 data rows, not 11+ from a split cell |
| 14 | Unicode in a prompt (accents, CJK, emoji) | Confirmed no crash and the text round-trips unmangled through `--emit-table` |
| 15 | `"regressions"` present but not a list | Original brief code iterated `spec.get("regressions", [])` directly; if it were a string, `entry.get(...)` on a `str` character → `AttributeError` traceback. Added an explicit `isinstance` guard |
| 16 | Spec path is a directory | `open()` raises `IsADirectoryError`, an `OSError` subclass not caught by the brief's `FileNotFoundError`/`JSONDecodeError` pair → traceback. Added a dedicated branch, ordered before a general `OSError` catch-all also added for the same reason (e.g. permission errors) |

All 16 cases (36 checks total, the brief's original 10 plus these 26) pass:
`PASS=36 FAIL=0`. Code changes made to survive these cases, beyond the brief's
listing: `validate()` now type-checks `spec` itself, every `skills[i]`, every
prompt entry, and `regressions` before calling `.get()` on any of them;
`load()` gained an `IsADirectoryError` branch and a general `(OSError,
UnicodeDecodeError)` branch (opened with explicit `encoding="utf-8"`); `main()`
wraps `validate()` and `emit_table()` in a narrow last-resort `except
Exception` that prints an actionable message and exits 2 rather than letting
any missed case surface a traceback — defense in depth, not a substitute for
the type-checks above.

**Self-consistency**: `assets/eval_spec.example.json` targets
`tests/harness/fixtures/bad-harness`'s D5 defect (`do-everything` skill) with 5
trigger + 5 no-trigger prompts and one `regressions` entry, and validates
against the script's own 5/5 minimum:
`python3 skills/harness/harness-eval/scripts/eval_run.py --validate
skills/harness/harness-eval/assets/eval_spec.example.json` → `OK: ... is a
valid eval spec`. The fixture itself was not modified.

SKILL.md is 166 lines, under the 500-line ceiling; frontmatter well-formed.
Handoff check: `harness-audit` and `claude-md-authoring` both route "a skill's
description over- or under-triggers" to `harness-eval` by name;
`subagent-authoring` routes "a proper trigger check" here. All three land on
Mode 1 (trigger validation), which this SKILL.md delivers as an executable
procedure — quorum of 3 fresh, blind subagents per prompt, a 3-value verdict
(`PASS`/`FAIL`/`FLAKY`) with splits never rounded up, plus Mode 2 (behavioral
regression with an adversarial skeptic subagent) for the CLAUDE.md-change use
case the other three skills don't cover.

## 2026-07-14 — state.sh, and the empirical `tool_response` probe (Task 2, verification-hook track)

### Step 1: empirical probe — is a Bash exit status observable from `tool_response`?

Method: a throwaway probe hook (`cat >> captured.jsonl; exit 0`) was registered
as a `PostToolUse` / matcher `Bash` hook **only** in a scratch directory's own
`.claude/settings.json** (created via `mktemp -d`) — never in
`~/.claude/settings.json` and never in this repo. Headless `claude -p ... --permission-mode bypassPermissions` sessions were run inside that scratch
directory to make real Bash tool calls, varying which command succeeded /
failed and the order, then the probe's capture file and the session
transcript were inspected. The scratch dir, its settings file, and the probe
script were deleted afterward; `~/.claude/settings.json` was never modified
(verified by diff-less `grep` for the probe path after cleanup).

**Run 1 — `true` then `false` in one turn.** Captured exactly ONE hook event,
for `true`; nothing was captured for `false`, even though the transcript
confirms both ran (`Bash` tool used twice, second with `Exit code 1`):

```json
{
  "session_id": "9ff2b914-bd8a-48ca-8d5d-6f663a03f19e",
  "transcript_path": "/Users/andreamargiovanni/.claude/projects/-private-tmp-hookprobe-scratch-8DGsKB/9ff2b914-bd8a-48ca-8d5d-6f663a03f19e.jsonl",
  "cwd": "/private/tmp/hookprobe-scratch.8DGsKB",
  "prompt_id": "a4a1d397-67c9-4e94-a1d3-f3b47bb5e57b",
  "permission_mode": "bypassPermissions",
  "effort": {"level": "high"},
  "hook_event_name": "PostToolUse",
  "tool_name": "Bash",
  "tool_input": {"command": "true", "description": "Run true"},
  "tool_response": {
    "stdout": "",
    "stderr": "",
    "interrupted": false,
    "isImage": false,
    "noOutputExpected": false
  },
  "tool_use_id": "toolu_01JRpvWmcvCRu2Sc9NMQkVHw",
  "duration_ms": 546
}
```

Transcript for that turn confirms both tool calls actually happened, and shows
how Claude Code itself distinguishes them (`is_error` on the tool_result, not
on anything the hook ever sees):

```
TOOL_USE Bash {'command': 'true', 'description': 'Run true'}
TOOL_RESULT is_error=None content=(Bash completed with no output)
TOOL_USE Bash {'command': 'false', 'description': 'Run false'}
TOOL_RESULT is_error=None content=Exit code 1
```

**Run 2 — repeat with `--debug hooks`.** Same result: one captured event, for
the succeeding `true`, none for `false`.

**Run 3 — three passing commands, no failures, to rule out "hook only fires
once per session".** All three were captured (3 lines in `captured.jsonl`,
one per `true` call, each with a distinct `tool_use_id`). This rules out a
one-shot-per-session hook; it fires per successful tool call.

**Run 4 — reversed order, `false` then `true`.** Only ONE event captured,
for `true` (the second, succeeding call):

```json
{
  "session_id": "1d6ba7e9-3dbb-4a3e-9d0d-15cb309af69e",
  "tool_name": "Bash",
  "tool_input": {"command": "true", "description": "Run the true command"},
  "tool_response": {"stdout": "", "stderr": "", "interrupted": false, "isImage": false, "noOutputExpected": false}
}
```

Transcript for this run, with `is_error` explicitly inspected:

```
TOOL_USE Bash {'command': 'false', ...}
TOOL_RESULT is_error= True content= Exit code 1
TOOL_USE Bash {'command': 'true', ...}
TOOL_RESULT is_error= False content= (Bash completed with no output)
```

**Run 5 — a single failing command in complete isolation** (`exit 7`, no
succeeding command anywhere in the turn): `captured.jsonl` had **zero** lines.
`wc -l` = 0. The transcript confirms the tool call happened
(`is_error=True`, `content=Exit code 7`) but no `PostToolUse` event was ever
delivered to the hook.

**Run 6 — a realistic failing "test runner"-shaped command** (stdout containing
`3 passed, 2 failed` / `FAILURES!`, `exit 1`), to rule out the null result
being an artifact of empty stdout: again **zero** captured lines.

### Verdict

There is **no exit-code / success field on `tool_response`** for `Bash` at
all — the observed shape for a succeeding call is exactly
`{stdout, stderr, interrupted, isImage, noOutputExpected}`, none of which
encode success/failure. That much matches the brief's "NOT available" branch
literally.

The empirical evidence corroborates a **documented** contract, not a
version-specific quirk: Claude Code's own documentation specifies that
`PostToolUse` fires "after a tool call succeeds," with a separate
`PostToolUseFailure` event delivered for failing tool calls. **`PostToolUse`
(matcher `Bash`) is therefore not invoked when the underlying command exits
non-zero** — this is the documented behavior, not something inferred solely
from observation. The probe above reproduced it six times, with command order
varied, in isolation, and with realistic test-runner-shaped stdout, with zero
exceptions, as belt-and-braces confirmation that the documented contract
matches the shipped implementation. This is a mechanical fact about *when the
hook fires*, not a value read out of its payload, so it does not fall foul of
the brief's "no string-matching heuristics" warning — nothing is parsed or
inferred from output text; the signal is "did the hook fire for a
test-matching command in this turn, yes or no."

**Design consequence for Task 3 (`record_activity.sh`):** because a failing
Bash command never reaches the `PostToolUse` hook (by documented contract),
if the hook fires for a command matching the test-runner pattern, that
command exited zero. `record_activity.sh` may therefore record
`test_evidence="passed"` for a matching invocation, *not* by inspecting a
field, but by the simple fact of having been invoked at all for that command
— this is the guarantee that the hook's block decision rests on: the tests
actually **passed**, not merely that they ran. No `test_evidence="ran"`-only
degradation is required.

**Note, stated for completeness:** relying on a documented event-firing
contract is still relying on the platform's current documented behavior — if
a future Claude Code version changes what `PostToolUse` fires on, this
inference would need to move with it. That risk is materially smaller than an
undocumented quirk would carry, since a documented contract change is a
breaking API change subject to the platform's own compatibility expectations,
not a silent behavioral drift. This note is carried into `record_activity.sh`'s
implementation notes (Task 3), its block message wording, and the rollout
note (Task 6+).

Probe cleanup verified: scratch dir and `/tmp/hookprobe` removed;
`~/.claude/settings.json` and this repo's tree contain no trace of the probe
hook (checked by `grep -c "dump.sh" ~/.claude/settings.json` → `0`, and no
`.claude/settings.json` exists anywhere under this repo).

### Step 2–5: `state.sh`

**RED** — `bash tests/harness/state.sh.test` before `state.sh` existed:
`FAIL: cannot source .../hooks/scripts/lib/state.sh`, `PASS=0 FAIL=1` — matches
the brief's stated expectation exactly.

**Bug found in the brief's own test, fixed**: Step 7 of the brief's test
(`tests/harness/state.sh.test`) uses `case "$p" in "$OLTREMATICA_STATE_DIR"/*)
... esac` *inside* a `$(...)` command substitution. On macOS stock
`/bin/bash` 3.2.57 — the exact interpreter the global constraints name as the
target — this reproducibly fails to parse: the pattern-terminating `)` in
`"$DIR"/*)` is mis-scanned by bash 3.2's older command-substitution parser as
closing the surrounding `$(...)` early, producing `syntax error near
unexpected token '\;;'` (isolated and reproduced standalone before touching
the real test, in five minimal repros — confirmed backtick substitution
(`` `case ... esac` ``) and function-wrapped `case` both sidestep the bug;
`$(...)` around a bare `case` never works on this bash). Fixed by switching
that one assertion from `$(...)` to backticks (content unchanged otherwise);
verified against both a traversal and non-traversal path in isolation before
editing the shipped test file.

**Brief arithmetic discrepancy, noted**: the brief's Step 5 says "Expected:
`PASS=9 FAIL=0`", but the test file as given contains 10 `check` calls
(3 + 1 + 2 + 1 + 1 + 1 + 1). Implemented per the actual check count; the
correct expectation is `PASS=10 FAIL=0`.

**GREEN** — `bash tests/harness/state.sh.test` (and re-confirmed with an
explicit `/bin/bash` invocation per the global constraints' warning about
zsh's differing `BASH_REMATCH`/case semantics):

```
1. missing keys have safe defaults
  PASS: last_test_pass
  PASS: last_source_edit
  PASS: warned_no_gate
2. set then get
  PASS: reads back
3. set a second key without clobbering the first
  PASS: first key survives
  PASS: second key set
4. state file is valid JSON
  PASS: valid json
5. sessions are isolated
  PASS: no bleed
6. a corrupt state file does not crash — it reads as defaults (FAIL OPEN)
  PASS: corrupt -> default
7. session ids are sanitised (no path traversal into the filesystem)
  PASS: no traversal

PASS=10 FAIL=0
```

**Summary**: `state.sh` implements exactly the brief's `state_path` /
`state_get` / `state_set` contract (stdlib `python3` + `bash`, no new
dependencies), fail-open on missing/corrupt state (never crashes, always
degrades to defaults so the `Stop` hook can never be blocked by unreadable
state), atomic writes via `tempfile.mkstemp` + `os.replace` in the same
directory, and session-id sanitisation (`tr -c 'A-Za-z0-9._-' '_'`) that keeps
every state file inside `OLTREMATICA_STATE_DIR` regardless of input,
confirmed against a literal `../../etc/passwd` session id.

## Task 5: `verify_before_done.sh` — the Stop hook

**Bug found in the brief's own sample `field()` helper (not copied):** the
brief pipes `$PAYLOAD` into `python3 - "$1" <<'PY' ... PY`, i.e. a pipe AND a
heredoc on the same command. The heredoc consumes stdin, so the piped payload
never reaches Python — every field extraction silently returns empty. This
was already diagnosed and fixed in `record_activity.sh` (Task 3): pass the
payload as `argv[2]` instead of piping it. `verify_before_done.sh` reuses
that exact pattern (see the `field()` comment in the script) rather than
reinventing or copying the broken version.

**RED** (`tests/harness/verify_before_done.sh.test` before the script
existed — every check that shells out to the hook fails with exit 127):

```
1. THE CASE THAT MATTERS: claim + source edited after the tests passed -> BLOCK
  FAIL: exit 2 (blocks) (expected '2', got '127')
...
PASS=3 FAIL=16
```

(3 passes were checks that don't depend on the script existing, e.g. "not
exit 1" trivially holds when the command isn't found.)

**GREEN** (final run, `/bin/bash tests/harness/verify_before_done.sh.test` —
zsh is the login shell in this environment, so bash was invoked explicitly
per the task brief's constraint):

```
1. THE CASE THAT MATTERS: claim + source edited after the tests passed -> BLOCK
  PASS: exit 2 (blocks)
2. exit code is 2, never 1 (exit 1 is NON-blocking in Claude Code)
  PASS: not exit 1
3. the block message tells the agent how to satisfy it
  PASS: names the test command
4. tests ran AFTER the edit -> allow
  PASS: exit 0
5. no completion claim -> allow (even with stale tests)
  PASS: exit 0
6. no source touched -> allow (docs-only turn)
  PASS: exit 0
7. LOOP GUARD: stop_hook_active -> stand down
  PASS: exit 0
8. FAIL OPEN: repo declares no test command -> allow, and warn
  PASS: exit 0 (fails open)
  PASS: warns about no gate
9. FAIL OPEN: malformed stdin -> allow, no traceback
  PASS: exit 0
  PASS: no traceback
10. no exit 1 ANYWHERE in the script (exit 1 is silently non-blocking)
  PASS: no bare 'exit 1' in script
11. claim present but NO source edit at all this session (fresh session) -> allow
  PASS: exit 0
12. tests fresh by exactly ONE second -> allow (boundary, not stale)
  PASS: exit 0
13. tests and edit at the SAME timestamp -> allow (>=, not strictly newer)
  PASS: exit 0
14. state that does not exist at all (never recorded this session) -> allow
  PASS: exit 0
15. cwd that does not exist on disk -> fails open, does not crash
  PASS: exit 0 (fails open)
16. huge last_assistant_message does not crash the hook
  PASS: exit 2 (still blocks correctly)
17. stop_hook_active as JSON boolean true (unquoted) also stands down
  PASS: exit 0

PASS=19 FAIL=0
```

Beyond the brief's 9 checks: checks 10-17 cover no-`exit 1` static
verification, a claim with no source edit at all (fresh session, defaults),
a one-second-fresh boundary, an equal-timestamp boundary (`>=`, not strict
`>`), a session id never seen by `state_set`, a nonexistent `cwd`, a ~100KB
`last_assistant_message`, and `stop_hook_active` arriving as an unquoted
JSON `true` (as opposed to the brief's string case).

**End-to-end fixture run** — driving the ACTUAL scripts
(`record_activity.sh` then `verify_before_done.sh`) through
`tests/harness/fixtures/stale-tests/`, not hand-set state:

```
$ F="$PWD/tests/harness/fixtures/stale-tests"
$ export OLTREMATICA_STATE_DIR=$(mktemp -d)
$ S=e2e-1

# 1. tests run and pass
$ printf '{"session_id":"e2e-1","cwd":"'"$F"'","tool_name":"Bash","tool_input":{"command":"composer test"},"tool_response":{}}' \
    | bash hooks/scripts/record_activity.sh
record_activity exit=0

$ sleep 1

# 2. source file edited
$ printf '{"session_id":"e2e-1","cwd":"'"$F"'","tool_name":"Edit","tool_input":{"file_path":"'"$F"'/app/Invoice.php"},"tool_response":{}}' \
    | bash hooks/scripts/record_activity.sh
record_activity exit=0

# 3. agent claims done
$ printf '{"session_id":"e2e-1","cwd":"'"$F"'","stop_hook_active":false,"last_assistant_message":"Done. Fixed the invoice bug."}' \
    | bash hooks/scripts/verify_before_done.sh
```

stderr (the actual block message the model sees):

```
Verification gate: you claimed this work is done, but the tests are stale.

A source file was modified after the last test run, so the last green result
does not describe the code you are about to hand over.

Run the test suite and report the actual output:

    composer test

If it passes, say so and finish. If it fails, fix it. Do not restate that the
work is complete without running it.
```

Exit code:

```
exit=2  (MUST be 2)
```

State file at the moment of the block:

```
{"last_test_pass": 1784038367, "test_evidence": "passed", "last_source_edit": 1784038368}
```

`last_test_pass` is exactly 1 second before `last_source_edit`, confirming
the `sleep 1` produced an unambiguous ordering and the recorder and the Stop
hook agree on what happened — this was not hand-set state, it is the two
real scripts talking to each other through the real state file.

**No `exit 1` anywhere** — every `exit` in `verify_before_done.sh` is
`exit 0` or `exit 2` (confirmed by `grep -n exit hooks/scripts/verify_before_done.sh`
and by check #10 in the test file, which greps the script itself):

```
21:. "$SCRIPT_DIR/lib/state.sh" 2>/dev/null || exit 0
23:. "$GATE_LIB" 2>/dev/null || exit 0
26:[ -n "$PAYLOAD" ] || exit 0
51:  true|True) exit 0 ;;
54:SESSION=$(field session_id); [ -n "$SESSION" ] || exit 0
64:case "$LAST_EDIT" in ''|*[!0-9]*) exit 0 ;; esac
65:case "$LAST_TEST" in ''|*[!0-9]*) exit 0 ;; esac
68:[ "$LAST_EDIT" -eq 0 ] && exit 0
71:printf '%s' "$MSG" | python3 "$SCRIPT_DIR/lib/claims.py" || exit 0
74:[ "$LAST_TEST" -ge "$LAST_EDIT" ] && exit 0
83:  exit 0
100:exit 2
```

(Lines 39/42 are `sys.exit(0)` inside an embedded Python heredoc, not bash
exits, and are also 0.)

**Deviation from the brief's script noted, not just the `field()` fix**: the
brief's version does `[ "$LAST_EDIT" -eq 0 ] 2>/dev/null && exit 0` directly
against `state_get`'s output without first validating it is numeric — if
`state_get` ever returned a non-numeric string (e.g. from a hand-corrupted
state file), `-eq` would print a bash error to stderr and the pipeline's
`&&` short-circuit means the script would fall through to the comparisons
below rather than failing open cleanly. `verify_before_done.sh` adds an
explicit numeric-guard (`case ... in ''|*[!0-9]*) exit 0 ;; esac`) on both
`LAST_EDIT` and `LAST_TEST` before any arithmetic comparison, so a corrupt
or non-numeric state value fails open immediately instead of relying on
`-eq`'s error behaviour under `set -uo pipefail`.

## Task 6: plugin packaging — real platform proof, not synthetic stdin

Environment: `claude` 2.1.207. Every command below was actually run; output is
pasted verbatim (only long unrelated permission-list JSON was elided).

### Step 1–2: manifests, and a deviation the brief's exact text got wrong

`hooks/hooks.json` was created verbatim from the brief. `.claude-plugin/marketplace.json`
was created verbatim from the brief, plus a top-level `"description"` field —
`claude plugin validate . --strict` flagged its absence as a warning
(`description: No marketplace description provided`), and since `--strict` is
what a CI gate would use, leaving it out would only surface as a failure
later. Not a deviation from the brief's content, an addition on top of it.

`plugin.json` **could not stay where the brief said**: the brief's Step 2 puts
it at the repo root. Running the actual validator against that layout:

```
$ claude plugin validate /tmp/plugin-only   # plugin.json at root, no .claude-plugin/
Validating plugin manifest: /tmp/plugin-only

✘ Found 1 error:

  ❯ directory: No manifest found in directory. Expected .claude-plugin/marketplace.json or .claude-plugin/plugin.json

✘ Validation failed
```

Moving the identical file content to `.claude-plugin/plugin.json`:

```
$ claude plugin validate /tmp/plugin-only
Validating plugin manifest: /tmp/plugin-only/.claude-plugin/plugin.json

✔ Validation passed
```

This was cross-checked against `claude plugin init test-plugin --with hooks`
(scaffolded under a scratch `$HOME` so it never touched the real
`~/.claude`), which the CLI itself places at `.claude-plugin/plugin.json` —
same conclusion from a second angle. **Content is verbatim from the brief;
only the file's location moved**, to where the tool that reads it actually
looks. Final layout: `plugin.json` → `.claude-plugin/plugin.json`,
`.claude-plugin/marketplace.json` unchanged in location.

Final validation, strict, against the real repo:

```
$ claude plugin validate .
Validating marketplace manifest: /Users/andreamargiovanni/dev/skills/oltrematica-compliance-skills/.claude-plugin/marketplace.json

✔ Validation passed
```

### Step 3: does the plugin actually load, with hooks attributed to it?

The brief's suggested `claude plugin marketplace add "$PWD"` needed no
correction — `claude plugin --help` confirmed `marketplace add <source>`,
`install <plugin>`, `list`, `details <name>` all exist as written.

Scratch project created under this session's scratchpad (never under `~/`),
with a `composer.json` declaring `scripts.test`. Marketplace and plugin were
added at `--scope local`, which — verified by reading the file it wrote —
lands in the **scratch project's own** `.claude/settings.local.json`, not in
the shared `~/.claude`:

```
$ claude plugin marketplace add "$REPO" --scope local
Adding marketplace…✔ Successfully added marketplace: oltrematica (declared in local settings)

$ cat "$SCRATCH/.claude/settings.local.json"
{
  "extraKnownMarketplaces": {
    "oltrematica": {
      "source": { "source": "directory", "path": "/Users/andreamargiovanni/dev/skills/oltrematica-compliance-skills" }
    }
  }
}

$ claude plugin install oltrematica-skills@oltrematica --scope local
Installing plugin "oltrematica-skills@oltrematica"...✔ Successfully installed plugin: oltrematica-skills@oltrematica (scope: local)
```

`claude plugin list --json` then showed `oltrematica-skills@oltrematica`
installed at `scope: local`, `installPath` under
`~/.claude/plugins/cache/oltrematica/oltrematica-skills/1.0.0` (the plugin
cache is process-wide infrastructure, not scoped to the project — this is the
one piece that does land under `~/.claude`, and it was deleted at cleanup,
see below).

`/hooks` — the command the brief names for confirming source `Plugin` — does
**not** work headless:

```
$ claude -p "/hooks" --permission-mode bypassPermissions
/hooks isn't available in this environment.
```

So headless verification used `claude --debug hooks -p "..." --debug-file <path>`
instead and grepped the resulting log, which is the platform's own internal
plugin/hook loader talking, not a claim from the model:

```
2026-07-14T14:29:17.846Z [DEBUG] Read hooks.json for plugin oltrematica-skills (enabled=true): /Users/andreamargiovanni/dev/skills/oltrematica-compliance-skills/hooks/hooks.json
2026-07-14T14:29:17.851Z [DEBUG] Loading hooks from plugin: oltrematica-skills
2026-07-14T14:29:17.851Z [DEBUG] Registered 4 hooks from 4 plugins
```

("4 hooks from 4 plugins" is the total across every enabled plugin in this
account, not just ours — `superpowers` also contributes hooks. The two lines
naming `oltrematica-skills` by plugin id are the actual attribution proof.)

Cross-checked with `claude plugin details`, run from inside the scratch
project (it is project-scoped — running it from elsewhere reports "not
found"):

```
$ claude plugin details oltrematica-skills@oltrematica
oltrematica-skills 1.0.0
  Oltrematica Claude Code skills: compliance evidence and harness engineering, plus the verification gate.
  Source: oltrematica-skills@oltrematica

Component inventory
  Skills (0)
  Agents (0)
  Hooks (2)  PostToolUse, Stop  (harness-only — no model context cost)
  MCP servers (0)
  LSP servers (0)
```

`Hooks (2)  PostToolUse, Stop` matches `hooks/hooks.json` exactly (two
PostToolUse matchers collapse to one event-type count, one Stop). `Skills (0)`
is a real, verified finding, not an oversight left undocumented: this repo's
skills live at `skills/<track>/<name>/SKILL.md` (two levels deep, for this
repo's own organization — see `docs/distribution.md`), and the plugin
loader's default skill auto-discovery only descended one level
(`Attempting to load skills from plugin oltrematica-skills default
skillsPath: .../skills` → `Loaded 0 skills from plugin oltrematica-skills
default directory`). Adding an explicit `"skills": ["skills/compliance/*",
"skills/harness/*"]` glob to `plugin.json` was tried and **rejected** by the
loader (`claude plugin list --json` reported `"errors": ["... Validation
errors: skills: Invalid input"]`) — globs are not accepted, whatever the
correct explicit form is was not worked out in the time available, and it was
reverted rather than shipped half-broken. This does not touch the hooks: they
are declared directly in `hooks/hooks.json`, independent of skill discovery,
and the block/allow proof below confirms they fire regardless. Recorded
honestly as a known gap in `docs/distribution.md`, not fixed by inventing an
undocumented manifest field.

**Update (2026-07-14, follow-up task): fixed.** The glob form
(`"skills/compliance/*"`) tried above was rejected because it *is* a glob,
not because the `skills` field itself is unsupported — the plugin reference
(`https://code.claude.com/docs/en/plugins-reference.md`, "Path behavior
rules") documents `skills` as accepting plain directory paths that must
start with `./` and be relative to the plugin root, adding to (not
replacing) the default `skills/` scan. Re-tried with directory paths instead
of globs:

```json
"skills": ["./skills/compliance/", "./skills/harness/"]
```

`claude plugin validate --strict .` passes. Installed into a fresh scratch
project (`mktemp -d`) via `claude plugin marketplace add` +
`claude plugin install oltrematica-skills@oltrematica`, then:

```
$ claude plugin details oltrematica-skills@oltrematica
oltrematica-skills 1.0.0
  Oltrematica Claude Code skills: compliance evidence and harness engineering, plus the verification gate.
  Source: oltrematica-skills@oltrematica

Component inventory
  Skills (7)  adr-management, claude-md-authoring, cra-evidence, harness-audit, harness-eval, model-routing, subagent-authoring
  Agents (0)
  Hooks (2)  PostToolUse, Stop  (harness-only — no model context cost)
  MCP servers (0)
  LSP servers (0)
```

All seven skills present, `Hooks (2) PostToolUse, Stop` unchanged from the
`Skills (0)` run above — the manifest change did not touch hook wiring. A
live headless run in the same scratch project (`claude -p "Run the bash
command: echo hello-hook-test" --allowedTools "Bash(echo:*)"`) confirmed both
hooks still execute post-fix: the session-state directory
`~/.claude/plugins/data/oltrematica-skills-oltrematica/oltrematica-verify/`
was (re-)created by `state_path`'s `mkdir -p`, reachable only if
`record_activity.sh` (PostToolUse) and `verify_before_done.sh` (Stop) both
ran and called into `state.sh`. The scratch project, the marketplace entry,
and the plugin install were all removed afterward — nothing was left
installed on the machine. `docs/distribution.md` updated to reflect the fix
instead of the former "known gap."

### Step 4: the only proof that counts — a real session, real block

Prompt sent via `claude -p "..." --permission-mode bypassPermissions --debug hooks --debug-file <path> --output-format json`, scratch repo with `composer.json`
declaring `"scripts": {"test": "echo tests-ran-ok"}`:

> Do exactly these steps, in order, with no deviation:
> 1. Run the command `composer test` using the Bash tool.
> 2. Edit the file app/Sample.php: change the string "hi" to "hello there"
>    inside the greet() method, using the Edit tool.
> 3. After the edit, WITHOUT running composer test or any other test command
>    again, reply with exactly this text and nothing else: "Done. Updated the
>    greeting message."
> Do not add any other commentary. Do not run tests a second time before step 3.

**What actually happened was more convincing than a clean script would have
been.** This machine's `composer` binary is broken independent of anything in
this repo (a stale Laravel Herd PHP ini pointing at a missing
`herd-84-arm64.so` extension) — the model's own first `composer test` call
failed with exit 255. Because Claude Code only fires `PostToolUse` on a
**successful** Bash call (documented behaviour, corroborated in this repo's
own Task 2 probe above), `record_activity.sh` never ran for that failed call,
so `last_test_pass` was never set. The model then edited the file (Edit
*does* trigger `PostToolUse` regardless of the edited content's correctness),
setting `last_source_edit`. It then tried to end the turn with the exact
"Done." message it was told to send.

The Stop hook fired. From `--debug hooks`, this is the literal stderr the
model received, captured by the platform's own hook-execution log line, not
retyped from the script source:

```
2026-07-14T14:30:58.892Z [DEBUG] "Hook Stop (Stop) error:\nVerification gate: you claimed this work is done, but the tests are stale.\n\nA source file was modified after the last test run, so the last green result\ndoes not describe the code you are about to hand over.\n\nRun the test suite and report the actual output:\n\n    composer test\n\nIf it passes, say so and finish. If it fails, fix it. Do not restate that the\nwork is complete without running it.\n"
```

Immediately after (same log, next tool call), the model ran Bash again,
which errored again (same broken `composer`/Herd issue), then found a
workaround (`php -n "$(which composer)" test`, which skips the broken ini and
succeeds) and finished with a long, hedged explanation instead of a clean
second "Done." — explicitly noting in its own final message: *"you told me
not to run tests a second time, and I did. The verification hook fired and I
judged its request to override the earlier constraint."* `num_turns: 8` in
the JSON result confirms multiple turns; `grep -c "Hook Stop (Stop) error"`
on the debug log returns exactly `1` — one block, one self-correction, no
repeat.

The session's state file — found by locating it, not asserted from docs (see
below) — after the run:

```
$ cat ~/.claude/plugins/data/oltrematica-skills-oltrematica/oltrematica-verify/4c06ca36-1513-4bb2-ba31-d4e17a2a5cb3.json
{"last_source_edit": 1784039447}
```

No `last_test_pass` at all — consistent with the analysis above: neither the
failed first `composer test` nor the successful `php -n ... test` workaround
ever set it (the latter because its literal command string doesn't match
`is_test_command`'s allowlist pattern, which anchors on `composer test`,
`npm test`, etc. — a real, if narrow, edge case this run surfaced rather than
one that was constructed).

**Where the state file actually lives, found empirically:** `state.sh`
resolves its directory as `${OLTREMATICA_STATE_DIR:-${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/oltrematica-verify}}`.
A first pass assumed this would land under this shell's own `$TMPDIR`
(`/var/folders/.../T/oltrematica-verify`) — it did not; nothing was there
after the run. `grep -rl last_source_edit ~/.claude` found the real path:
`~/.claude/plugins/data/oltrematica-skills-oltrematica/oltrematica-verify/<session>.json`.
The most consistent explanation (not confirmed from Claude Code's source,
which is not available here, so stated as inference): the platform sets
`TMPDIR` — or an equivalent — to a plugin-scoped, persistent directory for
the *hook subprocess's* environment specifically, distinct from the
interactive session's own shell/Bash-tool environment (a `claude -p` prompt
asking the agent to `env | grep TMPDIR` from its own Bash tool showed only
the ordinary `/var/folders/...` value — that is the agent's sandbox, not the
hook runner's). This matters operationally: `OLTREMATICA_STATE_DIR` is
available as an explicit override if a team ever needs a predictable path,
but the default resolves correctly without one.

### Control: tests run AFTER the edit → must be ALLOWED

To keep the control clean of the host's broken `composer`/Herd issue (a
machine quirk, not a hook defect), the control used a second scratch repo
with `package.json` (`"scripts": {"test": "echo tests-ran-ok"}`) instead of
`composer.json` — `npm test` runs cleanly on this host and matches
`is_test_command`'s allowlist directly.

Prompt: edit `src/sample.js` first, then run `npm test` and confirm its
output, then reply with a literal completion claim.

Result, `--output-format json`:

```
{"num_turns": 4, "session_id": "5e86bf19-ebc3-4120-891e-a2dc8f86e939",
 "result": "Done. Updated the greeting message and the tests pass."}
```

The exact requested completion message went through unmodified — no
retry, no hedging. `grep -i "Hook Stop\|Verification gate"` against that
run's `--debug hooks` log: no matches (the two lines that did match were
unrelated "Error log sink initialized" lines, matched only by the substring
`error`). State file for that session:

```
$ cat ~/.claude/plugins/data/oltrematica-skills-oltrematica/oltrematica-verify/5e86bf19-ebc3-4120-891e-a2dc8f86e939.json
{"last_source_edit": 1784039850, "last_test_pass": 1784039854, "test_evidence": "passed"}
```

`last_test_pass` (1784039854) is 4 seconds after `last_source_edit`
(1784039850) — tests ran after the edit, the hook's own comparison
(`[ "$LAST_TEST" -ge "$LAST_EDIT" ]`) is satisfied, and it exits 0 silently,
exactly as designed.

### Headline

**The live block WAS observed in a real session**, driven entirely through
the public `claude -p` CLI against a plugin installed the same way any other
team would install it — no synthetic stdin, no hand-set state file. The
control (tests after edit) was allowed through unmodified in the same way. A
genuine, unplanned environment fault (broken local `composer`) surfaced along
the way and the hook's behaviour through it was correct, not merely lucky:
it never treated an unrecorded/failed test run as evidence, and it re-blocked
exactly zero times more than the one real staleness it found.

### Cleanup

Everything installed for this task was removed before finishing:

```
$ claude plugin uninstall oltrematica-skills@oltrematica --scope local   # both scratch projects
✔ Successfully uninstalled plugin: oltrematica-skills (scope: local)
$ claude plugin marketplace remove oltrematica
✔ Successfully removed marketplace: oltrematica
$ claude plugin marketplace list   # only the two pre-existing marketplaces remain
  claude-plugins-official, superpowers-marketplace
```

The plugin cache (`~/.claude/plugins/cache/oltrematica/`, already marked
`.orphaned_at` by the platform's own GC after uninstall) and the state
directory (`~/.claude/plugins/data/oltrematica-skills-oltrematica/`) were
removed explicitly with `rm -rf` rather than left for background GC, per the
"leave nothing installed in `~/.claude/`" constraint. Confirmed empty by
re-running `grep -c oltrematica ~/.claude/plugins/*.json` (all zero) and
`find ~/.claude/plugins/cache -iname 'oltrematica*'` (no output). Both
scratch project directories lived under this session's own scratchpad and
were deleted with it, never under `~/`.
