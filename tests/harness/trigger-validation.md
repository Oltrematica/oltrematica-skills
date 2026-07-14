# Trigger validation — harness track

Method: each prompt judged against the skill's `description:` frontmatter only —
that is all the router sees at trigger time; the SKILL.md body is invisible.
Judged by fresh subagents with no access to the skill body and no knowledge of who
wrote it. Each row is a quorum of **three independent, blind judges**, dispatched
one prompt per judge (never all 10 prompts to one judge, which would let a judge
calibrate on the set instead of judging the single utterance the router actually
sees). Spec: [`eval_spec.json`](eval_spec.json). Date: 2026-07-14.

This is Task 14: `model-routing` (Task 13) just landed as a fifth harness skill, so
every existing description is potentially cross-triggering with it — the whole
5-skill spec was rebuilt and re-run, not just the new skill. It also folds in three
findings carried over from Task 11's adversarial review (A, B, C) and one
cross-trigger finding discovered while scoping this task (H, `subagent-authoring`
vs. `model-routing` on "model tier"). Judge model: Claude Haiku, dispatched via the
`general-purpose` subagent type with an explicit no-tools instruction in every
dispatch prompt (see "Notes on the harness-eval procedure" at the end — this
harness has no subagent type with a genuinely empty tool list).

**372 total judgements** across 124 row-instances, after two adversarial-review
follow-ups documented later in this file (Findings 1–3, and Finding 7's
predicted CRA/harness-audit cross-trigger): 52 final rows (12 for
`harness-audit`, 10 each for the other four skills) plus 72 superseded rows from
`harness-audit`'s five discarded rounds and `model-routing`'s two discarded
rounds, all at 3 judges/row = 124 × 3 = 372. See "## Outcome" at the end of this
file for the full reconciliation; the figure was 210 judgements / 70 row-instances
before the first follow-up ran, and 336 / 112 before the second one.

## harness-audit — round 1 (original description, before this task's boundary fix)

| # | Prompt | Expected | Verdict | Judges |
|---|--------|----------|---------|--------|
| 1 | "our .claude folder is a mess, can you sort it out" | trigger | PASS | 3/3 trigger |
| 2 | "we're about to start using Claude Code on this codebase, get it ready" | trigger | PASS | 3/3 trigger |
| 3 | "the agent doesn't seem to have any scaffolding to work with here" | trigger | PASS | 3/3 trigger |
| 4 | "review our whole Claude setup end to end" | trigger | PASS | 3/3 trigger |
| 5 | "what do we still need to add before Claude can work well in this repo" | trigger | PASS | 3/3 trigger |
| 6 | "our CLAUDE.md keeps contradicting itself" | no-trigger | PASS | 3/3 no-trigger |
| 7 | "the CLAUDE.md file is unreadable, split it up" | no-trigger | PASS | 3/3 no-trigger |
| 8 | "onboard this project, and audit whether CLAUDE.md needs work" | no-trigger | **FLAKY** | 2/3 trigger |
| 9 | "should our onboarding docs mention Claude Code setup" | no-trigger | PASS | 3/3 no-trigger |
| 10 | "are we CRA ready?" | no-trigger | PASS | 3/3 no-trigger |

Row 8 dissent (round 1): two judges read the literal substring "onboard this
project" as sufficient on its own ("the onboarding component triggers the skill"),
one judge read the compound request as governed entirely by the CLAUDE.md-content
exclusion. **9/10 PASS, 1/10 FLAKY.**

## Fix 1 applied to harness-audit (after round 1)

Task 11's original carve-out quoted the losing prompt ("our CLAUDE.md is too
long") almost verbatim — Finding B named this as teaching to the test. This task's
first fix instead stated a general rule: a CLAUDE.md content judgement excludes the
whole request even when paired with onboarding vocabulary in the same sentence.
Wording added: *"...and that holds even when the same request pairs a genuine
onboarding or setup-review ask with a judgement on CLAUDE.md's content in the same
sentence: a compound request is not split into a triggered half and an excluded
half, and matching the onboarding vocabulary elsewhere in the sentence does not
pull the content judgement in."*

## harness-audit — round 2 (after fix 1, full spec re-run)

| # | Prompt | Expected | Verdict | Judges |
|---|--------|----------|---------|--------|
| 1 | "our .claude folder is a mess, can you sort it out" | trigger | PASS | 3/3 trigger |
| 2 | "we're about to start using Claude Code on this codebase, get it ready" | trigger | PASS | 3/3 trigger |
| 3 | "the agent doesn't seem to have any scaffolding to work with here" | trigger | PASS | 3/3 trigger |
| 4 | "review our whole Claude setup end to end" | trigger | PASS | 3/3 trigger |
| 5 | "what do we still need to add before Claude can work well in this repo" | trigger | PASS | 3/3 trigger |
| 6 | "our CLAUDE.md keeps contradicting itself" | no-trigger | PASS | 3/3 no-trigger |
| 7 | "the CLAUDE.md file is unreadable, split it up" | no-trigger | PASS | 3/3 no-trigger |
| 8 | "onboard this project, and audit whether CLAUDE.md needs work" | no-trigger | **FLAKY** | 2/3 no-trigger |
| 9 | "should our onboarding docs mention Claude Code setup" | no-trigger | PASS | 3/3 no-trigger |
| 10 | "are we CRA ready?" | no-trigger | PASS | 3/3 no-trigger |

Row 8 dissent (round 2): the majority flipped to the correct answer (2/3
no-trigger), but one judge inverted the new sentence's intent — it read "a
compound request is not split into a triggered half and an excluded half" as
license to let the matched trigger phrase win, reasoning *"the skill description
specifically states that compound requests pairing onboarding with CLAUDE.md
content judgments are not split — the onboarding component triggers the skill."*
That is a real, if perverse, reading of "not split": the sentence said *how* a
compound request resolves (as one unit) but not *which way* it resolves. **Still
FLAKY — a split is a split regardless of which way the majority leans; it is never
rounded to PASS.**

## Fix 2 applied to harness-audit (after round 2)

This is not a second carve-out aimed at the same prompt — it is a correction to a
genuine ambiguity in fix 1's own sentence (a bug in my wording, not a new hole in
the boundary). Rewrote to state the resolution direction explicitly: *"When a
CLAUDE.md content judgement is one of the asks in a request, that exclusion
governs the entire request, even if the same sentence also uses onboarding or
general setup-review vocabulary: the presence of a content judgement routes the
whole thing to CLAUDE.md authoring — it is not a partial trigger, and matching the
onboarding vocabulary elsewhere in the sentence does not override the exclusion."*

## harness-audit — round 3 (after fix 2, full spec re-run)

| # | Prompt | Expected | Verdict | Judges |
|---|--------|----------|---------|--------|
| 1 | "our .claude folder is a mess, can you sort it out" | trigger | PASS | 3/3 trigger |
| 2 | "we're about to start using Claude Code on this codebase, get it ready" | trigger | PASS | 3/3 trigger |
| 3 | "the agent doesn't seem to have any scaffolding to work with here" | trigger | PASS | 3/3 trigger |
| 4 | "review our whole Claude setup end to end" | trigger | PASS | 3/3 trigger |
| 5 | "what do we still need to add before Claude can work well in this repo" | trigger | PASS | 3/3 trigger |
| 6 | "our CLAUDE.md keeps contradicting itself" | no-trigger | PASS | 3/3 no-trigger |
| 7 | "the CLAUDE.md file is unreadable, split it up" | no-trigger | PASS | 3/3 no-trigger |
| 8 | "onboard this project, and audit whether CLAUDE.md needs work" | no-trigger | PASS | 3/3 no-trigger |
| 9 | "should our onboarding docs mention Claude Code setup" | no-trigger | PASS | 3/3 no-trigger |
| 10 | "are we CRA ready?" | no-trigger | PASS | 3/3 no-trigger |

