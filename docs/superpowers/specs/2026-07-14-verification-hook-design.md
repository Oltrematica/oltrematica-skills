# Design — Verification Hook + Plugin Packaging

**Date:** 2026-07-14
**Owner:** Andrea Margiovanni
**Status:** Approved (design), not yet implemented
**Builds on:** `2026-07-14-harness-skills-track-design.md` (the harness track, now merged)

---

## 1. Problem

The harness track shipped seven skills. Every one of them is **advisory**. A skill is a
procedure a model *should* follow, and a model under pressure drops procedures — silently.

The catalogue itself says so. `subagent-authoring` states the rule plainly:

> If it must happen **every time**, without exception, it is not an instruction — it is a
> **hook**. Instructions are probabilistic. Hooks are deterministic.

And then we shipped **zero hooks**. We wrote the rule and did not apply it to ourselves.

The single most-ignored rule in the Oltrematica `CLAUDE.md` is the one that matters most:

> **Never declare a task complete without proving it works.**

Today that is a sentence in a file. This design makes it physics.

## 2. Goals

1. An agent cannot end a turn claiming the work is done when the tests are stale.
2. Enforcement arrives centrally, without editing `settings.json` in ~190 repositories.
3. The hook is proven to work before it ships — held to the same standard it enforces.

## 3. Non-goals

Scope is deliberately, aggressively narrow: **one hook, one rule.**

Explicitly cut, and **not** to be smuggled back in during implementation:

- Secret / debug-artifact scanning
- Blocking `composer require` / `npm install` without permission
- Blocking commits to `main`
- Auto-formatting on edit (Pint)
- Cost / delegation coaching

Each is defensible. None is this change. They can each be their own hook later, on the
infrastructure this design creates.

## 4. The rule

The `Stop` hook blocks the agent from ending its turn **if and only if both** hold:

1. The final assistant message **claims completion**, and
2. A **source file was modified after the last passing test run**.

### Why "stale", not "absent"

The naive rule is *"did the tests run this session?"*. It is wrong, and it waves through
the exact failure it exists to catch: an agent runs the suite, makes one more edit, and
declares victory. The tests passed — against code that no longer exists.

So the hook compares **timestamps**, not existence: if `last_source_edit > last_passing_test`,
the evidence is stale and the claim is not earned.

### What counts as a "source file"

Anything with a runtime surface — code the tests could conceivably exercise. Concretely:
**everything except** `*.md`, `LICENSE`, and files under a docs directory.

The exemption list is deliberately short and deliberately *not* clever. A generous exemption
list is an attack surface: every path we excuse is a path an agent can edit and still claim
done. When in doubt, a file counts as source, and the cost of being wrong is one test run.

Note that **test files themselves count as source.** Editing a test after the suite went
green means the green is stale — which is precisely the rule.

### When it does not fire

- **No source file was touched this turn.** A docs-only turn needs no test run. Enforcing
  there is tyranny, and tyranny gets the pack uninstalled.
- **The repository declares no test command.** The hook cannot enforce what the repo cannot
  run. It says so, once, and stands down (§7).
- **The message makes no completion claim.** Asking a question, reporting a partial result,
  or requesting input are all legitimate ways to end a turn.

## 5. Architecture

Three cooperating hooks and one session state file. No transcript parsing — the docs warn
that `transcript_path` lags and may not contain the current turn.

```
PostToolUse(Bash)        ─┐
  test command matched?   │   writes  →  <state>/<session_id>.json
  → record last_test_pass │              { "last_test_pass": <ts>,
                          │                "last_source_edit": <ts>,
PostToolUse(Write|Edit)  ─┤                "test_cmd": "...",
  source file touched?    │                "warned_no_gate": bool }
  → record last_source_edit
                          │
Stop                     ─┘   reads   →  decide
  claim? AND stale? → exit 2 (block, with the reason)
  otherwise         → exit 0 (allow)
```

**Why a state file rather than the transcript:** it is deterministic, it is cheap, and it
does not depend on a file the platform documents as lagging.

**Test-command detection is not reinvented.** `harness-audit`'s `inventory.sh` already
detects a repository's verify gate (`composer.json scripts.test`, `package.json scripts.test`,
a `Makefile` `test:` target, a CI workflow). That logic is extracted into a shared helper and
used by both. One definition of "how this repo runs its tests", not two that drift.

**"Passing", not merely "ran".** `PostToolUse` receives `tool_response`; a test command that
exited non-zero does not update `last_test_pass`. A failing suite is not evidence of anything.

## 6. Claim detection — the soft joint

Whether a message "claims completion" is a judgement, not a fact. We are not going to assert
that a regex gets it right. We are going to **prove it**, with the method this repo already
uses for exactly this class of problem.

`harness-eval`'s blind quorum, pointed at the detector: a corpus of final-message samples —
**at least 15 that claim completion, at least 15 that do not** — each judged by three
independent blind subagents. The detector's output is compared against the quorum's verdict.

