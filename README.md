# Oltrematica Compliance Skills

Claude Code skills that produce and maintain compliance evidence (CRA, SBOM,
EAA) and decision records (ADR) across Oltrematica repositories.

**Core contract for every skill here: Claude drafts, humans approve.** No
artifact is ever marked Accepted/Compliant by Claude autonomously.

## Skills

| Skill | Purpose |
|-------|---------|
| [`skills/adr-management`](skills/adr-management/) | Drafts Architecture Decision Records proactively whenever a significant decision is made; human reviews and approves. |
| [`skills/cra-evidence`](skills/cra-evidence/) | Generates the CRA evidence package: SBOM (CycloneDX), SBOM release diff, vulnerability scan + triage drafts, Annex I gap report, EAA/WCAG accessibility module. |

## Install (per repo)

Copy the skill directory into the target repo:

```bash
cp -R skills/cra-evidence /path/to/repo/.claude/skills/cra-evidence
cp -R skills/adr-management /path/to/repo/.claude/skills/adr-management
```

Full options (submodule, personal scope, future plugin) in
[`docs/distribution.md`](docs/distribution.md).

## Repo map

- `skills/` — the distributable skills
- `docs/` — program brief, distribution guide, CI gate proposal, rollout note
- `tests/` — fixture repos and test notes (living documentation)

## Program context

Driven by the Oltrematica Compliance Skills Program
([`docs/development-brief.md`](docs/development-brief.md)). Regulatory
deadlines: CRA vulnerability-reporting obligations from **2026-09-11**; full
CRA obligations from **2027-12-11**; EAA already in force since 2025-06-28.

## License

Proprietary — Copyright © 2026 Oltrematica. All rights reserved. See
[LICENSE](LICENSE).
