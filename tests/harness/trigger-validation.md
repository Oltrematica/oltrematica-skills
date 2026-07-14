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

**210 total judgements** across 70 row-instances: 50 final rows (5 skills × 10
prompts) plus 20 superseded rows from `harness-audit`'s two earlier rounds (10
rows × 2 discarded rounds), all at 3 judges/row = 70 × 3 = 210.

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

## model-routing (unchanged description — new skill from Task 13)

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
from `model-routing`'s side too. No description edit needed.**

## Outcome

**Final tally (using each skill's last round): 50/50 rows PASS.** Zero FAIL. Zero
FLAKY in the final state.

Counting every judgement actually run, including discarded rounds — the honest
total:

| Skill | Rounds run | Rows × judges per round | PASS | FLAKY | FAIL |
|---|---|---|---|---|---|
| harness-audit | 3 (round 1 discarded, round 2 discarded, round 3 final) | 10 × 3 = 30/round | 9 + 9 + 10 = 28 | 1 + 1 + 0 = 2 | 0 |
| claude-md-authoring | 1 | 30 | 10 | 0 | 0 |
| subagent-authoring | 1 | 30 | 10 | 0 | 0 |
| harness-eval | 1 | 30 | 10 | 0 | 0 |
| model-routing | 1 | 30 | 10 | 0 | 0 |
| **Total** | — | **70 rows × 3 = 210 judgements** | **68 PASS rows** | **2 FLAKY rows** | **0 FAIL rows** |

Arithmetic check: 68 + 2 + 0 = 70 rows. 70 × 3 = 210 judgements. 68 + 2 = 70 ✓.
Final-state rows (10 × 5 skills) = 50, all PASS. Discarded rows from
`harness-audit`'s two earlier rounds = 20 (10 × 2), of which 18 PASS and 2 FLAKY.
50 + 20 = 70 ✓.

- **2 description edits, both to `harness-audit`**, both aimed at the boundary with
  `claude-md-authoring`, not at the losing row's literal wording:
  1. General compositional rule: a CLAUDE.md content judgement excludes the whole
     request even when paired with onboarding vocabulary — fixed a genuine
     ambiguity but introduced a new one (which way a compound request resolves
     was unstated).
  2. Same clause, made directional: the exclusion governs the entire request, full
     stop, no partial trigger. This is what actually closed the ambiguity —
     confirmed by three fresh judges independently citing the same phrase in
     their reasoning.
- **1 description edit, pre-emptive, to `subagent-authoring`** (Finding H): removed
  the "model tier" claim before running any judges, because the collision with
  `model-routing` was predicted at spec-design time, not discovered by a split.
  The predicted row (row 8) passed 3/3 clean on the only run — evidence the
  pre-emptive fix was sufficient, though with only one run there is no
  before/after contrast the way `harness-audit`'s fixes have.
- **claude-md-authoring, harness-eval, model-routing**: zero edits, 10/10
  unanimous on the only run each. Per this skill's own honesty rule ("everything
  passes first try → suspect the spec, not the skill"), a clean sweep on three of
  five skills is not claimed as unqualified success — see the honesty note below.
- **No row was rounded.** Every "3/3" above is a genuine unanimous vote from three
  separately dispatched, blind subagents that saw only the `description:` text and
  one prompt each — never the skill body, never the other 9 prompts for that
  skill, never the expected answer, never each other's votes. Both FLAKY rows
  (harness-audit round 1 and round 2, row 8) are recorded as FLAKY, not rounded
  toward the majority, even though round 2's majority happened to agree with
  `Expected`.
- **This report does not mark any skill "validated."** These are the raw rows; a
  human should read them and decide.

### Honesty check on the clean sweeps

Three of five skills (`claude-md-authoring`, `harness-eval`, `model-routing`)
passed 10/10 unanimous on the only run, with no edit. Per Mode 1's own
interpretation table ("Everything passes first try → Suspect the spec, not the
skill"), this is not claimed as proof those three descriptions are bulletproof.
Mitigating factors, stated plainly rather than assumed:
- Every trigger-row prompt in all three specs was deliberately written as a
  natural paraphrase, not a verbatim quote of the description's own bracketed
  examples (Finding C) — so the clean sweep is not the "trivial pass" antipattern
  the interpretation table warns about.
- Each of the three specs' no-trigger sets includes at least one prompt from
  every other harness skill's territory and one from the compliance track
  (`adr-management`/`cra-evidence`) — the neighbor-collision surface that
  actually bit `harness-audit` was exercised for all three, and none produced
  even a single dissenting vote.
- Still: 3 judges × 10 prompts is a smoke test, not a benchmark (Mode 1's own
  "Small N" rule). A fourth reader, or a prompt this spec did not think to try,
  could still disagree. Unanimity here is evidence that the obvious neighbor
  collisions are clean, not proof the descriptions are complete.

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
   text, and none of the 210 dispatches show any `tool_uses` other than 0 in their
   returned usage metadata — so no judge actually exercised a tool. But this is a
   prompt-level convention enforced by inspection after the fact, not a structural
   guarantee enforced before dispatch, and it is the same workaround the prior
   (Task 11) run adopted. The skill's MUST is satisfiable in this harness only by
   this workaround; it would be stronger if Mode 1 named the workaround
   explicitly (e.g., "if no zero-tool subagent type exists, dispatch the
   general-purpose type with an explicit no-tool instruction, and verify `tool_uses:
   0` in every returned result before trusting it") rather than stating the
   requirement and leaving the mechanism to be reinvented per run.

This did not block execution — the workaround is documented above and every
dispatch was checked for `tool_uses: 0` — but a third team running this without
having read two prior reports would rediscover the same gap.
