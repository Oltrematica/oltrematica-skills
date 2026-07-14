---
name: harness-eval
description: >-
  Test whether a skill actually fires when it should — and stays quiet when it
  shouldn't — and whether a harness change measurably improved agent behavior. Use
  when a skill's triggering is in question ("does this skill trigger?", "test my
  skill's description", "the skill fires on everything", "the skill never fires",
  "why didn't Claude use the skill?"), before a skill is shared with the team, and
  when a CLAUDE.md or harness edit needs proof it helped ("did that change actually
  work?", "regression-test the harness"). Produces evidence tables, never an
  assertion.
---

# Harness Eval

A skill that never fires is dead code that looks alive. A skill that fires on
everything is worse — it is noise with a good reputation. Both failures are
invisible until someone measures them, and almost nobody does.

## Core contract

1. **Evidence, never assertion.** Output is a table of prompts, expectations and
   observed results. "The description looks good" is not a result.
2. **The description is the whole test surface.** At trigger time Claude sees the
   `description:` frontmatter and *nothing else*. A "do NOT use this for X"
   carve-out in the SKILL.md body cannot prevent a false trigger, because the body
   is invisible when the decision is made. Judge prompts against the description
   alone. This is the single most common mistake in skill testing.
3. **The spec lives in git.** An eval that lives in a chat log is not an eval; it
   is a memory. Prompts and expectations go in `.claude/eval_spec.json`, versioned
   alongside the skill they test.

## Mode 1 — Trigger validation

### 1. Write or locate the spec

Start from `assets/eval_spec.example.json`. Per skill: **at least 5 trigger and 5
no-trigger prompts.**

Choosing prompts is where the value is. Weak specs test the obvious cases and pass
trivially. A useful spec includes:

- **Verbatim phrasings** the description itself quotes — these must pass, and if
  they do not, the description is broken outright.
- **Natural phrasings the description does *not* quote** — real users do not read
  your frontmatter. This is where under-triggering hides.
- **Prompts belonging to a neighboring skill.** Cross-triggering is the failure
  mode that actually bites in a repo with several skills. If two skills sit near
  each other, each one's spec must include the other's territory as `no-trigger`.
- **Adjacent-but-unrelated prompts** — same vocabulary, different intent. "Why did
  we choose Redis?" versus "scan Redis for CVEs" share a noun and nothing else.

Validate before running. The script rejects a spec that is too thin to prove
anything:

```bash
scripts/eval_run.py --validate .claude/eval_spec.json
```

### 2. Judge each prompt with a quorum of fresh, blind subagents

Dispatch **three independent subagents per prompt** — a quorum, not a judge. Each
is given the skill's `description:` text and the prompt, and asked exactly one
thing:

> Given ONLY this skill description and this user prompt, would this skill be
> invoked? Answer `trigger` or `no-trigger`, then one sentence of reasoning.
> Judge the description alone — you have no access to the skill body.

Two things make this adversarial rather than decorative:

**Fresh.** Asking yourself, in the context where you just *wrote* the description,
produces a graded exam marked by its own author. You know what you meant; the
router will not.

**Plural.** Triggering is a probabilistic decision, so a single judge returns one
sample and calls it evidence. Three judges can *disagree* — and disagreement is not
noise to be averaged away, it is the finding. A prompt that two judges fire on and
one does not is exactly what a flaky trigger looks like from the outside. One judge
cannot see that. It reports a clean PASS and you ship a coin flip.

### 3. Tabulate — record the split, never round it

```bash
scripts/eval_run.py --emit-table .claude/eval_spec.json
```

Fill in two columns:

- **Judges** — the raw vote, e.g. `3/3 trigger` or `2/3 trigger`.
- **Verdict** — one of exactly three values:

| Verdict | When | Meaning |
|---------|------|---------|
| `PASS` | Unanimous, and matches `Expected` | The description behaves as intended |
| `FAIL` | Unanimous, and contradicts `Expected` | The description is wrong. Fix it |
| `FLAKY` | Judges split, whichever way the majority went | **Not a pass.** The description is ambiguous on this prompt |

**A split is a finding, not a rounding error.** Never convert `2/3 trigger` into
`PASS` because the majority agreed with you. A clause the judges cannot read
consistently is a clause the router will not apply consistently, and it will fail
on the day it matters. Find the ambiguous phrase and sharpen it until the quorum is
unanimous.

Write the table to `tests/<track>/trigger-validation.md`, or the repo's equivalent.

### 4. Interpret

| Pattern | Diagnosis | Fix |
|---------|-----------|-----|
| Trigger prompts fail | Under-triggering. The description is abstract, or written in your vocabulary rather than the user's | Add concrete example phrasings **in the user's words** |
| No-trigger prompts fire | Over-triggering. A clause is too broad — usually one that opens with a category rather than an example | Anchor the clause with specific examples; narrow the category |
| A neighbor's prompts fire | Cross-triggering | Sharpen the boundary in *both* descriptions, then re-run *both* specs |
| **Judges split (`FLAKY`)** | **Ambiguity.** Some clause is readable two ways, and each judge picked one | Find the phrase they disagreed *about* — their one-line reasonings will name it — and make it say one thing |
| Everything passes first try | Suspect the spec, not the skill | Your prompts are probably paraphrases of the description. Add prompts you expect to fail |

A description edit invalidates every previous result. Re-run the whole spec — not
just the row that failed.

## Mode 2 — Behavioral regression

Trigger validation proves a skill *fires*. It says nothing about whether the
harness *works*. For that: pin the behavior, change the harness, compare.

1. **Pin the observable.** In the spec's `regressions` array, each entry is a task
   prompt plus an `expect_observable` — something you can *see* in a transcript,
   not a vibe. "Runs the declared test command before claiming completion" is
   observable. "Writes better code" is not.
2. **Run before.** Dispatch each regression prompt to a fresh subagent against the
   current harness. Record what actually happened.
3. **Change the harness.** One change. Two changes at once and you learn nothing
   about either.
4. **Run after.** Same prompts, fresh subagents, same recording.
5. **Try to refute the improvement.** This is the step everyone skips, and it is the
   one that keeps you honest. Before you report that the change helped, dispatch a
   skeptic whose job is to argue it did not:

   > Here is the before transcript, the after transcript, and the change that was
   > made. Argue that the change is NOT responsible for the difference. Consider:
   > run-to-run variance, a prompt that was always going to succeed, a difference
   > that does not actually satisfy `expect_observable`. Default to "not
   > established" if the evidence is thin.

   You are the change's author, and you will read its transcript generously. The
   skeptic will not. If it can explain the improvement without reference to your
   change, you have not shown anything yet — run more samples or accept the null
   result.
6. **Diff and report.** State plainly what improved, what regressed, and what did
   not move — including what the skeptic could not rule out. **A change that moves
   nothing is a finding**, and a valuable one: it is how you learn that the
   paragraph you just added to CLAUDE.md is dead weight, competing for attention
   with the rules that work.

## Honesty rules

- **Small N.** Ten prompts × three judges is not a benchmark. Say so. This is a
  smoke test that catches gross triggering failures, and it is worth doing precisely
  because the alternative is zero evidence — not because it is rigorous.
- **A quorum reduces the error; it does not remove it.** Three judges who all read
  the same ambiguous clause the same way still tell you nothing about the fourth
  reader. Unanimity is evidence, not proof.
- **Never average away a disagreement.** `2/3` is `FLAKY`, not `PASS`. The moment
  you start rounding splits in your favor, the whole exercise becomes theatre with
  a table attached.
- **Never mark a skill "validated".** Report the rows and the splits. The human
  reads the table and decides.
