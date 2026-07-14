# Trigger validation — harness track

Method: each prompt judged against the skill's `description:` frontmatter only —
that is all the router sees at trigger time; the SKILL.md body is invisible.
Judged by fresh subagents with no access to the skill body and no knowledge of who
wrote it. Each row is a quorum of **three independent, blind judges**, dispatched
one prompt per judge (never all 10 prompts to one judge, which would let a judge
calibrate on the set instead of judging the single utterance the router actually
sees). Spec: [`eval_spec.json`](eval_spec.json). Date: 2026-07-14.

This is a dogfood run: `harness-eval`'s own Mode-1 procedure, applied to the four
skills the project just shipped (including `harness-eval` itself). Judge model:
Claude Haiku. 160 total judgements across two rounds (120 first-round + 30
second-round re-run of `harness-audit`, whose description was edited after a
`FLAKY` row).

## harness-audit — round 1 (original description)

| # | Prompt | Expected | Verdict | Judges |
|---|--------|----------|---------|--------|
| 1 | "set up Claude Code for this repo" | trigger | PASS | 3/3 trigger |
| 2 | "is our Claude setup any good?" | trigger | PASS | 3/3 trigger |
| 3 | "what's missing from our .claude directory?" | trigger | PASS | 3/3 trigger |
| 4 | "onboard this project to agentic development" | trigger | PASS | 3/3 trigger |
| 5 | "audit our harness" | trigger | PASS | 3/3 trigger |
| 6 | "our CLAUDE.md is too long" | no-trigger | **FLAKY** | 2/3 no-trigger |
| 7 | "create an agent that reviews migrations" | no-trigger | PASS | 3/3 no-trigger |
| 8 | "does this skill trigger?" | no-trigger | PASS | 3/3 no-trigger |
| 9 | "prepare the release" | no-trigger | PASS | 3/3 no-trigger |
| 10 | "fix the failing invoice test" | no-trigger | PASS | 3/3 no-trigger |

Row 6 reasoning as given by the three judges:
- Judge A (no-trigger): "lacks the clear intent shown in the skill's examples
  ('audit our harness', 'is our setup any good?')... appearing instead as
  feedback rather than a request for the harness assessment workflow."
- Judge B (**trigger** — the dissenter): "CLAUDE.md is explicitly listed as a
  core component of the Claude Code harness this skill audits and improves, and
  the user's complaint about file length is a quality/maintainability issue the
  skill is designed to address."
- Judge C (no-trigger): "did not explicitly request an audit, improvement, or
  bootstrap... the skill is triggered by requests like 'audit our harness'... not
  casual observations about file size."

**9/10 rows PASS, 1/10 FLAKY, 0/10 FAIL on first pass.**

## Fix applied to harness-audit

The ambiguous clause was "when harness quality is in question." Its opening
sentence names CLAUDE.md explicitly as one of the harness components this skill
audits, so a judge could legitimately read "our CLAUDE.md is too long" as a
harness-quality complaint about that same named component — exactly the kind of
clause that "opens with a category rather than an example" (harness-eval's own
over-triggering pattern). This prompt is deliberately claude-md-authoring's
territory in the spec (its own row 2), so the ambiguity is a real cross-trigger
risk, not a false positive from a bad test prompt.