- A **false negative** (the detector misses a real claim) is a hole: the hook fails to fire.
- A **false positive** (the detector fires on "done reading the file") is worse: it blocks
  legitimate work, and it is how the pack gets switched off.

Both are recorded in the ledger. A split quorum on a sample is `FLAKY` — the sample is
ambiguous and the detector is not charged with it. Same rule as everywhere else: **never
round a split into a pass.**

The corpus must include the adversarial cases: "done reading the file", "that's done, now
for the next part", "the tests should pass now" (a prediction, not a claim), "fixed the typo
in the README" (a claim, but no source change — the second condition saves us).

## 7. Failure modes — every one of these is how the hook gets uninstalled

**Fail open, loudly.** If the state file is unreadable, the test command undetectable, or the
script throws — **allow the turn to end** and print why. A verification hook that hard-blocks
because *it* is broken will be disabled within a day, and then it enforces nothing, forever.
Exit 2 is reserved for the one condition the hook actually understands.

**Exit 1 is a trap.** Claude Code treats exit 1 as **non-blocking**. A policy hook that exits
1 fails open *silently* and looks like it is working. Every block path exits **2**, and a
contract test asserts it — this is precisely the bug class that never surfaces on its own.

**Loop guard.** A blocking `Stop` hook can, in principle, block forever. The platform caps it
at 8 consecutive blocks; we do not rely on that. We read `stop_hook_active` from stdin and
stand down ourselves.

**The escape hatch is honest, or it becomes the default.** The block message states exactly
how to satisfy it — run the tests — and a human can always override in conversation. We do
**not** build a silent bypass flag. A bypass nobody can see becomes the happy path within a
month.

**No gate, no silence.** A repo with no declared test command cannot be enforced. The hook
warns **once per session** (`warned_no_gate`), points at `harness-audit`, and allows. Warning
on every turn is noise; warning never is a lie.

## 8. Packaging — the plugin

The repository becomes a Claude Code plugin with a marketplace manifest at its root.

```
.claude-plugin/marketplace.json     # the marketplace
plugin.json                         # the plugin
hooks/hooks.json                    # hook wiring (PostToolUse ×2, Stop)
hooks/scripts/*.sh|*.py             # the hook implementations
skills/                             # existing skills, now shipped by the plugin too
```

Teams run `/plugin marketplace add Oltrematica/oltrematica-skills` **once**. Hooks and skills
then arrive together and update centrally.

**Why the plugin is load-bearing here, not merely tidy:** hooks live in `settings.json`. The
alternative is editing that file in ~190 repositories, and re-editing all of them on every
update, merging against whatever each team has independently put there. Plugin hooks **merge
automatically** across scopes without touching anyone's settings. That is a functional
difference, not a packaging preference.

`scripts/install.sh` survives as the fallback for repositories that cannot use the
marketplace. It is no longer the primary path.

Scripts resolve their own paths via `${CLAUDE_PLUGIN_ROOT}`; state is written under
`${CLAUDE_PLUGIN_DATA}` where available, falling back to a temp dir keyed by session id.

## 9. How we prove it works

This hook enforces *"prove it before you claim it."* Shipping it unproven would be the exact
error the repository exists to prevent.

1. **Contract tests** on every script: block path exits 2 (not 1); stale detection is correct
   across the timestamp boundary; fail-open on every error path; loop guard honours
   `stop_hook_active`; malformed stdin never produces a traceback.
2. **A fixture that must be caught.** Extend `tests/harness/fixtures/` with a scenario where
   source is edited *after* a passing test run and the turn claims completion. The hook must
   block it. A hook validated only against the happy path proves nothing — the same reason
   `bad-harness` exists.
3. **The blind quorum on the claim detector** (§6), with the corpus and results committed to
   the ledger alongside the trigger-validation tables.

## 10. Decisions

| # | Decision | Rationale |
|---|---|---|
| H-1 | Graduated posture: block facts, coach judgement | A hard block on a judgement call blocks legitimate work; the first person it burns disables the pack for everyone |
| H-2 | One hook, one rule | The cut rules (secrets, deps, main-branch, formatter, cost coaching) are each defensible and each their own change |
| H-3 | Stale-tests semantics, not tests-ran | "Ran at some point" waves through the exact failure being targeted |
| H-4 | State file, not transcript parsing | The platform documents `transcript_path` as lagging the current turn |
| H-5 | Plugin packaging | The only option that does not require editing — and re-editing — `settings.json` in ~190 repos |
| H-6 | Reuse `inventory.sh`'s verify-gate detection | One definition of "how this repo runs its tests"; two would drift |
| H-7 | Fail open, loudly, on every error the hook does not understand | A hook that blocks because it is broken gets uninstalled, and then enforces nothing forever |

## 11. Open questions

None blocking.

Deferred: whether the cut rules (§3) become a second hook wave once this one has run in a
real repository for a sprint. That decision should be made on evidence from the first, not
in advance.
