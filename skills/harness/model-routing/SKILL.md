---
name: model-routing
description: >-
  Decide which Claude Code model tier or effort level a task needs, whether to
  delegate it to a subagent instead of doing it inline, and diagnose why a
  session is burning through its usage allowance. Use when cost or the usage
  limit comes up in the user's own words ("why do I keep hitting the usage
  limit?", "this is burning through my usage", "we hit the limit before the 5
  hours were up", "how do I make Claude Code cheaper", "which model should I
  use for this?", "can we use a cheaper model for this task", "should this run
  on Opus or Haiku?", "is fast mode cheaper?"). Explains the real cost
  mechanism — context length times turns, not prompt count — and gives a
  routing table from task shape to model tier, plus the counter-rule that a
  cheap model taking extra turns can cost more than a capable one. Does not
  cover how to write a subagent file, or the skill/subagent/command/hook
  choice itself — that is `subagent-authoring`; this skill only judges whether
  delegating is the cheaper move and which tier to send work to, once that
  choice is made elsewhere. Does not cover CLAUDE.md structure or authoring
  ("our CLAUDE.md is too long") — that is `claude-md-authoring` — and does not
  cover a general harness audit or a skill's trigger accuracy — those are
  `harness-audit` and `harness-eval`.
---

# Model Routing

Two jobs. First, teach the routing decision — which model tier, which effort
level, and whether the work belongs in a subagent instead of the main
conversation. Second, diagnose the complaint that actually brings people here:
*"I hit the usage limit before the 5 hours were up."*

This skill does not enforce anything — it cannot. Enforcement is a CLAUDE.md
policy block (`assets/claude_md_snippet.md`), which a repo either adopts or
doesn't.

## The one idea that matters

**Usage is context length × turns, not number of prompts.**

Every turn re-sends the whole conversation back to the model — that is how a
stateless API call carries a multi-turn conversation at all. A long context
is not paid once; it is paid again on every subsequent turn. That is the
entire reason `/context` exists (to show what is silently costing you on
every turn) and `/compact` exists (to summarize the conversation and shrink
what gets re-sent).

This is why a developer who keeps one giant session open all afternoon,
pasting file dumps and command output into it, hits the limit before lunch —
while someone doing *more total work* in short, delegated bursts does not.
The first person is paying for the same 40 files again on turn 30 that they
paid for on turn 3. The second person's subagents read those files in their
*own* context and returned only a conclusion; nothing accumulated in the
session that has to be re-sent.

Read this before reaching for "use a cheaper model" — that lever exists, and
it matters, but it is not where most of the waste is.

## The three levers, in order of how much they actually save

1. **Delegate read-heavy work to a subagent.** A survey of 40 files costs the
   main conversation almost nothing if a subagent reads them and returns only
   the conclusion — the 40 files live in the subagent's own context, not
   yours, and are never re-sent. Done inline, those 40 files sit in your
   context for the rest of the session and are re-paid on every later turn.
   This is `subagent-authoring`'s territory for *how* to build the subagent;
   here the question is simpler — is this read-heavy, disposable-after-the-answer
   work? If yes, it belongs in a subagent regardless of which model runs it.
2. **Route the task to the right tier.** Most tasks are not architecture. A
   mechanical, fully-specified edit does not need the most capable model
   available. See the routing table below.
3. **Keep the main context clean.** Don't paste large outputs into the
   conversation when a subagent could fetch and summarize them; don't
   re-read a file already in context; run `/compact` or start a fresh
   session when the task changes rather than dragging an old one along.

## The routing table

| Task shape | Tier | Why |
|---|---|---|
| Mechanical, fully specified (transcribe a spec, apply a rename, boilerplate) | Cheapest (`haiku`) | There is no judgement to make. Paying for reasoning you don't use is pure waste |
| Integration, multi-file, debugging, pattern-matching | Mid (`sonnet`) | Needs judgement, but not deep design |
| Architecture, design, hard review, subtle correctness | Most capable (`opus`, or `fable` for the hardest/longest-running work) | A wrong architectural call costs more than every token saved by going cheap |

### The counter-rule — read this before routing anything to the cheapest tier

**Turn count beats token price.** A cheap model that takes three times the
turns on a multi-step task costs *more* than a capable one that gets it right
first time, because every one of those extra turns re-sends the whole
context (the mechanism above). So:

- Use the cheapest tier when the task is genuinely mechanical **and the
  instructions are complete** — no back-and-forth needed to clarify intent.
- Use a mid tier as the floor for anything that requires multi-step work from
  a prose description, because a mid-tier model that finishes in one pass
  usually beats a cheap one that needs three retries.

