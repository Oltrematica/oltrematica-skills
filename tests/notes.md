# Test notes (cross-track)

Evidence for repo-level tooling that belongs to no single track. Track-specific
evidence lives in `tests/compliance/notes.md` and `tests/harness/notes.md`.

## 2026-07-14 — scripts/install.sh

| Step | Test | Result |
|------|------|--------|
| RED | Script missing (`bash tests/install.sh.test` before implementation) | `No such file or directory`, PASS=1 FAIL=9 ✓ |
| GREEN | Full contract, brief's 4 scenarios (10 checks) | PASS=10 FAIL=0 ✓ |
| GREEN | Full suite incl. 4 added scenarios (19 checks) | PASS=19 FAIL=0 ✓ |

Contract verified: resolves a skill by name across tracks; installs to the flat
`.claude/skills/<name>/` path (track dir is *not* recreated in the target);
handles multiple skills per call; exits 1 with the available-skill list on an
unknown name; exits 2 on a missing `--to`.

Additional failure modes exercised beyond the brief's own test (real-world
cases a user would plausibly hit), all passing against the implementation:

- **Target path containing spaces** — properly quoted throughout, so
  `--to "/path/with spaces/target"` installs correctly.
- **Target exists but is a plain file, not a directory** — the brief's
  reference implementation only checked `[ -d "$TARGET" ]`, which would have
  reported the misleading "target repo not found" for a path that *does*
  exist. Added an explicit `[ -e "$TARGET" ] && [ ! -d "$TARGET" ]` check
  that reports "target repo path exists but is not a directory" instead, so
  the error names the actual problem.
- **Relative `--to` path** — resolved from the caller's cwd (the script never
  `cd`s the parent shell), so `--to relhere` from within a project directory
  behaves as expected without requiring an absolute path.
- **Reinstalling over an existing installation** — `rm -rf "$dest"` before
  `cp -R` means a file left over from an older version of the skill (no
  longer present in the source) is correctly dropped on reinstall rather than
  lingering as stale content, while current files are still installed intact.

Note: the brief's Step 4 states "Expected: PASS=8 FAIL=0", but the test code
block it provides contains 10 `check` calls (4 + 2 + 3 + 1 across its four
scenarios), so the correct expectation for the brief's own test is
`PASS=10 FAIL=0`. Confirmed by direct count and by running the script.

## 2026-07-14 — collateral fix while building harness-audit

Scenario 10 ("skill name ambiguous across tracks") built its fixture at
`skills/harness/adr-management/` and its cleanup ran
`rm -rf "$REPO_ROOT/skills/harness"` — safe only while `skills/harness/` had
no real content. Adding `skills/harness/harness-audit/` means running this
test would have deleted that skill. Fixed `cleanup_fixture` to remove only the
fixture subdirectory it creates. Re-ran: `PASS=25 FAIL=0`, and confirmed
`skills/harness/harness-audit/` survives the run intact.
