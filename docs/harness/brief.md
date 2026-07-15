# Harness Track — Brief

## Why this track exists

Oltrematica's AI-native pilot rests on a premise that nobody has been checking: that
the harness — the `CLAUDE.md`, skills, subagents, hooks and verification gates a
coding agent runs inside — is any good. Today that harness is folklore. It is
assembled once per repo by whoever set the repo up, never reviewed, never measured,
and it rots silently: a `CLAUDE.md` grows until the agent quietly stops obeying the
half of it that matters, a skill's description drifts until it fires on everything
or on nothing.

The compliance track exists because *compliance fails through friction, not
ignorance* — nobody regenerates an SBOM mid-sprint, not because they doubt it
matters, but because nothing forces the moment. The harness track exists for the
mirror reason: **the harness fails through invisibility.** Nothing tells you it
broke. There is no error message. The agent just gets worse, and the team concludes
the model got worse.

These five skills make the harness a maintained artifact: something you can audit,
author deliberately, and — the part nobody does — **test**.

## The skills

| Skill | Answers |
|-------|---------|
| [`harness-audit`](../../skills/harness/harness-audit/) | What scaffolding does this repo give an agent, and what is missing, across all eight surfaces? |
| [`claude-md-authoring`](../../skills/harness/claude-md-authoring/) | Is this CLAUDE.md policy, or is it a skill (or a hook) in disguise? |
| [`subagent-authoring`](../../skills/harness/subagent-authoring/) | Should this be a skill, a subagent, a command, or a hook? |
| [`harness-eval`](../../skills/harness/harness-eval/) | Does this skill actually fire? Did that harness change actually help? |
| [`model-routing`](../../skills/harness/model-routing/) | Which model tier does this task need, is a subagent the cheaper move, and why do we keep hitting the usage limit? |

`harness-audit` is the entry point. It inventories the repo across eight surfaces —
`CLAUDE.md`, skills, subagents, hooks, slash commands, MCP, the verify gate, and
model routing policy — and hands each gap to the skill that owns the fix.

`model-routing` was added mid-plan, after the first four skills were already in
review: teams kept hitting the five-hour usage limit and assumed the fix was
model choice. It usually isn't.

## Dependency: Superpowers

These skills **assume the [Superpowers](https://github.com/obra/superpowers) plugin
is installed** and deliberately do not re-implement it. Superpowers owns *how to
work*: brainstorming, planning, TDD, systematic debugging, verification, code
review. This track owns *what the harness is made of* and *whether it works*.

Where a harness gap needs one of those workflows, our skills hand off by name
rather than duplicating. Forking them would buy independence and cost us permanent
drift.

## Non-goals

- **No hooks-authoring skill.** Claude Code's built-in `update-config` skill already
  owns `settings.json`. `subagent-authoring` decides *that* you need a hook and hands
  off; it does not hand-edit the file.
- **No MCP-authoring skill.** Out of scope for this track.
- **No skill-authoring skill.** `superpowers:writing-skills` covers it. Our house
  conventions live in [`docs/contributing-skills.md`](../contributing-skills.md).
- **No CI enforcement.** `harness-audit` reports; it does not block a merge. Whether
  it should eventually run in CI — as the compliance track is proposing for its own
  gate — is deferred until the track has run on a real repo.

## The shared contract

Same as the compliance track, for the same reason: **Claude drafts, humans approve**,
and every report is **evidence, never an assertion**. A harness audit that says
"looks good" is worth exactly as much as a compliance dossier that says "we're
compliant" — nothing, and worse than nothing if anyone believes it. That contract is
tested, not just stated: the trigger-validation ledger for these five skills
(`tests/harness/trigger-validation.md`) records every judgement run against their
descriptions, including the splits that were found and the fixes that closed them —
not just the clean final pass.