**"Cheapest model" is not the goal. "Least total cost to a correct result"
is.** A reader who comes away from this skill thinking "always use Haiku" has
learned the wrong lesson.

## Diagnostic: "I keep hitting the usage limit"

Work the list in this order — it is ordered by how often each is the real
cause, which is *not* the order most people assume:

1. **How long is the conversation?** One long session carrying unrelated
   tasks is the usual culprit; every turn pays for all of it. Check `/context`
   to see what's actually sitting in the window. Fix: finish the task, then
   start a fresh session rather than continuing an old one into new work.
2. **What is in the context that never needed to be there?** Pasted file
   dumps, large command output, whole files read where a `grep` would have
   answered the question. Fix: delegate to a subagent, which reads in *its*
   context and returns only the answer — see lever 1 above.
3. **What model is doing the mechanical work?** If the answer is "the most
   capable one, for everything," that is the second-biggest lever — apply
   the routing table.
4. **Is work being re-done?** Re-reading a file already in context,
   re-running the same search, re-deriving something a plan already decided.
5. **Only then: is the task genuinely large?** Sometimes it is. The fix is to
   decompose it into smaller delegated pieces, not to micro-optimize model
   choice on a task that was always going to be big.

Model choice is **third**, not first. A developer who burns the budget by
lunchtime is usually not losing it to model choice — they are losing it to a
context they never cleaned. Say that plainly when this comes up; sending
someone straight to "switch to Haiku" without checking session length first
sends them to optimize the wrong thing.

## Claude Code mechanics

Every mechanic below was verified against current Claude Code documentation
before being written down — see the report accompanying this skill's
introduction for the verification trail. If Claude Code's behavior has
changed since, the primary source is the product's own docs and `/help`, not
this file.

**Changing the model for a session** — `/model <alias|name>` switches
immediately (no argument opens a picker); `--model <alias|name>` sets it at
launch; the `ANTHROPIC_MODEL` environment variable and the `model` key in a
settings file set it more durably. Aliases: `haiku`, `sonnet`, `opus`,
`fable`, plus `best` (picks the strongest available) and `opusplan` (uses
`opus` during plan mode, then switches to `sonnet` for execution — a
built-in version of lever 2 above).

**Pinning a subagent's model** — the `model:` field in a `.claude/agents/*.md`
subagent's frontmatter. Valid values: `sonnet`, `opus`, `haiku`, `fable`, a
full model ID, or `inherit` (the default when the field is omitted, meaning
"use the main conversation's model"). Authoring the subagent file itself is
`subagent-authoring`'s job — this is only the field that controls cost.

**Overriding a subagent's model per dispatch** — separate from the pinned
frontmatter value, Claude Code accepts a per-invocation model choice when
dispatching a subagent. Resolution order, highest priority first: the
`CLAUDE_CODE_SUBAGENT_MODEL` environment variable, then the per-invocation
choice, then the subagent definition's `model:` frontmatter, then the main
conversation's model.

**Effort level** — Claude Code's control for reasoning depth is called
*effort*, not "reasoning effort." Set it with `/effort <level>` (or
`/effort` with no argument for a picker) or `--effort <level>` at launch.
Valid levels, model-dependent: `low`, `medium`, `high`, `xhigh`, `max`. Lower
effort is faster and cheaper on straightforward tasks; higher effort spends
more to reason harder on complex ones — it is a second, finer-grained lever
alongside model tier, not a replacement for it.

**Fast mode is not a cheaper model.** `/fast` toggles a high-speed
configuration that is *only* available on Opus, and it makes responses
faster at a **higher** per-token cost, not lower — same model, same quality,
different latency/cost tradeoff. If someone reaches for "fast mode" expecting
it to save budget, correct that before they turn it on: it does the opposite
of what this skill is trying to help with. It is a latency lever for
interactive work, not a cost lever.

**Seeing what a session is actually spending** — `/usage` (alias `/cost`)
shows session token usage and estimated cost; `/context` visualizes what is
occupying the context window and flags what's bloating it. Point people at
these before they guess.

## Handoffs

This skill decides *whether* to delegate and *which tier*. It does not author
anything:

| Need | Hand off to |
|------|-------------|
| Writing the subagent file, choosing skill vs. subagent vs. command vs. hook | `subagent-authoring` |
| CLAUDE.md is too long, or this skill's policy block needs to go in it | `claude-md-authoring` |
| A skill's own description over- or under-triggers | `harness-eval` |
| A full harness audit beyond just cost | `harness-audit` |

## Deeper material

`references/cost-model.md` — the full verification trail for every mechanic
above, and worked examples of the diagnostic in use.

`assets/claude_md_snippet.md` — the paste-in policy block that makes the
routing table binding rather than advisory for a given repo.
