# Rollout note: Harness Skills

## What shipped

Five Claude Code skills for working on the harness itself:

- `harness-audit` — inventories a repo's `.claude/` scaffolding across eight
  surfaces (`CLAUDE.md`, skills, subagents, hooks, slash commands, MCP, verify
  gate, model routing policy) and reports each present / gap / not applicable.
  **Start here.**
- `claude-md-authoring` — writes and repairs `CLAUDE.md`. Also the thing to reach
  for when the agent keeps ignoring an instruction.
- `subagent-authoring` — decides between a skill, a subagent, a command and a hook,
  then writes it.
- `harness-eval` — tests whether a skill actually fires, and whether a harness
  change actually helped.
- `model-routing` — decides which model tier a task needs, whether a subagent is
  the cheaper way to run it, and diagnoses why you keep hitting the usage limit.

Install:

```bash
git clone https://github.com/Oltrematica/oltrematica-skills.git /tmp/os
/tmp/os/scripts/install.sh harness-audit claude-md-authoring subagent-authoring harness-eval model-routing --to /path/to/repo
```

They assume the Superpowers plugin is installed. They do not replace it — they add
what it does not cover.

## What changes for you

**Run `harness-audit` once on your repo.** It takes a couple of minutes and produces
a `Proposed` report: eight surfaces, each marked present / gap / not applicable, with
the reason. It never says "looks good" — if a surface is fine, it says why it is fine.

Then fix what the report says is worth fixing. It will tell you which skill does each
fix. Do not fix everything; a harness with an unused hook in it is worse than one
without.

## Two things worth knowing

**If the agent keeps ignoring an instruction, the answer is almost never a stronger
instruction.** It is usually one of two things: your `CLAUDE.md` has grown long
enough that rules compete for attention and the one you care about is losing, or the
rule needed to hold *every single time* — in which case it was never really an
instruction, it was a hook wearing prose. `claude-md-authoring` walks the diagnosis
in that order (measure the length, classify each section, ask whether it must hold
every time) before it lets you touch the wording.

**A skill you did not test probably does not fire.** Or it fires on everything,
which is worse, because it looks like it is working. `harness-eval` runs your
description past fresh, blind subagents that have never seen the skill body — the
same thing the router sees at trigger time, and nothing more. This is not
theoretical: building these five skills, that process found a real flaky boundary
between `harness-audit` and CRA-compliance questions, and — after the first pass
looked suspiciously clean — a genuine under-triggering failure in `model-routing`'s
own description once the test prompts were rewritten to stop quoting the description
verbatim. Both were fixed and re-verified; the full ledger, including the rounds that
failed before the fix, is in `tests/harness/trigger-validation.md`. Final state: 52
of 52 trigger checks pass, unanimous, across the five skills — but that number came
from 372 individual judgements across every round run, including the ones that
turned up a flaky split and a real failure. The clean final number is not the
interesting part of that file; the rounds before it are.

## What `model-routing` is actually for

People are hitting the five-hour usage limit before the window is up, and the
instinct is to blame the model — "switch to a cheaper one," or the opposite,
"we need the strongest model for everything." Usually neither is the real cause.

Cost is context length times turns, not the number of things you asked for. A
long-running session that has accumulated pasted file dumps, full-file reads and
command output pays for all of that again on every subsequent turn, because a
stateless API call re-sends the whole conversation each time. Someone doing *more*
total work in short, delegated sessions — where a subagent reads the 40 files and
hands back a conclusion, not the 40 files — does not hit the same wall. `/context`
shows what is silently costing you; `/compact` and starting a fresh session are the
actual fix more often than switching models. `model-routing` walks the diagnosis in
the order that actually matters (session length and dead context first, model tier
third) and ships a paste-in `CLAUDE.md` policy block if you want the routing table
to be binding rather than advisory.

## The contract, unchanged

Claude drafts, humans approve. Nothing gets marked healthy, validated or done without
you. Evidence, never assertion — on the harness as on compliance.
