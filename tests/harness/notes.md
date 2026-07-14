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

But the empirical evidence is stronger and more useful than the brief
anticipated: **`PostToolUse` (matcher `Bash`) is not invoked at all when the
underlying command exits non-zero.** This was reproduced six times, with
command order varied, in isolation, and with realistic test-runner-shaped
stdout, with zero exceptions. This is a mechanical fact about *when the hook
fires*, not a value read out of its payload, so it does not fall foul of the
brief's "no string-matching heuristics" warning — nothing is parsed or
inferred from output text; the signal is "did the hook fire for a
test-matching command in this turn, yes or no."

**Design consequence for Task 3 (`record_activity.sh`):** because a failing
Bash command never reaches the hook, if the hook fires for a command matching
the test-runner pattern, that command exited zero (in this Claude Code CLI
version — see caveat below). `record_activity.sh` may therefore record
`test_evidence="passed"` for a matching invocation, *not* by inspecting a
field, but by the simple fact of having been invoked at all for that command.
No `test_evidence="ran"`-only degradation is required by the current
platform behavior.

**Caveat — must be stated loudly per the brief, and is:** this is
version-specific, undocumented harness behavior of Claude Code CLI
`2.1.207`, discovered empirically, not documented API contract. If a future
Claude Code version starts invoking `PostToolUse` on failing Bash calls (e.g.
to let hooks react to failures), `record_activity.sh`'s "fired ⇒ passed"
inference would then be wrong — it would need to move to whatever field the
new version adds. This caveat is repeated in `hooks/scripts/lib/state.sh`'s
header comment and must also be carried into `record_activity.sh`'s
implementation notes (Task 3), its block message wording, and the rollout
note (Task 6+), per the brief's instruction to say this loudly rather than
claim a stronger guarantee than we have.

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
