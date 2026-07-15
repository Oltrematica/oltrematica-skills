# bad-harness fixture

A repo with a deliberately defective Claude Code harness. `harness-audit` and
`harness-eval` are developed and tested against it.

**Do not "fix" these defects.** They are the test.

| ID | Defect | Which skill must catch it |
|----|--------|---------------------------|
| D1 | `CLAUDE.md` is a 190+ line procedure dump — routing, not policy | `harness-audit`, `claude-md-authoring` |
| D2 | No `.claude/agents/` directory | `harness-audit` |
| D3 | No `.claude/settings.json`, therefore no hooks | `harness-audit` |
| D4 | No verify gate — `composer.json` has no `scripts.test` | `harness-audit` |
| D5 | `.claude/skills/do-everything/` triggers on essentially any prompt | `harness-audit`, `harness-eval` |
