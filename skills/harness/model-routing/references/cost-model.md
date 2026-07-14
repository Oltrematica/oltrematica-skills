# Cost model — verification trail and worked examples

This file exists so the claims in SKILL.md are checkable, not just assertable.
Every mechanic in SKILL.md's "Claude Code mechanics" section was verified
against Claude Code's official documentation (`code.claude.com/docs`) at the
time this skill was written, independently, via two routes: a dispatch of the
`claude-code-guide` agent, and a direct fetch of the relevant docs pages. Both
routes agreed. Docs move; if a claim below looks stale, re-verify against
`/help` or the live docs rather than trusting this file indefinitely.

## Verified mechanics and their source

| Mechanic | Exact syntax | Source |
|---|---|---|
| Switch model mid-session | `/model <alias\|name>`, no argument opens a picker | `model-config.md`, "Setting your model" |
| Switch model at launch | `--model <alias\|name>` | `model-config.md`, "Setting your model" |
| Switch model via environment | `ANTHROPIC_MODEL=<alias\|name>` | `model-config.md`, "Setting your model" |
| Switch model via settings file | `"model": "<alias>"` | `model-config.md`, "Setting your model" |
| Model aliases | `haiku`, `sonnet`, `opus`, `fable`, `best`, `opusplan` | `model-config.md`, "Model aliases" |
| Subagent model pin | `model:` frontmatter field in `.claude/agents/*.md`; values `sonnet`, `opus`, `haiku`, `fable`, a full model ID, or `inherit` (default) | `sub-agents.md`, "Supported frontmatter fields" and "Choose a model" |
| Per-dispatch model override | Claude Code accepts a per-invocation `model` parameter when a subagent is dispatched, resolved above the frontmatter pin but below `CLAUDE_CODE_SUBAGENT_MODEL` | `sub-agents.md`, "Choose a model" |
| Effort level | `/effort <level>` or `--effort <level>`; levels `low`, `medium`, `high`, `xhigh`, `max` (model-dependent; `ultracode` is a distinct Claude-Code-orchestration setting, not a plain effort level) | `model-config.md`, "Adjust effort level" |
| Fast mode | `/fast` toggles it; **Opus-only**; same model, same quality, **higher** per-token price, lower latency | `fast-mode.md` — quoted directly: "Fast mode is not a different model. It uses Claude Opus with a different API configuration that prioritizes speed over cost efficiency." |
| Usage/cost visibility | `/usage` (alias `/cost`) | `commands.md` |
| Context visibility | `/context [all]` | `commands.md` |
| Context compaction | `/compact [instructions]` | `commands.md` |

## What was considered and dropped

Nothing was dropped from the initial verification pass — the seven mechanics
the brief asked to confirm (session model switch, subagent frontmatter pin,
per-dispatch override, effort control, fast mode's real behavior, current
model names/positioning, and usage/context visibility) all checked out against
primary documentation with exact syntax. Anything not in the table above and
not in SKILL.md was deliberately left out of the skill body even though it
came up during research (for example, `opusplan`'s plan/execution split,
`CLAUDE_CODE_SUBAGENT_MODEL`, and organization-level effort/model caps) — it
is real and verified, but it is admin/organization-level configuration, not a
lever an individual developer reaches for when routing a single task, and
including it would have diluted the four levers that matter day to day.

## Worked example — the diagnostic in use

**Symptom:** "I hit the limit by 1pm and I was only doing code review."

**Applying the list in order:**

1. *How long is the conversation?* One session, open since 9am, covering three
   unrelated PRs. This is already the likely answer — three tasks' worth of
   context, all still resident, all re-sent on every turn of the third PR's
   review.
2. *What's in the context that never needed to be?* The developer pasted the
   full diff of a 2,000-line PR directly into the conversation instead of
   letting a subagent read it and return findings. That diff has been re-sent
   on every turn since.
3. *What model is doing the mechanical work?* Opus, for all three PRs,
   including the two that were small and mechanical. A contributing factor,
   but not the leading one here.
4. *Is work being re-done?* Some — the developer re-pasted a file to "remind"
   the model of it partway through PR 2, doubling that file's presence in
   context.
5. *Is the task genuinely large?* No — three ordinary PR reviews should not
   have consumed a 5-hour allowance by 1pm.

**Diagnosis:** the session, not the model. Fix: one session per PR, and route
the diff through a review subagent (see `subagent-authoring`) so the 2,000
lines live in the subagent's context and only its findings return to the main
conversation. Model tier is a secondary fix here, not the primary one.

## Worked example — the counter-rule in use

**Symptom:** "I switched everything to Haiku like the routing table said, and
it's not actually saving anything."

**What's likely happening:** the task being routed to Haiku is not genuinely
mechanical — it requires the model to infer intent from a loosely specified
prompt, gets it wrong, and the developer corrects it, then corrects it again.
Three turns at Haiku's price can still exceed one turn at Sonnet's, because
each of those three turns re-sent the whole conversation. The routing table's
first row requires *both* "mechanical" and "fully specified" — a task that
fails the second test does not belong on the cheapest tier just because it
looks simple, and forcing it there is where "always use the cheap model"
backfires exactly as the counter-rule predicts.
