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
