# Oltrematica Skills

Claude Code skills for the Oltrematica portfolio, in two tracks:

- **Compliance** — produce and maintain regulatory evidence (CRA, SBOM, EAA) and
  decision records.
- **Harness** — build, operate and evaluate the agent harness itself: the
  `CLAUDE.md`, skills, subagents, hooks and verification gates that coding agents
  run inside.

**The contract shared by every skill here: Claude drafts, humans approve.** No
artifact is ever marked Accepted, Compliant, or Passing by Claude autonomously,
and every report states its evidence rather than asserting a verdict.

## Compliance track

| Skill | Purpose |
|-------|---------|
| [`adr-management`](skills/compliance/adr-management/) | Drafts Architecture Decision Records proactively whenever a significant decision is made; the human reviews and approves. |
| [`cra-evidence`](skills/compliance/cra-evidence/) | Generates the CRA evidence package: SBOM (CycloneDX), SBOM release diff, vulnerability scan + triage drafts, Annex I gap report, EAA/WCAG accessibility module. |

Regulatory clock: CRA vulnerability-reporting obligations from **2026-09-11**;
full CRA obligations from **2027-12-11**; EAA in force since 2025-06-28.
Background in [`docs/compliance/development-brief.md`](docs/compliance/development-brief.md).

## Harness track

*Planned — see [the design spec](docs/superpowers/specs/2026-07-14-harness-skills-track-design.md).*

| Skill | Purpose |
|-------|---------|
| `harness-audit` | Inventories a repo's harness surfaces and reports present / gap / not applicable. |
| `claude-md-authoring` | Writes and repairs `CLAUDE.md` — policy, not routing. |
| `subagent-authoring` | Chooses between skill, subagent, command and hook — then authors it. |
| `harness-eval` | Proves a skill fires when it should, and that a harness change actually helped. |

These skills assume the [Superpowers](https://github.com/obra/superpowers) plugin
is installed. They deliberately do not re-implement planning, TDD, debugging or
code review — Superpowers owns those.

## Install

```bash
git clone https://github.com/Oltrematica/oltrematica-skills.git /tmp/os
/tmp/os/scripts/install.sh adr-management cra-evidence --to /path/to/your-repo
```

Skills install to `.claude/skills/<name>/`. Commit that directory so the team
gets them on pull. Full options — personal scope, submodule, updating — in
[`docs/distribution.md`](docs/distribution.md).

## Repo map

| Path | Contents |
|------|----------|
| `skills/compliance/` | Compliance-track skills |
| `skills/harness/` | Harness-track skills |
| `scripts/install.sh` | Track-aware installer |
| `docs/` | Distribution, contributing conventions, per-track briefs |
| `tests/` | Fixture repos, trigger validation, test evidence (living documentation) |

## Contributing a skill

Read [`docs/contributing-skills.md`](docs/contributing-skills.md) first. It is
short, and it is binding.

## License

Proprietary — Copyright © 2026 Oltrematica. All rights reserved. See
[LICENSE](LICENSE).
