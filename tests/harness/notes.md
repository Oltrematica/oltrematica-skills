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
