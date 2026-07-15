---
name: claude-md-authoring
description: >-
  Write, restructure or debug a CLAUDE.md file at user, project or subdirectory
  scope. Use when a CLAUDE.md is being created or edited ("write a CLAUDE.md for
  this repo", "add this rule to CLAUDE.md", "our CLAUDE.md is too long", "clean up
  our CLAUDE.md"), and when Claude repeatedly ignores or misapplies a documented
  instruction ("the agent keeps forgetting to run the tests", "why is Claude
  ignoring our conventions?", "it keeps doing X even though CLAUDE.md says not
  to") — the usual cause is a CLAUDE.md carrying procedure that belongs in a skill,
  or grown long enough that instructions compete. Enforces CLAUDE.md as policy,
  not routing.
---

# CLAUDE.md Authoring

## The one rule

**CLAUDE.md is policy, not routing.**

*Policy* is what is mandatory in this repo, what is out of scope, and what "done"
means. It is short, imperative, verifiable, and it is loaded into every context
whether or not it is relevant.

*Routing* — "when the user asks about X, do Y" — is what a skill's `description:`
frontmatter already does, and does better. *Procedure* — "how to do X" — is what a
skill body is for.

The test for any line you are about to add: **would this still be true on a task
that has nothing to do with it?** If not, it is not policy, and it should not be
paying rent in every context window.

## Scopes

| File | Holds | Shared with |
|------|-------|-------------|
| `~/.claude/CLAUDE.md` | Personal working habits | Nobody |
| `<repo>/CLAUDE.md` | Team policy for this repo | The team, via git |
| `<repo>/<module>/CLAUDE.md` | Rules binding only inside that module | The team; loaded only when working in there |

Putting a personal preference in a shared file is how a team ends up arguing about
someone's tone preferences in code review. Putting a module rule at repo root is
how you pay for it on every unrelated task.

## Authoring workflow

1. **Read what exists.** Never write over a CLAUDE.md without reading it — some of
   what is in there was hard-won and is load-bearing.
2. **Draft from `assets/claude_md_skeleton.md`.** Fill only the sections that have
   real content. An empty section is worse than a missing one.
3. **Every rule imperative and verifiable.** "Before Y, always check Z" — never
   "be careful with Y". If you cannot state how to check compliance, you cannot
   state the rule.
4. **Route by mandate, not by trigger.** Say *when a skill is mandatory in this
   repo*; never restate what the skill's description already says.
5. **Show the diff and stop.** CLAUDE.md is the human's constitution for the repo.
   Propose; do not merge.

## Diagnostic workflow — "the agent keeps ignoring X"

This is the most common reason this skill gets invoked, and the instinct — *add a
stronger instruction, in caps* — makes it worse. Work the list in order:

1. **Classify every section as policy, procedure, or unverifiable exhortation.**
   Procedure is usually the bulk of it — each procedure section is a skill that has
   not been extracted yet, and extracting it shortens the file *and* makes the
   procedure available on demand, strictly better on both axes. Watch for a third
   category that fits neither: **unverifiable exhortation** — "be careful," "write
   good code," "don't break things." It reads like policy but carries no check, so
   it is not policy — it is noise wearing policy's clothes, diluting the rules that
   do work. It has exactly two honest outcomes: rewrite it as an imperative,
   verifiable rule (step 3 below), or delete it. See `references/antipatterns.md`,
   antipattern #2. This classification also gives you your candidates for the
   next step: procedure and unverifiable-exhortation sections are the ones worth
   testing for removal; policy sections are not.
2. **Measure the length and effect.** `wc -l CLAUDE.md`. The mechanism is not in
   dispute: every line here loads into every context window and competes for the
   same attention — rule 80 competes with rule 3. Whether *your* file has actually
   crossed the point where that competition costs you is not something to assert
   from a line count; it is something to measure. Use `harness-eval`'s
   behavioral-regression mode: trim one of the procedure or unverifiable-exhortation
   sections flagged in step 1, run the same task before and after, and see whether
   anything actually moved. If it did, the fix is subtraction, not emphasis. If it
   didn't, you have learned the section was already dead weight either way.
3. **Ask whether X must hold *every single time*.** If yes, it is not an
   instruction — it is a **hook**. Instructions are probabilistic; hooks are
   deterministic. "Always run the formatter after editing" belongs in
   `settings.json` (use the built-in `update-config` skill), not in prose. This is
   the single highest-value move in this workflow, and it is the one people skip.
4. **Check the scope.** A rule about a module, sitting at repo root, is diluted
   across every task that never touches that module.
5. **Only now, rewrite the rule.** If it survived steps 1–4, it may genuinely be
   badly phrased — vague, unverifiable, or contradicted by another rule elsewhere
   in the file. Contradictions are common in files that have grown by accretion.

Full catalogue with symptoms and fixes: `references/antipatterns.md`.

## Handoffs

This skill authors CLAUDE.md prose. It does not touch anything else:

| Need | Hand off to |
|------|-------------|
| A rule must hold every single time (format, lint, block secrets) | Built-in `update-config` skill — owns `settings.json`. Never hand-edit it here. |
| A procedure section is being extracted into a new skill | `superpowers:writing-skills` (+ `docs/contributing-skills.md` if this repo) |
| A skill's description over- or under-triggers | `harness-eval` |
| The repo needs a subagent, command, or hook design decision | `subagent-authoring` |
| Full harness audit beyond just CLAUDE.md | `harness-audit` |

## What good looks like

Short. Verifiable. Every line earns its place in every context window. If you
cannot say why a section would matter on a task unrelated to it, cut the section.
