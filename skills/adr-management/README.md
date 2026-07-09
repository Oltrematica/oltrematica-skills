# ADR Management Skill

A [Claude Code](https://claude.com/claude-code) skill that makes **Claude draft your Architecture Decision Records automatically**, so decision history stops getting lost. The human only reviews and approves — Claude does the writing.

The failure mode of every ADR process is friction: people forget to write records, and the *why* behind a system disappears. This skill inverts that workflow: whenever an architecturally significant decision is made or discovered during any task, Claude proactively drafts an ADR (status `Proposed`) and tells you afterwards. You approve it in chat or in the PR, and Claude flips it to `Accepted`.

## What it does

- **Drafts ADRs proactively** — no need to say the word "ADR". Choosing or replacing a library, a database/schema strategy, an API design, an auth approach, an infra or CI/CD change, a migration or breaking change → Claude writes the record as part of the task.
- **Keeps humans in control** — every ADR starts as `Proposed`. Claude never marks one `Accepted` or `Rejected` on its own; only after your explicit confirmation.
- **Treats accepted ADRs as immutable** — a changed decision becomes a *new* ADR that supersedes the old one, with cross-links, rather than a rewrite.
- **Locates or initializes the ADR directory** — respects `.adr-dir`, `docs/adr/`, `docs/decisions/`, etc., and bootstraps one (with an index and a meta ADR-0001) if none exists.
- **Maintains an index table** and manages the full lifecycle: `Proposed → Accepted | Rejected`, later `Deprecated` or `Superseded by`.
- **Answers "why" questions** by checking the ADR index before reconstructing an answer from code.
- **Backfills decision history** for existing codebases from git history, on request.

## Contents

| File | Purpose |
|------|---------|
| [SKILL.md](SKILL.md) | The skill itself — the full workflow, significance test, and lifecycle rules Claude follows. |
| [scripts/new_adr.sh](scripts/new_adr.sh) | Deterministic ADR creation: next sequential number, kebab-case slug, file from template. |
| [assets/template.md](assets/template.md) | The ADR template (Context / Decision / Alternatives / Consequences). |

## Installation

This skill now lives in the
[`oltrematica-compliance-skills`](https://github.com/Oltrematica/oltrematica-compliance-skills)
repo. Install it in one of two scopes:

### Per project (shared with the team via git)

```bash
cp -R skills/adr-management /path/to/your-project/.claude/skills/adr-management
```

### For your user account (available in every project)

```bash
cp -R skills/adr-management ~/.claude/skills/adr-management
```

See [`docs/distribution.md`](../../docs/distribution.md) for submodule and
plugin options.

### Verify

Restart Claude Code (or start a new session) and run `/skills` —
`adr-management` should appear. No build step, no dependencies:
`new_adr.sh` only needs `bash`, `sed`, and `find` (present on macOS and Linux).

## How it behaves once installed

You don't invoke anything explicitly. During normal work, when a decision crosses the significance bar, Claude drafts the ADR and reports back — for example:

> Done — sessions now use Redis (config in `config/session.php`).
> I also drafted **ADR-0012: Move session storage to Redis** (`docs/adr/0012-move-session-storage-to-redis.md`) covering the alternatives we ruled out. It's `Proposed` — approve it in the PR and I'll flip it to `Accepted`.

You can also trigger it directly: "document this decision", "why did we choose X?", or "backfill our decision history from git".

## License

Proprietary — Copyright © 2026 Oltrematica. All rights reserved. See the
repository [LICENSE](../../LICENSE).
