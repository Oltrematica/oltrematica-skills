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
