---
name: adr-management
description: >-
  Create and maintain Architecture Decision Records (ADRs) in any repository,
  with Claude drafting and the human only reviewing. Use this skill whenever an
  architecturally significant decision is made, discussed, or discovered during
  any task — choosing or replacing a library/framework, database or schema
  strategy, API design, authentication/authorization approach, infrastructure or
  hosting changes, CI/CD pipeline design, migration strategies, breaking
  changes, deprecations, security or compliance tradeoffs — even if the user
  never says the word "ADR". Also use it when the user mentions ADRs, decision
  records, "document this decision", "why did we choose X", or asks to backfill
  decision history for an existing codebase.
---

# ADR Management

Architecture Decision Records capture *why* a system is the way it is. The failure mode of every ADR process is friction: humans forget to write them, so the history is lost. This skill inverts the workflow: **Claude drafts every ADR proactively; the human only reviews and approves.**

## Core contract

1. **Claude drafts, the human decides.** Every ADR Claude creates starts with status `Proposed`. Claude NEVER sets an ADR to `Accepted` or `Rejected` on its own initiative — only after explicit human confirmation (in chat, in PR review, or by the human editing the status themselves).
2. **Don't ask permission to draft.** If a decision meets the significance bar (below), draft the ADR as part of the task and tell the user afterwards: "I also drafted ADR-0007 for the switch to Redis-backed queues — review when you can." Drafting is cheap; a lost decision is not.
3. **Accepted ADRs are immutable.** Never rewrite the Context or Decision of an accepted ADR. If the decision changes, create a *new* ADR that supersedes the old one and cross-link both.

## When to draft an ADR (significance test)

Draft one when the decision meets **any** of these:

- It constrains the structure of the system (architecture, module boundaries, data model)
- It is expensive or disruptive to reverse (migrations, framework choices, hosting)
- It has non-obvious rejected alternatives worth remembering
- It affects cross-cutting concerns: security, compliance (GDPR, AI Act, CRA, NIS2...), performance, accessibility
- A developer joining in six months would plausibly ask "why is it like this?"

Do NOT draft ADRs for: routine bug fixes, formatting/style choices, dependency patch bumps, decisions that are trivially reversible and local to one file. When in doubt at the margin, draft it — a short `Proposed` ADR the human rejects costs one minute of review.

## Workflow

### 1. Locate (or initialize) the ADR directory

Check in this order, use the first that exists:

1. Path in a `.adr-dir` file at repo root (adr-tools convention)
2. `docs/adr/`
3. `docs/decisions/`
4. `adr/` or `doc/adr/`

If none exists, create `docs/adr/` plus an index file `docs/adr/README.md` (see "Index" below), and mention the initialization to the user.

### 2. Create the record

Use `scripts/new_adr.sh` for deterministic numbering and file creation:

```bash
scripts/new_adr.sh "Use Redis for queue backend"
# → creates docs/adr/0007-use-redis-for-queue-backend.md from the template, prints the path
```

If the script isn't practical in the environment, do the same by hand: next 4-digit sequential number, kebab-case slug of the title, file created from `assets/template.md`.

Then fill in the template (structure in `assets/template.md`):

- **Title**: imperative and specific — "Use Redis for queue backend", not "Queues".
- **Context**: the forces at play — requirements, constraints, what triggered the decision. Facts, not justification. Include compliance constraints when relevant (data residency, audit requirements, etc.).
- **Decision**: one or two sentences, active voice: "We will...".
- **Alternatives considered**: every option seriously evaluated, each with the one-line reason it lost. This section is the main value of the document — be honest about tradeoffs.
- **Consequences**: both positive and negative, including new obligations created (things to monitor, migrations to schedule, skills the team must acquire).
- Keep the whole record under one page. An ADR nobody reads is worse than none.

**Language**: match the language of the repo's existing docs; default to English.

### 3. Maintain the index

`README.md` in the ADR directory holds a table:

```markdown
# Architecture Decision Records

| ID | Title | Status | Date |
|----|-------|--------|------|
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted | 2026-01-12 |
| [0007](0007-use-redis-for-queue-backend.md) | Use Redis for queue backend | Proposed | 2026-07-09 |
```

Update the index row whenever an ADR is created or changes status. If the directory has no index, create one from the existing files.

### 4. Review and lifecycle

Statuses: `Proposed` → `Accepted` | `Rejected`; later possibly `Deprecated` or `Superseded by [NNNN](file)`.

- When the human approves (says so in chat, approves the PR, thumbs-up on the specific ADR), update status to `Accepted` and set the date.
- When a new decision replaces an old one: create the new ADR, set the old one's status to `Superseded by [NNNN](...)`, and add "Supersedes [MMMM](...)" to the new one. Update both index rows.
- In a branch/PR workflow, commit the ADR **in the same PR as the change it documents**, so the review happens where the code review already happens. In direct-commit workflows, commit the ADR with a message like `docs(adr): propose 0007 use redis for queue backend`.

### 5. Answering "why" questions

When the user asks why something is the way it is ("why are we on Hetzner?", "why Laravel and not keeping Python?"), check the ADR index **before** reconstructing an answer from the code. If an ADR exists, quote and link it. If none exists and the answer required real archaeology, offer to backfill an ADR so the next person doesn't repeat the dig.

## Retroactive mode (backfilling)

When asked to backfill decision history for an existing codebase:

1. Gather evidence: `git log --oneline --reverse`, merge commits, changes to lockfiles/config/infra files, README history.
2. Identify the significant decisions using the significance test above.
3. Draft one ADR per decision with the **original date** (from git) in the Date field and a note `Backfilled on YYYY-MM-DD from git history` under it.
4. Mark backfilled ADRs of decisions that are clearly in force as `Proposed` anyway — the human confirms the reconstruction is accurate, then flips them to `Accepted`.
5. Present the batch as a single list for review, not one interruption per ADR.

## Bootstrap ADR

When initializing a fresh ADR directory, ADR 0001 should be "Record architecture decisions" — a short meta-record stating the team will use ADRs, where they live, and the review rule (Claude drafts, humans approve). This gives the process itself a paper trail.

## Example interaction

**Situation**: while implementing a feature, Claude and the user settle on moving session storage from files to Redis to support horizontal scaling.

**Wrong**: finish the code, say nothing about documentation.

**Right**: finish the code, then:

> Done — sessions now use Redis (config in `config/session.php`).
> I also drafted **ADR-0012: Move session storage to Redis** (`docs/adr/0012-move-session-storage-to-redis.md`) covering the file-based and database alternatives we ruled out. It's `Proposed` — say the word or approve it in the PR and I'll flip it to `Accepted`.