Fix: (1) anchored "harness quality" to "the harness's **overall** completeness or
quality," and (2) added an explicit carve-out sentence: `A complaint about one
file's content or length (e.g. "our CLAUDE.md is too long") is not a harness
audit — that belongs to CLAUDE.md authoring.` No other clause was touched, and no
other skill's description was touched — the split only implicated harness-audit's
description, not claude-md-authoring's (which passed row 2 for the same prompt,
3/3 trigger, unanimously and correctly, in its own first pass below).

## harness-audit — round 2 (after fix, full spec re-run)

Per harness-eval's own rule ("a description edit invalidates every previous
result for that skill"), all 10 prompts were re-judged with 3 fresh judges each —
not just row 6.

| # | Prompt | Expected | Verdict | Judges |
|---|--------|----------|---------|--------|
| 1 | "set up Claude Code for this repo" | trigger | PASS | 3/3 trigger |
| 2 | "is our Claude setup any good?" | trigger | PASS | 3/3 trigger |
| 3 | "what's missing from our .claude directory?" | trigger | PASS | 3/3 trigger |
| 4 | "onboard this project to agentic development" | trigger | PASS | 3/3 trigger |
| 5 | "audit our harness" | trigger | PASS | 3/3 trigger |
| 6 | "our CLAUDE.md is too long" | no-trigger | PASS | 3/3 no-trigger |
| 7 | "create an agent that reviews migrations" | no-trigger | PASS | 3/3 no-trigger |
| 8 | "does this skill trigger?" | no-trigger | PASS | 3/3 no-trigger |
| 9 | "prepare the release" | no-trigger | PASS | 3/3 no-trigger |
| 10 | "fix the failing invoice test" | no-trigger | PASS | 3/3 no-trigger |

**10/10 PASS on the re-run.** Row 6's three judges now unanimously and explicitly
cite the new carve-out sentence in their reasoning (e.g. "The skill description
explicitly states 'A complaint about one file's content or length... is not a
harness audit — that belongs to CLAUDE.md authoring,' and the user prompt is
precisely that type of complaint"), which is the outcome that shows the edit
resolved the actual ambiguity rather than just changing the odds.

## claude-md-authoring

| # | Prompt | Expected | Verdict | Judges |
|---|--------|----------|---------|--------|
| 1 | "write a CLAUDE.md for this repo" | trigger | PASS | 3/3 trigger |
| 2 | "our CLAUDE.md is too long" | trigger | PASS | 3/3 trigger |
| 3 | "the agent keeps forgetting to run the tests" | trigger | PASS | 3/3 trigger |
| 4 | "why is Claude ignoring our conventions?" | trigger | PASS | 3/3 trigger |
| 5 | "add this rule to CLAUDE.md" | trigger | PASS | 3/3 trigger |
| 6 | "audit our harness" | no-trigger | PASS | 3/3 no-trigger |
| 7 | "should this be a skill or a command?" | no-trigger | PASS | 3/3 no-trigger |
| 8 | "test my skill's description" | no-trigger | PASS | 3/3 no-trigger |
| 9 | "why did we choose Redis for queues?" | no-trigger | PASS | 3/3 no-trigger |
| 10 | "update the README badges" | no-trigger | PASS | 3/3 no-trigger |

**10/10 PASS, all unanimous. No description edit needed.**

## subagent-authoring

| # | Prompt | Expected | Verdict | Judges |
|---|--------|----------|---------|--------|
| 1 | "create an agent that reviews migrations" | trigger | PASS | 3/3 trigger |
| 2 | "should this be a skill or a command?" | trigger | PASS | 3/3 trigger |
| 3 | "I want a subagent for research" | trigger | PASS | 3/3 trigger |
| 4 | "make this run automatically every time" | trigger | PASS | 3/3 trigger |
| 5 | "add a /deploy command" | trigger | PASS | 3/3 trigger |
| 6 | "write a CLAUDE.md for this repo" | no-trigger | PASS | 3/3 no-trigger |
| 7 | "is our Claude setup any good?" | no-trigger | PASS | 3/3 no-trigger |
| 8 | "the skill fires on everything" | no-trigger | PASS | 3/3 no-trigger |
| 9 | "generate an SBOM for v2.1" | no-trigger | PASS | 3/3 no-trigger |
| 10 | "refactor UserController into a service class" | no-trigger | PASS | 3/3 no-trigger |

**10/10 PASS, all unanimous. No description edit needed.**

## harness-eval

| # | Prompt | Expected | Verdict | Judges |
|---|--------|----------|---------|--------|
| 1 | "does this skill trigger?" | trigger | PASS | 3/3 trigger |
| 2 | "test my skill's description" | trigger | PASS | 3/3 trigger |
| 3 | "the skill fires on everything" | trigger | PASS | 3/3 trigger |
| 4 | "why didn't Claude use the skill?" | trigger | PASS | 3/3 trigger |
| 5 | "did that CLAUDE.md change actually work?" | trigger | PASS | 3/3 trigger |
| 6 | "write a CLAUDE.md for this repo" | no-trigger | PASS | 3/3 no-trigger |
| 7 | "create an agent that reviews migrations" | no-trigger | PASS | 3/3 no-trigger |
| 8 | "set up Claude Code for this repo" | no-trigger | PASS | 3/3 no-trigger |
| 9 | "are we CRA ready?" | no-trigger | PASS | 3/3 no-trigger |
| 10 | "write a migration for the orders table" | no-trigger | PASS | 3/3 no-trigger |

**10/10 PASS, all unanimous. No description edit needed.** (Note: this skill was
judging itself blind, same as the other three — the judges saw only the
description text quoted above, not this file, not the SKILL.md body, and not the
fact that harness-eval was auditing itself.)

## Outcome

**Final tally: 40/40 rows PASS** (using each skill's final round: harness-audit
round 2, the other three round 1). Counting every judgement actually run —
including the discarded round-1 harness-audit result — the honest total is
**39 PASS + 1 FLAKY out of the first 40 rows**, then **10/10 PASS** on the
required re-run, for **150 individual judgements** across **13 unique
prompt×description combinations that were re-judged** (harness-audit's full 10
rows re-run after its 1-row edit).

- **1 description edited**: `skills/harness/harness-audit/SKILL.md`. Reason: the
  "harness quality is in question" clause was broad enough, combined with the
  opening sentence's explicit mention of CLAUDE.md as a harness component, that
  one of three blind judges read a single-file length complaint as a harness-wide
  quality complaint. Fixed by anchoring the clause to "overall" and adding an
  explicit carve-out naming the exact ambiguous prompt shape. Full spec (10
  prompts × 3 judges = 30 judgements) re-run after the edit per harness-eval's own
  rule that an edit invalidates all prior results for that skill; all 30 came back
  unanimous and correct.

- **claude-md-authoring, subagent-authoring, harness-eval**: no edits. All three
  passed 10/10 unanimously on the first and only run.

- **Cross-trigger risk, recorded honestly**: the pair that actually collided —
  harness-audit vs. claude-md-authoring on "our CLAUDE.md is too long" — is
  exactly the kind of neighbor collision the brief called out as the realistic
  failure mode in a seven-skill repo. It did not show up as a clean FAIL (which
  would have been easy to fix confidently); it showed up as a 2/3 split, which
  the raw output would have looked like a "probably fine" PASS if rounded. That
  is the scenario harness-eval's honesty rules exist to catch, and this run is
  the first real evidence that catching it in practice, rather than in theory,
  actually changes what gets shipped: the original harness-audit description
  would have gone out with a description that one judge in three (33% of a
  three-way tiebreak) would have wrongly triggered on. No other pair (e.g.
  harness-eval vs. harness-audit on "set up Claude Code for this repo",
  subagent-authoring vs. claude-md-authoring on "write a CLAUDE.md for this
  repo", harness-eval vs. compliance skill "are we CRA ready?") produced even a
  single dissenting vote across all 150 judgements — those boundaries are not
  close calls, they are clean separations.

- **No row was rounded.** Every 3/3 above is a genuine unanimous vote recorded
  from three separately dispatched, blind subagents that saw only the
  `description:` text and one prompt each — never the skill body, never the other
  9 prompts for that skill, never the expected answer, and never each other's
  votes. This report does not mark any skill "validated" — these are the raw
  rows; a human should read them and decide.

## Notes on the harness-eval procedure itself (first real use)

Following `skills/harness/harness-eval/SKILL.md` Mode 1 literally surfaced two
points worth flagging back to that skill's author, since this was its first real
run outside the skill's own examples:

1. **"Dispatch three independent subagents per prompt" is unambiguous once read
   carefully, but easy to violate by default.** The natural first instinct when
   automating 40 rows is to batch all 10 prompts for a skill into one judge
   dispatch to save calls — the SKILL.md explicitly warns against exactly this in
   its own honesty rules ("a single judge returns one sample and calls it
   evidence") but the *task brief* (Task 11) had to restate "one prompt per judge
   dispatch" as an explicit constraint on top of the skill text for it to be
   unmissable. The skill body could be more forceful on this point — it currently
   reads as a design rationale rather than a hard constraint an implementer must
   not violate.
2. **The skill does not specify how to keep judges blind to tool access.** Nothing
   in Mode 1 step 2 says a dispatched judge subagent should be barred from using
   Read/Grep/Bash. In this run every judge prompt had to add its own explicit "do
   NOT use any tools, do not read files" instruction, because the default
   subagent tool allowlist would otherwise let a curious judge go find and read
   the actual SKILL.md body (defeating the entire "description alone" premise).
   This is a real gap: a less careful implementer could dispatch judges with full
   tool access and get a materially different (falsely inflated) result without
   any obvious signal that something went wrong, since the judges would still
   answer in the right format.

Neither point blocked execution — both were resolved by being conservative — but
both are the kind of thing that should be tightened in the skill body before a
second team runs this without the benefit of a task brief spelling out the
gotchas.
