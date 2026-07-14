---
name: harness-audit
description: >-
  Audit, bootstrap or improve a repository's Claude Code harness as a whole — the
  CLAUDE.md, skills, subagents, hooks, slash commands, MCP servers and
  verification gate that coding agents run inside. Use when onboarding a repo to
  agentic development ("set up Claude Code for this repo", "onboard this
  project", "get this repo ready for Claude"), when the harness's overall
  completeness or quality is in question ("is our Claude setup any good?",
  "audit our harness", "what's missing from our .claude directory?"), or when an
  agent keeps underperforming in a repo and the cause may be missing or rotten
  scaffolding rather than the task itself. A complaint about one file's content or
  length (e.g. "our CLAUDE.md is too long") is not a harness audit — that belongs
  to CLAUDE.md authoring. Produces a present/gap/not-applicable report — never a
  bare "looks good".
---

# Harness Audit

The entry point to the harness track. It answers one question — *what scaffolding
does this repo give a coding agent, and what is missing?* — and hands the fixing
to the skill that owns each surface.

## Core contract

1. **Claude drafts, humans approve.** The report ships as `Proposed`. Never mark a
   harness "compliant", "healthy" or "done" on your own initiative.
2. **Facts from the script, judgement from you.** `scripts/inventory.sh` reports
   what exists. It never judges. You classify. Do not eyeball the filesystem and
   skip the script — the script is what makes the facts reproducible.
3. **Three states, no fourth.** Every surface is **present**, a **gap**, or **not
   applicable**, each with a stated reason. "Looks fine" is not a state.
4. **One review batch.** Audit all seven surfaces, then present *one* report. Do
   not interrupt the human seven times.

## Workflow

### 1. Inventory (deterministic)

```bash
scripts/inventory.sh <repo-root>
```

Returns JSON with seven keys: `claude_md`, `skills`, `agents`, `hooks`,
`commands`, `mcp`, `verify_gate`. If the script cannot run, say so and stop —
do not fall back to guessing.

### 2. Classify each surface

| Surface | Present when | Gap when | Typically N/A when |
|---------|--------------|----------|--------------------|
| **CLAUDE.md** | Exists, and is policy: scope, mandates, exceptions, what "done" means here | Absent, **or** it is procedure/routing rather than policy, **or** it is long enough that the agent demonstrably drops parts of it | Never — every repo an agent works in needs one |
| **Skills** | The repo's recurring procedures are skills | Procedures live in CLAUDE.md prose instead, or a skill's description is so broad it fires on everything | A repo with no recurring agent procedures |
| **Subagents** | Isolated-context work (research, review) has a definition in `.claude/agents/` | Heavy read-only work is done in the main context, blowing the window | Small repos where nothing needs isolation |
| **Hooks** | Things that MUST happen every time (format, lint, block secrets) are hooks | Those things are written as CLAUDE.md instructions and therefore sometimes skipped | No deterministic must-run steps |
| **Slash commands** | Frequent human-fired prompts are commands | The team pastes the same prompt repeatedly | No repeated prompts |
| **MCP** | Configured where external systems are genuinely needed | An external system is accessed by ad-hoc shell instead | No external system in the loop — the common case |
| **Verify gate** | A declared way to run the tests, and CLAUDE.md says it must pass before "done" | No test command, or one that nobody told the agent to run | A repo with no executable code |

**Line count is a signal, not a verdict.** A long CLAUDE.md is evidence to
investigate, not an automatic gap. Read it and ask: is this *policy* (what is
mandatory here) or *procedure* (how to do a thing)? Procedure is a skill wearing
a CLAUDE.md costume — that is the gap.

### 3. Report

Fill `assets/audit_report_template.md`. Write it to `docs/harness-audit.md` in the
target repo unless the human says otherwise. Lead with a plain-language paragraph:
a tech lead who has never opened `.claude/` should understand the state of things
without reading the table.

### 4. Hand off the fixes — do not do them here

This skill diagnoses. It does not author.

| Gap | Hand off to |
|-----|-------------|
| CLAUDE.md missing, bloated, or full of procedure | `claude-md-authoring` |
| Needs a subagent, a command, or a hook | `subagent-authoring` |
| A skill's description over- or under-triggers | `harness-eval` |
| Needs a new skill written | `superpowers:writing-skills` (+ `docs/contributing-skills.md`) |
| No verify gate | The built-in `verify` skill bootstraps one |
| Hooks need wiring into settings.json | The built-in `update-config` skill owns settings.json |

Propose the handoffs in priority order and let the human pick. Do not silently
chain into four skills and rewrite the repo.

## Bootstrap mode (empty harness)

When a repo has no `.claude/` at all, the audit is trivially "all gaps" — say so
in one line and move straight to proposing the minimum viable harness, in this
order:

1. **CLAUDE.md** — policy only. Without it nothing else lands.
2. **Verify gate** — the agent must know how to prove its work.
3. **Skills** — only for procedures that actually recur. Do not invent three
   speculative skills on day one.
4. Everything else, later, driven by observed friction rather than by this list.

Resist installing the full seven surfaces on a repo that needs two. An unused hook
is a liability; an unused MCP server is a bigger one.