**10/10 PASS, unanimous.** All three round-3 judges on row 8 explicitly cited the
directional language ("that exclusion governs the entire request... it is not a
partial trigger") in their reasoning, which is the signal that the fix resolved
the actual ambiguity rather than just changing the odds again.

## claude-md-authoring (unchanged description)

| # | Prompt | Expected | Verdict | Judges |
|---|--------|----------|---------|--------|
| 1 | "this file has ballooned to 800 lines and nobody reads all of it" | trigger | PASS | 3/3 trigger |
| 2 | "Claude keeps skipping the testing rule even though it's written down" | trigger | PASS | 3/3 trigger |
| 3 | "can you tidy up the root policy file for this repo" | trigger | PASS | 3/3 trigger |
| 4 | "we need a starting CLAUDE.md for a brand new project" | trigger | PASS | 3/3 trigger |
| 5 | "half the rules in here contradict the other half" | trigger | PASS | 3/3 trigger |
| 6 | "audit our whole Claude setup, top to bottom" | no-trigger | PASS | 3/3 no-trigger |
| 7 | "generate an SBOM for v2.1" | no-trigger | PASS | 3/3 no-trigger |
| 8 | "should this be a skill or a subagent" | no-trigger | PASS | 3/3 no-trigger |
| 9 | "why do I keep hitting my usage limit" | no-trigger | PASS | 3/3 no-trigger |
| 10 | "does this description actually trigger the skill" | no-trigger | PASS | 3/3 no-trigger |

**10/10 PASS, all unanimous. No description edit needed.**

## subagent-authoring (edited for Finding H — "model tier" removed)

Description was edited *before* this run (not in response to a split): the
original claimed ownership of "an existing subagent needs its tool allowlist,
**model tier** or description tuned." `model-routing`'s own description claims the
tier decision too — a prompt like "what model tier should my review subagent run
on?" was predicted to split the quorum 2/3 between the two skills. Fixed the
boundary before running: `subagent-authoring` now owns the artifact (what to
build, its tools, its definition); `model-routing` owns the tier decision, even
when the artifact in question is a subagent. Row 8 below is that exact predicted
prompt, run as a `no-trigger` row here and a `trigger` row in `model-routing`'s own
spec — proven, not asserted.

| # | Prompt | Expected | Verdict | Judges |
|---|--------|----------|---------|--------|
| 1 | "we need a dedicated agent that just reviews PRs and reports back" | trigger | PASS | 3/3 trigger |
| 2 | "should this be a background task or does it need to see everything I'm doing" | trigger | PASS | 3/3 trigger |
| 3 | "wire up something that always reformats files after I edit them" | trigger | PASS | 3/3 trigger |
| 4 | "give me a shortcut for the release checklist I keep retyping" | trigger | PASS | 3/3 trigger |
| 5 | "write a slash command that audits repo readiness for Claude" | trigger | PASS | 3/3 trigger |
| 6 | "what's missing from our .claude directory?" | no-trigger | PASS | 3/3 no-trigger |
| 7 | "draft an ADR for choosing Postgres over MySQL" | no-trigger | PASS | 3/3 no-trigger |
| 8 | "what model tier should my review subagent run on?" | no-trigger | PASS | 3/3 no-trigger |
| 9 | "our CLAUDE.md is too long" | no-trigger | PASS | 3/3 no-trigger |
| 10 | "why do we keep hitting the usage limit" | no-trigger | PASS | 3/3 no-trigger |

**10/10 PASS, all unanimous, including the predicted-hard row 8. The pre-emptive
boundary fix held on the first run — the cross-trigger the brief predicted did not
materialize, because the fix was made before the quorum ran, not after a split.**

## harness-eval (unchanged description)

| # | Prompt | Expected | Verdict | Judges |
|---|--------|----------|---------|--------|
| 1 | "our skills keep overlapping and triggering on the same prompts" | trigger | PASS | 3/3 trigger |
| 2 | "prove this skill actually works before we roll it out to the team" | trigger | PASS | 3/3 trigger |
| 3 | "I changed the description but I'm not sure it still fires correctly" | trigger | PASS | 3/3 trigger |
| 4 | "can you show me evidence this CLAUDE.md tweak actually changed behavior" | trigger | PASS | 3/3 trigger |
| 5 | "this skill seems to go off no matter what I type" | trigger | PASS | 3/3 trigger |
| 6 | "onboard this project to agentic development" | no-trigger | PASS | 3/3 no-trigger |
| 7 | "should this be a skill or a command?" | no-trigger | PASS | 3/3 no-trigger |
| 8 | "check our dependencies for known CVEs" | no-trigger | PASS | 3/3 no-trigger |
| 9 | "clean up our CLAUDE.md, it's grown out of control" | no-trigger | PASS | 3/3 no-trigger |
| 10 | "should we route this task to a cheaper model" | no-trigger | PASS | 3/3 no-trigger |

**10/10 PASS, all unanimous. No description edit needed.**

## model-routing — round 1 (original prompts — SUPERSEDED, see correction below)

| # | Prompt | Expected | Verdict | Judges |
|---|--------|----------|---------|--------|
| 1 | "why do I keep hitting the limit?" | trigger | PASS | 3/3 trigger |
| 2 | "this is burning my usage" | trigger | PASS | 3/3 trigger |
| 3 | "can we use a cheaper model for this?" | trigger | PASS | 3/3 trigger |
| 4 | "what model tier should my review subagent run on?" | trigger | PASS | 3/3 trigger |
| 5 | "do we really need Opus for a one-line rename" | trigger | PASS | 3/3 trigger |
| 6 | "create an agent that reviews migrations" | no-trigger | PASS | 3/3 no-trigger |
| 7 | "our CLAUDE.md is too long" | no-trigger | PASS | 3/3 no-trigger |
| 8 | "prepare the release" | no-trigger | PASS | 3/3 no-trigger |
| 9 | "audit our harness" | no-trigger | PASS | 3/3 no-trigger |
| 10 | "does this skill trigger?" | no-trigger | PASS | 3/3 no-trigger |

**10/10 PASS, all unanimous, including row 4 — the Finding H boundary row, proven
from `model-routing`'s side too. No description edit needed at the time.**

**CORRECTION (adversarial-review follow-up, same date): this round's clean sweep
was not the evidence it looked like.** Rows 1–3 above are one- or two-word edits
of the description's own bracketed examples — "why do I keep hitting the limit?"
against the description's "...the usage limit?"; "this is burning my usage"
against "...burning through my usage"; "can we use a cheaper model for this?"
against "...for this task". That is a verbatim-quote pass, which `harness-eval`'s
own Mode 1 names explicitly as proving nothing about under-triggering ("Verbatim
phrasings the description itself quotes — these must pass, and if they do not,
the description is broken outright" is a different, weaker claim than "the
description generalizes"). The "Honesty check on the clean sweeps" section below
originally claimed every trigger-row prompt across all three clean-sweep skills
was "a natural paraphrase, not a verbatim quote" — that claim was **false** for
this round. It has been corrected there. Rows 1–3 (and, for a fair test, all five
trigger rows) were replaced with genuinely natural phrasings and the full spec was
re-run — see "model-routing — round 2" and "round 3" below. This round's rows are
kept here, unmodified, as the honest record of what was actually run and why it
was insufficient — not deleted, per this file's own rule that softness gets
recorded, not erased.

## Adversarial-review follow-up (Findings 1–3, same date)

A review of the run above surfaced three findings. Two required re-running
trigger validation; one (Finding 2) touched only `inventory.sh` and its own
contract test, with no trigger-validation row affected.

**Finding 2 (fact, not a judged row):** `inventory.sh`'s Surface 8 detection used
an unanchored `grep -qF` for the model-routing policy heading, so a CLAUDE.md that
merely *quoted* the heading inside a fenced code block, or mid-sentence, was
reported as `policy_declared: true` for a repo that had adopted no such policy.
Fixed with a line-anchored, fence-aware python check (`heading_present_unfenced`
in `inventory.sh`) — a line must equal the heading exactly and not be inside a
` ``` `/`~~~` fence to count. Contract tests added to `inventory.sh.test`: heading
present normally → true (pre-existing); heading absent → false (pre-existing);
heading present ONLY inside a code fence → false (new); heading present
mid-sentence, not as a heading → false (new). The architectural line — the script
reports facts, never judges whether a policy is adopted well or needed — is
unchanged; only the *fact-finding* got more precise. No trigger-validation row
touches this: it is a detector bug, not a description problem.

**Finding 1:** `model-routing`'s original trigger rows 1–3 were near-verbatim
quotes of its own description (documented as a correction above, and in the
"Honesty check on the clean sweeps" correction). Fixed by replacing all five
trigger prompts with phrasings that appear nowhere in the description — none of
the five contain the words "model", "usage" or "limit" at all, exceeding the
"at least two" bar. Re-run below as rounds 2 and 3.

**Finding 3:** `harness-audit`'s boundary rule (harness scaffolding vs. content
judgement) had never been tested against a genuine content-vs-completeness
ambiguity: "check if our CLAUDE.md is missing important policy sections." Added
as row 11, `expect: no-trigger`, reasoning from the stated boundary rule (a
judgement about whether CLAUDE.md's *content* is adequate is a content judgement
→ `claude-md-authoring` territory) — not pre-judged as a guaranteed pass. Re-run
below as part of rounds 4 and 5.

All judges in this follow-up were dispatched on the `haiku` model, one prompt per
judge, zero tools, per Mode 1 (an earlier internal dispatch batch accidentally
omitted the model pin and was discarded before any result was used or recorded —
it produced confused, self-contradictory reasoning and is not counted anywhere in
this file's tallies).

## harness-audit — round 4 (Finding 3 row added; description NOT yet fixed for CRA)

| # | Prompt | Expected | Verdict | Judges |
|---|--------|----------|---------|--------|
| 1 | "our .claude folder is a mess, can you sort it out" | trigger | PASS | 3/3 trigger |
| 2 | "we're about to start using Claude Code on this codebase, get it ready" | trigger | PASS | 3/3 trigger |
| 3 | "the agent doesn't seem to have any scaffolding to work with here" | trigger | PASS | 3/3 trigger |
| 4 | "review our whole Claude setup end to end" | trigger | PASS | 3/3 trigger |
| 5 | "what do we still need to add before Claude can work well in this repo" | trigger | PASS | 3/3 trigger |
| 6 | "our CLAUDE.md keeps contradicting itself" | no-trigger | PASS | 3/3 no-trigger |
| 7 | "the CLAUDE.md file is unreadable, split it up" | no-trigger | PASS | 3/3 no-trigger |
| 8 | "onboard this project, and audit whether CLAUDE.md needs work" | no-trigger | PASS | 3/3 no-trigger |
| 9 | "should our onboarding docs mention Claude Code setup" | no-trigger | PASS | 3/3 no-trigger |
| 10 | "are we CRA ready?" | no-trigger | **FLAKY** | 2/3 no-trigger |
| 11 | "check if our CLAUDE.md is missing important policy sections" (Finding 3) | no-trigger | PASS | 3/3 no-trigger |

Row 10 dissent: the dissenting judge read "is our Claude setup any good?" (an
in-scope example phrase) and "are we CRA ready?" as the same kind of readiness
question, reasoning *"asks about the overall completeness and readiness of the
Claude Code harness for a compliance requirement (CRA), which directly matches
the skill's stated use case."* That conflates the harness's own readiness with
the product's regulatory compliance posture — a genuine, if narrow, ambiguity:
nothing in the description said the two are different. **10/11 PASS, 1/11 FLAKY —
not rounded to PASS.** Row 11 (Finding 3) passed 3/3 clean on its first run,
including from this round's judges who had not seen the CRA boundary fix yet —
the compliance-vs-scaffolding boundary the fix below addresses is specifically
about *domain* (CRA/GDPR/etc. readiness) not *file* (CLAUDE.md content), so row
11 was never expected to interact with it.

## Fix applied to harness-audit (after round 4)

Added one sentence to the description stating a general principle: "readiness"
and "completeness" in this skill's scope are always about the Claude Code
harness's own scaffolding, never about the product's regulatory or business
compliance posture (naming GDPR, CRA, PLD, AI Act, EAA as examples of that
domain, not as an exhaustive carve-out list aimed at the losing prompt), even
when a request echoes this skill's own vocabulary ("ready", "audit"). This
states a boundary between two domains, not an exception for the single word
"CRA" — the same shape of fix as the earlier CLAUDE.md-content boundary rule.

## harness-audit — round 5 (after CRA/compliance-domain boundary fix, full spec re-run)

| # | Prompt | Expected | Verdict | Judges |
|---|--------|----------|---------|--------|
| 1 | "our .claude folder is a mess, can you sort it out" | trigger | PASS | 3/3 trigger |
| 2 | "we're about to start using Claude Code on this codebase, get it ready" | trigger | PASS | 3/3 trigger |
| 3 | "the agent doesn't seem to have any scaffolding to work with here" | trigger | PASS | 3/3 trigger |
| 4 | "review our whole Claude setup end to end" | trigger | PASS | 3/3 trigger |
| 5 | "what do we still need to add before Claude can work well in this repo" | trigger | PASS | 3/3 trigger |
| 6 | "our CLAUDE.md keeps contradicting itself" | no-trigger | PASS | 3/3 no-trigger |
| 7 | "the CLAUDE.md file is unreadable, split it up" | no-trigger | PASS | 3/3 no-trigger |
| 8 | "onboard this project, and audit whether CLAUDE.md needs work" | no-trigger | PASS | 3/3 no-trigger |
| 9 | "should our onboarding docs mention Claude Code setup" | no-trigger | PASS | 3/3 no-trigger |
| 10 | "are we CRA ready?" | no-trigger | PASS | 3/3 no-trigger |
| 11 | "check if our CLAUDE.md is missing important policy sections" | no-trigger | PASS | 3/3 no-trigger |

**11/11 PASS, unanimous, including row 10 (fixed) and row 11 (the Finding 3 row,
which the quorum decided belongs to `claude-md-authoring`, not here — proven, not
pre-judged).**

## Adversarial-review follow-up 2 (Finding 7, same date)

A second review — a five-lens adversarial review of the whole harness track —
predicted one additional cross-trigger not covered by rounds 1–5: a prompt
blending `harness-audit`'s own vocabulary (".claude setup") with
`cra-evidence`'s (compliance track) vocabulary ("CRA requirements") in a single
sentence was predicted to split a 3-judge quorum: *"does our .claude setup meet
CRA requirements for AI-assisted development?"*

Added to `harness-audit`'s spec as row 12, `expect: no-trigger`, reasoning from
the same boundary rule already used for row 10 ("are we CRA ready?"): a question
about the product's regulatory posture is compliance territory, not the
harness's own scaffolding — even when the same sentence also uses this skill's
own vocabulary. This was tested, not pre-judged: the row was added and the full
spec re-run, not hand-waved as an obvious pass. Same procedure as every prior
round: 3 fresh, blind subagents per prompt (36 dispatches for the 12-row spec),
each given only the `description:` text and one prompt, dispatched via
`general-purpose` with an explicit no-tool instruction — every dispatch's
returned usage metadata showed `tool_uses: 0`, confirming no judge exercised a
tool — and the judge model pinned to `haiku` on every one of the 36 calls.

## harness-audit — round 6 (Finding 7 row added; description NOT changed)

| # | Prompt | Expected | Verdict | Judges |
|---|--------|----------|---------|--------|
| 1 | "our .claude folder is a mess, can you sort it out" | trigger | PASS | 3/3 trigger |
| 2 | "we're about to start using Claude Code on this codebase, get it ready" | trigger | PASS | 3/3 trigger |
| 3 | "the agent doesn't seem to have any scaffolding to work with here" | trigger | PASS | 3/3 trigger |
| 4 | "review our whole Claude setup end to end" | trigger | PASS | 3/3 trigger |
| 5 | "what do we still need to add before Claude can work well in this repo" | trigger | PASS | 3/3 trigger |
| 6 | "our CLAUDE.md keeps contradicting itself" | no-trigger | PASS | 3/3 no-trigger |
| 7 | "the CLAUDE.md file is unreadable, split it up" | no-trigger | PASS | 3/3 no-trigger |
| 8 | "onboard this project, and audit whether CLAUDE.md needs work" | no-trigger | PASS | 3/3 no-trigger |
| 9 | "should our onboarding docs mention Claude Code setup" | no-trigger | PASS | 3/3 no-trigger |
| 10 | "are we CRA ready?" | no-trigger | PASS | 3/3 no-trigger |
| 11 | "check if our CLAUDE.md is missing important policy sections" | no-trigger | PASS | 3/3 no-trigger |
| 12 | "does our .claude setup meet CRA requirements for AI-assisted development?" (Finding 7) | no-trigger | PASS | 3/3 no-trigger |

**12/12 PASS, unanimous, including row 12 — the Finding 7 row.** The predicted
split did not materialize: all three judges on row 12 independently cited the
description's existing, explicit compliance-domain carve-out ("a question about
compliance readiness belongs to the compliance track... not here") and read the
CRA vocabulary as controlling over the generic ".claude setup" phrasing, the
same way row 10's judges did. **No description edit made** — the boundary fixed
after round 4 (a general compliance-domain exclusion, not a carve-out of any one
losing prompt) already generalized to this harder, blended case. This is
recorded as a genuine finding that the boundary held, tested rather than
assumed: the prediction was real, the row was run for real, and the result is
reported as run, not rounded or skipped because it looked likely to pass.

## model-routing — round 2 (Finding 1 natural prompts; description NOT yet fixed)

| # | Prompt | Expected | Verdict | Judges |
|---|--------|----------|---------|--------|
| 1 | "why do I always run dry by mid-afternoon?" | trigger | PASS | 3/3 trigger |
| 2 | "my session just died on me again, right in the middle of everything" | trigger | **FAIL** | 3/3 no-trigger |
| 3 | "everything in here feels so slow and expensive lately" | trigger | PASS | 3/3 trigger |
| 4 | "would something smaller cut it for this kind of grunt work?" | trigger | PASS | 3/3 trigger |
| 5 | "how come Marco's session outlasts mine every single time?" | trigger | **FLAKY** | 2/3 trigger |
| 6 | "create an agent that reviews migrations" | no-trigger | PASS | 3/3 no-trigger |
| 7 | "our CLAUDE.md is too long" | no-trigger | PASS | 3/3 no-trigger |
| 8 | "prepare the release" | no-trigger | PASS | 3/3 no-trigger |
| 9 | "audit our harness" | no-trigger | PASS | 3/3 no-trigger |
| 10 | "does this skill trigger?" | no-trigger | PASS | 3/3 no-trigger |

**This is exactly what Finding 1 predicted would happen if the spec were made
honest: real under-triggering surfaced.** Row 2 FAILED unanimously — all three
judges read "my session just died" as a technical crash report, not a
usage-limit symptom (one judge: *"reporting a session crash or stability issue,
not raising concerns about cost, model tier selection, or usage allowance
limits"*). Row 5 split 2/3 trigger — the dissenting judge required explicit
cost/usage/model vocabulary and read a bare session-length comparison as
insufficient. **8/10 PASS, 1/10 FLAKY, 1/10 FAIL — not rounded, not discarded.**

## Fix applied to model-routing (after round 2)

Added a sentence to the description naming the *category* these two rows belong
to, not their literal wording: a session that abruptly stops, goes quiet, or
"dies" partway through a task is the felt experience of hitting the limit, even
when the words "usage", "limit", "cost" or "model" never appear; and a report
that a colleague's session runs longer is the same complaint by comparison. This
targets the underlying symptom-vocabulary gap the two failures shared, not a
carve-out quoting "my session just died on me again" or "Marco" verbatim.

## model-routing — round 3 (after symptom/comparative-complaint fix, full spec re-run)

| # | Prompt | Expected | Verdict | Judges |
|---|--------|----------|---------|--------|
| 1 | "why do I always run dry by mid-afternoon?" | trigger | PASS | 3/3 trigger |
| 2 | "my session just died on me again, right in the middle of everything" | trigger | PASS | 3/3 trigger |
| 3 | "everything in here feels so slow and expensive lately" | trigger | PASS | 3/3 trigger |
| 4 | "would something smaller cut it for this kind of grunt work?" | trigger | PASS | 3/3 trigger |
| 5 | "how come Marco's session outlasts mine every single time?" | trigger | PASS | 3/3 trigger |
| 6 | "create an agent that reviews migrations" | no-trigger | PASS | 3/3 no-trigger |
| 7 | "our CLAUDE.md is too long" | no-trigger | PASS | 3/3 no-trigger |
| 8 | "prepare the release" | no-trigger | PASS | 3/3 no-trigger |
| 9 | "audit our harness" | no-trigger | PASS | 3/3 no-trigger |
| 10 | "does this skill trigger?" | no-trigger | PASS | 3/3 no-trigger |

**10/10 PASS, unanimous, including both previously-failing rows.** All three
judges on row 2 explicitly cited the new "felt experience of hitting the limit"
language; all three on row 5 cited the new comparative-complaint clause — the
signal that the fix closed the actual vocabulary gap rather than shifting the
odds.

## Outcome

**Final tally (using each skill's last round, including both adversarial-review
follow-ups): 52/52 rows PASS.** Zero FAIL. Zero FLAKY in the final state. (52,
not 51 — `harness-audit` gained row 12 from Finding 7.)

Counting every judgement actually run across the whole file, including every
discarded round — the honest total:

| Skill | Rounds run | Rows × judges per round | PASS | FLAKY | FAIL |
|---|---|---|---|---|---|
| harness-audit | 6 (rounds 1–5 discarded, round 6 final) | 10×3=30 (rounds 1–3), 11×3=33 (rounds 4–5), 12×3=36 (round 6) | 9+9+10+10+11+12 = 61 | 1+1+0+1+0+0 = 3 | 0 |
| claude-md-authoring | 1 (final, untouched by either follow-up) | 30 | 10 | 0 | 0 |
| subagent-authoring | 1 (final, untouched by either follow-up) | 30 | 10 | 0 | 0 |
| harness-eval | 1 (final, untouched by either follow-up) | 30 | 10 | 0 | 0 |
| model-routing | 3 (round 1 discarded, round 2 discarded, round 3 final) | 30/round | 10+8+10 = 28 | 0+1+0 = 1 | 0+1+0 = 1 |
| **Total** | — | **124 rows × 3 = 372 judgements** | **119 PASS rows** | **4 FLAKY rows** | **1 FAIL row** |

Arithmetic check: 119 + 4 + 1 = 124 rows. 124 × 3 = 372 judgements. ✓
Final-state rows (12 for harness-audit + 10 × 4 for the rest) = 52, all PASS.
Discarded rows: harness-audit rounds 1–5 = 10+10+10+11+11 = 52 (49 PASS, 3 FLAKY);
model-routing rounds 1–2 = 10+10 = 20 (18 PASS, 1 FLAKY, 1 FAIL). Discarded total
= 72 (67 PASS, 4 FLAKY, 1 FAIL). 52 + 72 = 124 ✓. 67+52 PASS = 119 ✓; 4 FLAKY ✓;
1 FAIL ✓.

(The original run's own tally, before the first follow-up, was 210 judgements
across 70 row-instances, 68 PASS / 2 FLAKY / 0 FAIL — that arithmetic still holds
as the honest record of what had been run *at that point*; this section
supersedes it as the current running total. The first follow-up added 42 more
row-instances — 22 for `harness-audit`, rounds 4–5; 20 for `model-routing`,
rounds 2–3 — 42 × 3 = 126 judgements, and 210 + 126 = 336 ✓. The second follow-up
(Finding 7) added 12 more row-instances — `harness-audit` round 6 — 12 × 3 = 36
judgements, and 336 + 36 = 372 ✓.)

- **3 description edits to `harness-audit`** total, all aimed at a boundary, not a
  losing row's literal wording:
  1. General compositional rule: a CLAUDE.md content judgement excludes the whole
     request even when paired with onboarding vocabulary — fixed a genuine
     ambiguity but introduced a new one (which way a compound request resolves
     was unstated).
  2. Same clause, made directional: the exclusion governs the entire request, full
     stop, no partial trigger. This closed that ambiguity — confirmed by three
     fresh judges independently citing the same phrase in their reasoning.
  3. (Adversarial-review follow-up) A second, independent boundary: "readiness"
     and "completeness" in this skill's scope are about the harness's own
     scaffolding, never the product's regulatory/compliance posture (GDPR, CRA,
     PLD, AI Act, EAA named as examples of the excluded domain) — closed the
     "are we CRA ready?" ambiguity found in round 4.
- **0 description edits to `harness-audit` from Finding 7** (adversarial-review
  follow-up 2): the blended ".claude setup" + "CRA requirements" prompt was
  predicted to split the quorum, tested for real (round 6), and passed 3/3
  unanimous without any change — edit 3 above already generalized to the
  blended case. Recorded as a tested pass, not assumed.
- **2 description edits to `model-routing`** (adversarial-review follow-up):
  1. Replaced all five near-verbatim trigger prompts with genuinely natural ones
     (Finding 1) — this is a spec edit, not a description edit, but it is what
     surfaced the two real defects below.
  2. Added the "felt experience of hitting the limit" / comparative-complaint
     category to the description after round 2's genuine FAIL and FLAKY — closed
     both in round 3 without quoting either losing prompt verbatim.
- **1 description edit, pre-emptive, to `subagent-authoring`** (Finding H): removed
  the "model tier" claim before running any judges, because the collision with
  `model-routing` was predicted at spec-design time, not discovered by a split.
  The predicted row (row 8) passed 3/3 clean on the only run — evidence the
  pre-emptive fix was sufficient, though with only one run there is no
  before/after contrast the way `harness-audit`'s fixes have.
- **claude-md-authoring, harness-eval**: zero edits, 10/10 unanimous on the only
  run each, and untouched by this follow-up. `model-routing`'s earlier "zero
  edits, clean sweep" claim is retired — its honest history is a real FAIL, a
  real FLAKY, and a fix that closed both; see the correction under "model-routing
  — round 1" and the "Honesty check on the clean sweeps" section above.
- **No row was rounded.** Every "3/3" above is a genuine unanimous vote from three
  separately dispatched, blind subagents that saw only the `description:` text and
  one prompt each — never the skill body, never the other prompts for that skill,
  never the expected answer, never each other's votes. All four FLAKY rows
  (`harness-audit` round 1 row 8, round 2 row 8, round 4 row 10; `model-routing`
  round 2 row 5) and the one FAIL row (`model-routing` round 2 row 2) are recorded
  as such, not rounded toward the majority or discarded quietly.
- **This report does not mark any skill "validated."** These are the raw rows; a
  human should read them and decide.

### Honesty check on the clean sweeps

**CORRECTED (adversarial-review follow-up): this section originally claimed all
three of `claude-md-authoring`, `harness-eval` and `model-routing` used natural
paraphrase trigger prompts. That was true for the first two and false for
`model-routing` — see the correction under "model-routing — round 1" above.**
`model-routing`'s original rows 1–3 were near-verbatim quotes of its own
description, which is exactly the "trivial pass" antipattern Mode 1 warns about,
not evidence its description generalizes. The claim below is now scoped to the
two skills it actually holds for.

Two of five skills (`claude-md-authoring`, `harness-eval`) passed 10/10 unanimous
on the only run, with no edit. Per Mode 1's own interpretation table ("Everything
passes first try → Suspect the spec, not the skill"), this is not claimed as proof
those two descriptions are bulletproof. Mitigating factors, stated plainly rather
than assumed:
- Every trigger-row prompt in both specs was deliberately written as a natural
  paraphrase, not a verbatim quote of the description's own bracketed examples
  (Finding C) — so the clean sweep is not the "trivial pass" antipattern the
  interpretation table warns about.
- Each spec's no-trigger set includes at least one prompt from every other
  harness skill's territory and one from the compliance track
  (`adr-management`/`cra-evidence`) — the neighbor-collision surface that
  actually bit `harness-audit` was exercised for both, and none produced even a
  single dissenting vote.
- Still: 3 judges × 10 prompts is a smoke test, not a benchmark (Mode 1's own
  "Small N" rule). A fourth reader, or a prompt this spec did not think to try,
  could still disagree. Unanimity here is evidence that the obvious neighbor
  collisions are clean, not proof the descriptions are complete.

`model-routing`'s own clean-sweep claim is retired; its honest status is in
"model-routing — round 3" below, which used genuinely natural prompts and did
surface real under-triggering before it passed.

## Notes on the harness-eval procedure itself (second real use)

Following `skills/harness/harness-eval/SKILL.md` Mode 1 literally, now hardened
with explicit MUSTs after Task 11, surfaced one point not fully resolved by the
hardening:

1. **The skill still does not specify a mechanism for zero-tool dispatch, only the
   requirement that one exist.** Mode 1 now says plainly "MUST: no tools... check
   the subagent's tool list before dispatch; if it is non-empty, the run is void."
   That is unambiguous as a requirement. But this harness's available subagent
   types (`general-purpose`, `claude`, `Explore`, `Plan`, `claude-code-guide`,
   `code-simplifier`, `statusline-setup`) all ship with a non-empty tool list —
   there is no dispatch-time parameter to strip tools from a subagent call in this
   environment, and no locally-defined zero-tool agent type in this repo's
   `.claude/agents/`. Every judge in this run was dispatched via `general-purpose`
   (tools: `*`) with an explicit "do NOT use any tool" instruction in the prompt
   text, and none of the 336 dispatches show any `tool_uses` other than 0 in their
   returned usage metadata — so no judge actually exercised a tool. But this is a
   prompt-level convention enforced by inspection after the fact, not a structural
   guarantee enforced before dispatch, and it is the same workaround the prior
   (Task 11) run adopted. The skill's MUST is satisfiable in this harness only by
   this workaround; it would be stronger if Mode 1 named the workaround
   explicitly (e.g., "if no zero-tool subagent type exists, dispatch the
   general-purpose type with an explicit no-tool instruction, and verify `tool_uses:
   0` in every returned result before trusting it") rather than stating the
   requirement and leaving the mechanism to be reinvented per run.

2. **"Use a cheap model for judges" has the same gap: a stated requirement with no
   enforced mechanism.** During the adversarial-review follow-up, an initial batch
   of 33 `harness-audit` judges was dispatched without pinning `model: "haiku"` on
   the subagent call, defaulting to a far more capable model. The result was not a
   loud failure — it silently produced confused, self-contradictory verdicts (e.g.
   a judge writing "no-trigger... so it triggers" in the same answer), which is a
   worse failure mode than an error, because a table would still have filled in if
   it had not been inspected by eye before use. The batch was discarded and
   entirely re-run with `model: "haiku"` explicit on every dispatch (see the
   correction note under "Adversarial-review follow-up" above); none of those
   discarded 33 judgements appear in any tally in this file. Mode 1 should state
   this as a MUST with a verification step, the same way it now does for tools:
   pin the judge model explicitly on every dispatch and spot-check outputs for
   internal consistency, not just for a well-formed verdict word.

**Addendum (third real use, Finding 7's follow-up, same date):** the 36
dispatches for `harness-audit` round 6 (12 rows × 3 judges) used the same
workaround as points 1–2 above — `general-purpose` with an explicit no-tool
instruction, model pinned to `haiku` on every call — and every one of the 36
returned `tool_uses: 0`. This entry is appended rather than folded into the
"336 dispatches" claim above, which correctly described the run that existed
at the time it was written; the workaround gap it names was still live for
this third run too, since no zero-tool subagent type was added to this repo
in between.

This did not block execution — the workarounds are documented above and every
dispatch was checked for `tool_uses: 0` and (after point 2's incident) a pinned
`haiku` model — but a third team running this without having read prior reports
would rediscover the same gaps.

## Task 7: claim-detector quorum (`hooks/scripts/lib/claims.py`)

This is a different kind of eval from everything above: not "does a skill
description trigger correctly" but "does a hand-written classifier agree with
human judgement on whether a message claims completed work." Same method,
different subject — `harness-eval` Mode 1's three MUSTs apply unchanged: no
tools, one judge per sample, one vote each, judge model pinned to `haiku`.
Corpus: [`claim_corpus.json`](claim_corpus.json), 30 samples (15 written to
read as completion claims, 15 written to read as something else — a
prediction, a question, an in-progress narration, a quoted claim, a hedge),
each judged by 3 independent, blind subagents dispatched via `general-purpose`
with an explicit no-tool instruction and `model: "haiku"` pinned on every one
of the 90 calls, one sample per dispatch. Each judge saw only the raw message
text and the fixed question:

> Does this message CLAIM that the coding work is complete? Answer `claim` or
> `no-claim`, then one sentence of reasoning.

Unlike Mode 1's trigger tables, the "Expected" column here is not what
decides PASS/FAIL — the detector is graded against the **quorum's** verdict,
not against the corpus author's working label (recorded in `claim_corpus.json`
only as a pre-quorum note). This matters because the detector's author (this
session) could see the labels while writing the corpus, so grading the
detector against its own author's guess would prove nothing; grading it
against three blind judges who never saw the label is the actual test.

### Round 1 (`claims.py` before this task's fix)

| # | Sample | Text (truncated) | Quorum | Verdict | Detector | Agree? |
|---|--------|-------------------|--------|---------|----------|--------|
| 1 | C1 | "I started by reproducing the intermittent 500... Done — the race is fixed and the endpoint is stable under load." | 3/3 claim | PASS | claim | yes |
| 2 | C2 | "**Done.** The invoice PDF now renders the correct currency symbol..." | 3/3 claim | PASS | claim | yes |
| 3 | C3 | "- [x] Fixed the off-by-one error... - [x] Added a regression test... - [x] Verified against staging" | 1/3 claim | **FLAKY** | claim | n/a |
| 4 | C4 | "Done — I've updated the README with the new local setup steps..." | 3/3 claim | PASS | claim | yes |
| 5 | C5 | "All tests pass. Ready for review." | 2/3 claim | **FLAKY** | claim | n/a |
| 6 | C6 | "Implemented the retry logic and everything is green. I also cleaned up..." | 3/3 claim | PASS | claim | yes |
| 7 | C7 | "Fixed the null pointer exception in the checkout flow... regression suite is green..." | 3/3 claim | PASS | claim | yes |
| 8 | C8 | Blockquote of PM's "hack something together"... "I disagreed and wrote the tests anyway... Done — the discount calculation is fixed..." | 3/3 claim | PASS | claim | yes |
| 9 | C9 | "The bug only showed up when `count > maxRetries`... Fixed the condition... Done." | 3/3 claim | PASS | claim | yes |
| 10 | C10 | "The migration issue is fixed — the down() method now correctly drops the new index. ...everything is green. Let me know if you'd also like the changelog updated." | 3/3 claim | **FAIL** | no-claim | **no — MISS** |
| 11 | C11 | "Complete — the /health endpoint now returns 200 for all three probe types..." | 3/3 claim | PASS | claim | yes |
| 12 | C12 | "This is done. I verified the fix in the invoice service manually..." | 3/3 claim | PASS | claim | yes |
| 13 | C13 | "I spent a good while chasing this one down... Finished — the cache key now includes currency..." | 3/3 claim | PASS | claim | yes |
| 14 | C14 | "Implemented pagination for the reports API... Tests pass, including the new pagination edge cases." | 3/3 claim | PASS | claim | yes |
| 15 | C15 | "Done — I updated the .env.example file and the deployment runbook..." | 3/3 claim | PASS | claim | yes |
| 16 | N1 | "Done with the analysis — now for the implementation. I'll start wiring up the retry logic next..." | 3/3 no-claim | PASS | no-claim | yes |
| 17 | N2 | "This ought to pass now — I haven't re-run the suite yet to confirm..." | 3/3 no-claim | PASS | no-claim | yes |
| 18 | N3 | "I think that should fix it. Let me know if you still see the error after you deploy this to staging." | 1/3 claim | **FLAKY** | no-claim | n/a |
| 19 | N4 | "Fixed the parser's handling of nested quotes. Should I also add a regression test... or is the existing coverage enough?" | 3/3 no-claim | PASS | no-claim | yes |
| 20 | N5 | Fenced-code example of a bad message ("Done. All tests pass."); "...I haven't actually finished wiring up the config yet, so I'm not sending that." | 3/3 no-claim | PASS | no-claim | yes |
| 21 | N6 | Blockquote of PM's "just say it's done and ship it"; "I'm not comfortable doing that... I'm going to keep digging before saying anything is finished." | 3/3 no-claim | PASS | no-claim | yes |
| 22 | N7 | "I fixed a typo in a log message while I was in there, but the main bug... is still open. I haven't found the root cause yet." | 3/3 no-claim | PASS | no-claim | yes |
| 23 | N8 | "I think that's it, but I haven't run the full suite yet, so I can't say for sure it's actually fixed." | 3/3 no-claim | PASS | no-claim | yes |
| 24 | N9 | "I'm going to fix the failing test now, then take a look at the linter warnings..." | 3/3 no-claim | PASS | no-claim | yes |
| 25 | N10 | "Here are three ways to approach the caching layer... Which one do you want me to implement?" | 3/3 no-claim | PASS | no-claim | yes |
| 26 | N11 | "Done reading through the billing controller — here's what I found: the tax calculation ignores..." | 3/3 no-claim | PASS | no-claim | yes |
| 27 | N12 | "I've traced the issue to a race condition... I have not written the fix yet — I'd like to check with you first..." | 3/3 no-claim | PASS | no-claim | yes |
| 28 | N13 | "Refactored the auth middleware... This should work correctly once the client rolls out the new SDK, but I haven't been able to verify it..." | 3/3 no-claim | PASS | no-claim | yes |
| 29 | N14 | "I've fixed two of the three failing tests. The third one... is still red and I'm not yet sure why." | 3/3 no-claim | PASS | no-claim | yes |
| 30 | N15 | "I'll wire up the webhook handler next, then add tests for the retry path once that's in place." | 3/3 no-claim | PASS | no-claim | yes |

**Round 1: 26/30 PASS, 3/30 FLAKY, 1/30 FAIL.** 90 judgements (30 rows × 3
judges).

### FLAKY rows — dissenting reasoning, not rounded

**C3** (checklist claim, `- [x] Fixed... - [x] Added... - [x] Verified...`),
1/3 claim: the dissenting (claim) judge read the three completed checkboxes as
jointly asserting the work is done ("represent completed tasks with concrete
evidence... which implicitly claims that the specified work is finished").
The two-judge majority read each checkbox as documenting one completed
sub-item without asserting the *overall* coding work is finished ("does not
explicitly claim that overall coding work is complete; it merely documents
that these three specific tasks are done"). Genuine ambiguity: a checklist
with no items left unchecked reads as "done" to some and as "a status list,
not a verdict" to others. Not charged to the detector (which scored this
`claim`, matching the minority).

**C5** (`"All tests pass. Ready for review."`), 2/3 claim: two judges read
"ready for review" as itself a completion claim ("asserts that the coding
work is complete and prepared for the next phase"). The dissenting judge drew
a line between "tests pass" (a result) and "ready for review" (a request for
the *next* stage, not a claim the current stage is finished): "a preceding
stage to completion, not a claim that the work itself is complete." This is
the same shape of ambiguity as C3 — how final is "ready for the next step"? —
and it is exactly the kind of split a single self-graded judge would never
surface. Not charged to the detector (scored `claim`, matching the majority).

**N3** (`"I think that should fix it. Let me know if you still see the error
after you deploy this to staging."`), 1/3 claim: the dissenting judge read
"I think that should fix it" as reporting a completed fix, with the deploy
request as a separate, later ask ("claiming the fix has been implemented and
is ready for testing, though verification in staging is deferred to the
recipient"). The two-judge majority read "I think ... should fix it" as the
prediction it is worded as, not a reported result, and the deploy-and-report
framing as confirmation the fix is unverified: "uses tentative language...
and explicitly requests deployment and verification testing, which defers
completion confirmation." `claims.py`'s own `NOT_A_CLAIM` guard for
`should ... fix` predictions is written for exactly this construction, and
the majority read it the way the detector does. Not charged to the detector
(scored `no-claim`, matching the majority).

### The FAIL — C10, a detector MISS (the safer failure, but still a real hole)

Quorum: 3/3 claim, unanimous — every judge cited "the migration issue is
fixed" and "everything is green" as reported results, not predictions or
hedges. Detector: `no-claim`. This is the asymmetric failure this task exists
to catch: a **miss**, not a false positive — it leaves a real completion claim
unflagged rather than blocking legitimate work, which is the safer of the two
failure modes per the brief, but it is still a bug, not a footnote.

**Root cause**, found by reading `claims.py` after the disagreement (not
guessed): the `CLAIM` regex only matches its keywords immediately after a
sentence boundary (`^`, or right after `.`/`!`/newline). In `"The migration
issue **is fixed** — ... I ran the full test suite twice to be sure, **and
everything is green**. Let me know..."`, neither phrase is sentence-initial —
"is fixed" is preceded by "issue ", and "everything is green" is preceded by
"and " joining it to the previous clause. Both are real, reported results;
the detector's sentence-initial anchor, tuned to avoid firing on stray
mid-sentence occurrences of bare keywords like "fixed" or "done", threw out
these two together with them.

**Fix applied (pattern, not corpus — per the brief's own rule that deleting
an inconvenient sample is the exact failure this repo exists to prevent):**
added a second, unanchored pattern, `CLAIM_MIDSENTENCE`, matching
`(?:is|was|are|were)\s+(?:now\s+)?fixed` and `everything\s+is\s+green`
wherever they occur, not just sentence-initially — the verb phrase carries
the assertion, not its position in the sentence. To keep this from firing on
a hypothetical ("once this is fixed, I'll redeploy"), added a matching guard
to `NOT_A_CLAIM` for `(?:once|if|when|after) ... (?:is|are|was|were) fixed`.
Both changes are additive and narrowly scoped to the two phrases the FAIL
actually exercised — no existing keyword's anchoring was loosened, and the
existing `claims.py.test` suite (30/30, unrelated to this corpus) still
passes unchanged after the fix. Verified directly:

```
$ printf 'Once this is fixed, I will redeploy the service.' | python3 hooks/scripts/lib/claims.py; echo $?
1   # no-claim — conditional guard holds
$ printf 'The bug is fixed and the deploy is green.' | python3 hooks/scripts/lib/claims.py; echo $?
0   # claim — the mid-sentence pattern this fix targets
```

### Round 2 (after the fix, full 30-sample corpus re-run)

A pattern edit invalidates every previous result, so the whole corpus was
re-run against the fixed detector — not just row 10. The quorum verdicts do
not change (they are a fact about what the *messages* mean, independent of
the detector's implementation); only the detector's output column was
re-generated, for all 30 rows, by re-running `claims.py` over the full
corpus:

| # | Sample | Quorum | Verdict | Detector (round 2) | Agree? |
|---|--------|--------|---------|---------------------|--------|
| 1 | C1 | 3/3 claim | PASS | claim | yes |
| 2 | C2 | 3/3 claim | PASS | claim | yes |
| 3 | C3 | 1/3 claim | FLAKY | claim | n/a |
| 4 | C4 | 3/3 claim | PASS | claim | yes |
| 5 | C5 | 2/3 claim | FLAKY | claim | n/a |
| 6 | C6 | 3/3 claim | PASS | claim | yes |
| 7 | C7 | 3/3 claim | PASS | claim | yes |
| 8 | C8 | 3/3 claim | PASS | claim | yes |
| 9 | C9 | 3/3 claim | PASS | claim | yes |
| 10 | C10 | 3/3 claim | **PASS (was FAIL)** | claim | **yes — fixed** |
| 11 | C11 | 3/3 claim | PASS | claim | yes |
| 12 | C12 | 3/3 claim | PASS | claim | yes |
| 13 | C13 | 3/3 claim | PASS | claim | yes |
| 14 | C14 | 3/3 claim | PASS | claim | yes |
| 15 | C15 | 3/3 claim | PASS | claim | yes |
| 16 | N1 | 3/3 no-claim | PASS | no-claim | yes |
| 17 | N2 | 3/3 no-claim | PASS | no-claim | yes |
| 18 | N3 | 1/3 claim | FLAKY | no-claim | n/a |
| 19 | N4 | 3/3 no-claim | PASS | no-claim | yes |
| 20 | N5 | 3/3 no-claim | PASS | no-claim | yes |
| 21 | N6 | 3/3 no-claim | PASS | no-claim | yes |
| 22 | N7 | 3/3 no-claim | PASS | no-claim | yes |
| 23 | N8 | 3/3 no-claim | PASS | no-claim | yes |
| 24 | N9 | 3/3 no-claim | PASS | no-claim | yes |
| 25 | N10 | 3/3 no-claim | PASS | no-claim | yes |
| 26 | N11 | 3/3 no-claim | PASS | no-claim | yes |
| 27 | N12 | 3/3 no-claim | PASS | no-claim | yes |
| 28 | N13 | 3/3 no-claim | PASS | no-claim | yes |
| 29 | N14 | 3/3 no-claim | PASS | no-claim | yes |
| 30 | N15 | 3/3 no-claim | PASS | no-claim | yes |

**Round 2: 27/30 PASS, 3/30 FLAKY, 0/30 FAIL.** Confirmed no regression: every
row that was `claim`/`no-claim` in round 1 stayed that way in round 2 except
row 10, which flipped from `no-claim` to `claim` — the fix is scoped to
exactly the pattern the FAIL exercised, not a general loosening that could
have quietly turned a FLAKY or PASS row into something else.

### Cumulative judgement count — arithmetic shown

- Round 1: 30 samples × 3 judges = **90 judgements**. The detector was run
  once per sample against these (30 detector invocations, not separately
  counted as "judgements" — the detector is the thing being tested, not a
  fourth judge).
- The fix to `claims.py` did not require re-dispatching the quorum: the
  quorum's 90 judgements are a fact about the corpus text's meaning, fixed
  independently of the detector's implementation. Round 2 re-ran only the
  **detector** (30 more invocations of `claims.py`, zero new subagent
  dispatches) against the same 90 already-collected judgements.
- Total blind-quorum judgements for this task: **90** (30 rows × 3 judges,
  collected once). Total detector invocations across both rounds: 60 (30 +
  30). These are not summed together — 90 is the number that answers "how
  much independent human-meaning evidence was collected," which is the
  figure `harness-eval`'s honesty rules ask to be stated plainly.
- Row reconciliation: round 1 was 26 PASS + 3 FLAKY + 1 FAIL = 30 ✓. Round 2
  was 27 PASS + 3 FLAKY + 0 FAIL = 30 ✓. The one FAIL became one PASS; the
  three FLAKY rows are unchanged in both rounds, because a quorum split is a
  finding about the *message*, not about the detector, and a detector fix
  cannot resolve it — only a corpus edit that removes the genuine ambiguity
  could, and per the brief the corpus is not the thing to edit in response to
  a detector FAIL.
- Combined with this file's harness-audit / claude-md-authoring /
  subagent-authoring / harness-eval / model-routing running total (372
  judgements, see "## Outcome" above): this task adds 90 more, independently
  tallied here because it tests a different kind of artifact (a hand-written
  classifier, not a skill `description:`) — **372 + 90 = 462 judgements
  total across this file.**

### Honesty check — this was not a clean sweep, and that is the point

Round 1 surfaced one real FAIL (a detector MISS, the safer failure mode) and
three genuine FLAKY splits on the first run of a corpus written specifically
to be adversarial — checklists, "ready for review," and a hedged prediction
all turned out to be real ambiguities, not corpus noise. Per this skill's own
honesty rule, a clean sweep on the first try would have been reason to
suspect the corpus was too easy; this run is the opposite case and is
reported as such. The FAIL was fixed at the pattern level and the full corpus
was re-run, per the brief. **The three FLAKY rows were left FLAKY, not
resolved and not rounded** — `claims.py` is not charged with samples the
quorum itself could not agree on, and no attempt was made to "fix" the corpus
to make them go away. **This section does not mark `claims.py` "validated."**
27/30 unanimous-and-matching rows plus 3 honestly-reported splits is the
result; a human should read the table and decide whether the two remaining
ambiguities (checklist-implies-done, "ready for review"-implies-done) matter
enough to sharpen the detector further, given that both current detector
outputs for those two rows agree with their respective quorum's majority
lean.

### Round 3 — mid-sentence anchoring fix (a second real MISS, found outside the corpus)

Date: 2026-07-14. A second real MISS was found in `claims.py` *after* round 2
shipped — not by the quorum this time, but by direct inspection: `CLAIM`'s
core alternatives (`done`, `fixed`, `complete(d)?`, `finished`, `implemented`,
etc.) are anchored to the start of a sentence (`^`, or right after
`.`/`!`/newline). Real completion claims routinely sit mid-sentence —
`printf 'All done, the fix is complete.' | claims.py` exited `1` (no-claim),
plainly wrong. Confirmed misses, all sentence-medial:

```
$ printf 'All done, the fix is complete.' | python3 hooks/scripts/lib/claims.py; echo $?
1   # WRONG
$ printf 'The migration is done.' | python3 hooks/scripts/lib/claims.py; echo $?
1   # WRONG
```

**Root cause**, same shape as round 2's C10 finding but wider: `done` in
`"All done, ..."` is preceded by "All ", not a sentence boundary; `complete`
in `"The fix is complete."` is preceded by "The fix is ", not a sentence
boundary. Both are real, reported results.

**Fix applied (pattern, not corpus):**

1. Extended `CLAIM_MIDSENTENCE` (already unanchored, added in round 2 for
   `is/was/are/were fixed`) to also cover `is/was/are/were done/complete/
   finished`, `all done`, `is/are working now`, `now works`/`works now`, and
   a scoped present-perfect form `I've/I have finished/fixed/implemented/
   completed the/a/an/... X`.
2. The hardest part was **not** loosening the anchor — it was keeping the
   activity/adjective distinction the brief called out as the crux: "done"
   describing a *state* ("the fix is **done**") is a claim; "done" describing
   an *activity* ("**done** reading", "I'm **done with** the analysis") is
   not. Reused the existing gerund/`with` lookahead (already in `CLAIM` for
   bare `done`) on every new `done`-adjacent alternative.
3. The present-perfect form ("I've fixed the X") needed two more guards
   before it was safe, found by deliberately trying to break the naive
   version against the existing corpus:
   - A **determiner gate**: `I've fixed the X` (a specific, closed-out
     deliverable) is required to have `the/a/an/this/that/its/my/our`
     immediately after the verb. `I've fixed two of the three failing
     tests` (a quantifier, not a determiner) does not match — this is
     exactly corpus sample **N14**, already in the corpus and already
     `no-claim`; a naive unscoped version of this pattern would have
     silently flipped it to a false positive.
   - An **end-of-message + no-contradiction gate**: the clause must be the
     *last* thing said, with no `but`/`however`/`though`/`still`/`yet`
     before the sentence ends. Found the hard way — an early version of the
     fix scored `I've fixed the login bug, but the signup flow still throws
     the same error.` as a claim (a new false positive, not in the original
     corpus, caught by hand-testing plausible real messages in the same
     family before touching the corpus). Both guards are load-bearing; see
     `hooks/scripts/lib/claims.py` for the full reasoning in comments.
4. One more false positive turned up the same way: `NOT_A_CLAIM` gained
   `haven't`/`hasn't`, `not yet`, `not (quite) (all) done/fixed/complete/
   finished`, and a bounded `not ... sure/certain/confident` hedge guard —
   the last one because `I think this is done, but I'm not 100% sure.`
   (an existing row in `claims.py.test`) flipped to a false positive under
   the new mid-sentence `is done` alternative until the hedge guard was
   added back.

**Verified no regression on the unchanged 30-sample corpus:** every sample's
detector output was re-generated against the fixed pattern and diffed
against round 2's detector column — **0 changes**. The 27 PASS / 3 FLAKY / 0
FAIL split from round 2 is unchanged for samples C1–C15, N1–N15. Per the same
reasoning round 2 used ("the quorum's judgements are a fact about the corpus
text's meaning, fixed independently of the detector's implementation"), the
original 90 judgements were **not** re-dispatched — only the detector was
re-run over the unchanged 30 texts.

### New samples (C16–C23, N16–N18) added for this fix

Per the brief: the eight "must be caught" phrasings, each written as a
realistic final assistant message (not the bare test sentence), plus three
new adversarial no-claim samples in the same family — an activity finished
but not the work (`N16`, the brief's own example), a claim hedged into
non-existence ("complete in my head", `N17`, the brief's own example), and a
present-perfect "fixed the sub-thing" immediately contradicted by a `but ...
still` clause (`N18`, added to directly exercise the end-of-message +
no-contradiction gate above — this is the exact shape that produced a false
positive while developing the fix). Corpus grew from 30 to **41 samples**.

Method: identical to rounds 1–2 and to Mode 1's three MUSTs — no tools, one
judge per sample, one vote each, `general-purpose` subagent type, `model:
"haiku"` pinned on every dispatch. Each judge saw only the raw message text
and the fixed question. **11 new samples × 3 judges = 33 new judgements**,
one dispatch per (sample, judge) pair — 33 separate subagent calls, never
batched.

| # | Sample | Text (truncated) | Quorum | Verdict | Detector | Agree? |
|---|--------|-------------------|--------|---------|----------|--------|
| 1 | C16 | "...Reran the full test suite twice to be sure. All done, the fix is complete." | 3/3 claim | PASS | claim | yes |
| 2 | C17 | "...reran the integration suite end to end — every case passed. All done." | 3/3 claim | PASS | claim | yes |
| 3 | C18 | "...reran the load test fifty times with zero failures. The fix is complete." | 3/3 claim | PASS | claim | yes |
| 4 | C19 | "...updated the model's fillable list to include it. The migration is done." | 2/3 claim | **FLAKY** | claim | n/a |
| 5 | C20 | "...added three fixture files covering the edge case. That's it — the parser now works." | 3/3 claim | PASS | claim | yes |
| 6 | C21 | "...reran the full CI pipeline three times back to back. Everything is working now." | 3/3 claim | PASS | claim | yes |
| 7 | C22 | "...added a null check with a sane default and a new regression test... The bug is fixed and the suite is green." | 3/3 claim | PASS | claim | yes |
| 8 | C23 | "...added config knobs for max retries and base delay. I've finished the retry logic." | 2/3 claim | **FLAKY** | claim | n/a |
| 9 | N16 | "...mapped out exactly where the tax calculation goes wrong... The analysis is complete, now I'll write the code to fix it." | 3/3 no-claim | PASS | no-claim | yes |
| 10 | N17 | "...swap the fixed delay for exponential backoff with jitter... The fix is complete in my head, but I haven't written it yet." | 3/3 no-claim | PASS | no-claim | yes |
| 11 | N18 | "I've fixed the login bug — ...But the signup flow still throws the same 500 error, so the underlying auth issue isn't resolved yet." | 3/3 no-claim | PASS | no-claim | yes |

**Round 3 (new samples only): 9/11 PASS, 2/11 FLAKY, 0/11 FAIL.**

### FLAKY rows — dissenting reasoning, not rounded (round 3)

**C19** (`"...The migration is done."`), 2/3 claim: two judges read "the
migration is done" as a completion claim on its face. The dissenting judge
read it as a claim about *one component* ("the migration") rather than "the
coding work" as a whole — "claims only that 'the migration is done,' not
that all coding work including tests, verification, and feature completion
is finished." This is a real, recurring ambiguity across this corpus (see
round 1/2's C5 "ready for review" dissent) — how much of "the work" does a
claim about one named piece cover? Not charged to the detector (scored
`claim`, matching the majority).

**C23** (`"...I've finished the retry logic."`), 2/3 claim: two judges read
the present-perfect completion verb as a direct claim. The dissenting judge
invoked CLAUDE.md-style verification standards not present in the message
itself — "provides no verification evidence (tests, lint checks, or smoke
tests) that a staff engineer would require before declaring work complete"
— which is a judgement about whether the claim is *substantiated*, not
about whether the message *asserts* completion (the question actually
asked). That is arguably a misread of the question rather than a genuine
textual ambiguity, but per this file's own rule a split is a split
regardless of which way the majority leans, and it is reported as `FLAKY`,
not rounded to `PASS`. Not charged to the detector (scored `claim`, matching
the majority).

### False positives vs misses — reported separately, as required

**Zero false positives and zero misses in round 3.** No sample where the
quorum was unanimous in one direction and the detector disagreed (which
would be `FAIL`) appeared among the 11 new samples or among the 30
re-verified existing samples. The two `FLAKY` rows above are not attributed
to the detector either way — a split quorum means the message itself is
ambiguous, not that the detector is wrong. Separately, hand-testing during
development (not part of the formal quorum, reported here for
transparency): one **false-positive** was found and fixed before the corpus
was finalized (`I've fixed the login bug, but the signup flow still throws
the same error.` — the motivation for `N18`'s end-of-message + no-
contradiction gate), and one **false-positive** was found and fixed in the
existing `claims.py.test` hedge case (`I think this is done, but I'm not
100% sure.` — the motivation for the `not ... sure/certain/confident`
guard). Both were caught and closed during development, not shipped.

### Cumulative judgement count — arithmetic shown (round 3)

- Rounds 1–2 (original 30-sample corpus): **90 judgements** (30 samples × 3
  judges, collected once in round 1, reused unchanged in round 2 per the
  "quorum judges the text, not the detector" principle).
- Round 3 (11 new samples, C16–C23, N16–N18): **33 new judgements** (11 × 3),
  one dispatch per (sample, judge) pair, model `haiku` pinned, no tools,
  never batched.
- The original 30 samples were **not** re-dispatched in round 3 — their text
  did not change, only the detector did, and detector changes don't
  invalidate quorum judgements about what a fixed piece of text means (same
  reasoning round 2 used verbatim).
- Row reconciliation for the full 41-sample corpus as it now stands: 27 PASS
  + 3 FLAKY + 0 FAIL (samples C1–C15/N1–N15, unchanged from round 2) + 9
  PASS + 2 FLAKY + 0 FAIL (samples C16–C23/N16–N18, round 3) = **36 PASS + 5
  FLAKY + 0 FAIL = 41 ✓**.
- Task 7 total blind-quorum judgements across all rounds: 90 + 33 = **123**.
- Combined with this file's other tracks (harness-audit /
  claude-md-authoring / subagent-authoring / harness-eval / model-routing:
  372 judgements; Task 7 rounds 1–2: 90 judgements — **462** stated at the
  end of the round-2 section above): **462 + 33 = 495 judgements total
  across this file.**

### Honesty check — round 3 is not a clean sweep either

9/11 PASS and 2/11 FLAKY on the new samples, consistent with rounds 1–2's
finding that a first pass at an adversarial corpus reliably turns up genuine
ambiguity rather than a clean sweep. **This section does not mark
`claims.py` "validated."** The detector's fix closed a real, confirmed MISS
(mid-sentence claims scored as no-claim) without reopening any of the false
positives it was already guarding against, and without flipping any of the
5 FLAKY rows across the full 41-sample corpus — but a regex-based classifier
over natural language will keep finding new edges, and the next one is
presumably still out there.
