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
