---
name: Skill proposal
about: Propose a new skill, or a change to an existing skill's trigger/behavior
title: "feat(scope): short description"
labels: enhancement
assignees: ''
---

## The capability

One sentence: what does this skill do that no existing skill in this repo
does? (If you can't state it in one sentence without an "and", it might be
two skills — see [`CONTRIBUTING.md`](../../CONTRIBUTING.md)'s "one skill,
one capability" rule.)

## Track

- [ ] `compliance` (GDPR / CRA / PLD / AI Act / EAA evidence)
- [ ] `harness` (auditing/authoring the Claude Code setup itself)
- [ ] Neither — propose a new track (explain why the existing two don't fit)

## Trigger phrasings — the part we will actually test

The `description:` frontmatter is the *only* thing Claude sees when
deciding whether to invoke a skill — the body is invisible at trigger time.
So the trigger surface is what gets reviewed and tested, not the
implementation. Give us real phrasings, in a user's own words, not abstract
categories.

**Prompts this skill MUST fire on** (at least 5, in the user's own words —
not paraphrases of your description):

1.
2.
3.
4.
5.

**Prompts this skill must NOT fire on** (at least 5 — include anything that
sits near a neighboring skill's territory, since cross-triggering between
adjacent skills is the failure mode that actually happens):

1.
2.
3.
4.
5.

## What it produces

The concrete artifact(s): a file path, a report format, a status field. State
whether anything it produces could ever be marked `Accepted`/`Compliant` on
its own initiative (it should not be — see the "evidence, never assertion"
rule).

## Dependencies

Confirm: `bash` (portable, macOS-3.2-safe) or `python3` stdlib only, no new
runtime dependency. If you believe an exception is warranted, say why here —
it will need explicit maintainer sign-off before the PR can be considered.

## Anything else

Prior art, related issues, a sketch of the SKILL.md structure if you have
one.
