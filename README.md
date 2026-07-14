# Oltrematica Skills

Claude Code skills for the Oltrematica portfolio: five skills that build,
audit and test the Claude Code harness itself — stack-agnostic, useful in
any repo — plus two skills that produce EU-regulatory compliance evidence
(CRA, EAA).

## The catalogue

| Skill | Track | What it's for |
|---|---|---|
| [`harness-audit`](skills/harness/harness-audit/) | Harness | Entry point — inventories the 8 harness surfaces, reports present/gap/not-applicable |
| [`claude-md-authoring`](skills/harness/claude-md-authoring/) | Harness | Writes and repairs `CLAUDE.md` as policy, not procedure |
| [`subagent-authoring`](skills/harness/subagent-authoring/) | Harness | Chooses skill vs. subagent vs. slash command vs. hook, then authors it |
| [`harness-eval`](skills/harness/harness-eval/) | Harness | Proves a skill's trigger actually fires — or doesn't |
| [`model-routing`](skills/harness/model-routing/) | Harness | Diagnoses usage-limit complaints, recommends model tier / subagent split |
| Verification gate (Stop hook) | Harness — **plugin only** | Blocks a "done" claim when a source file changed after the last passing test run |
| [`adr-management`](skills/compliance/adr-management/) | Compliance | Drafts Architecture Decision Records proactively for significant decisions |
| [`cra-evidence`](skills/compliance/cra-evidence/) | Compliance | Generates and maintains the CRA/SBOM/EAA evidence package |

**Harness track (5 skills + the verification gate) is stack-agnostic** — it
applies to any repo, regardless of language or regulatory exposure.
**Compliance track (2 skills) is EU-regulatory** — it exists for CRA and EAA
obligations. If you don't ship software into the EU, the harness track is
still fully for you; feel free to skip the other two.

## Which stacks are supported

`harness-audit`'s surface inventory and the verification gate's stack
detection (`skills/harness/harness-audit/scripts/lib/verify_gate.sh`) work
against any of: **PHP, Node (JS/TS), Python, Go, Rust, Ruby, Java/Kotlin,
.NET, and Elixir**, plus a bare `Makefile test:` target. This is verified,
not asserted — see the 137 checks in `tests/harness/verify_gate.sh.test`
under [How this repo tests itself](#how-this-repo-tests-itself).

## Install

### Plugin (primary)

```bash
claude plugin marketplace add https://github.com/Oltrematica/oltrematica-skills.git
claude plugin install oltrematica-skills@oltrematica
```

This is the only path that installs the Stop-hook verification gate
alongside the seven skills. Default scope is `user` (every project on your
machine); pass `--scope project` to commit it to the repo's own
`.claude/settings.json` for the whole team.

Verified live on this branch — added the marketplace from a local path,
installed the plugin into a scratch project, then ran
`claude plugin details oltrematica-skills@oltrematica`:

```
Skills (7)  adr-management, claude-md-authoring, cra-evidence, harness-audit,
            harness-eval, model-routing, subagent-authoring
Hooks (2)   PostToolUse, Stop
```

Full scope options, update commands, and the verification transcript (incl.
the URL-form command, re-verified once this branch reaches `main`):
[`docs/distribution.md`](docs/distribution.md). Before relying on the gate to
block anything, read
[what it does and does not guarantee](docs/harness/verification-gate.md).

### `scripts/install.sh` (fallback — **skills only, no verification gate**)

Use only if you cannot add a marketplace (offline CI runner, no outbound git
access, policy blocks it). It copies skill directories as plain files; it
cannot install hooks — the gate needs `${CLAUDE_PLUGIN_ROOT}`, which only the
plugin loader sets, so a plain file copy has nothing for the hook scripts to
attach to.

```bash
git clone https://github.com/Oltrematica/oltrematica-skills.git /tmp/os
/tmp/os/scripts/install.sh <skill-name>... --to /path/to/your-repo
```

Run with no arguments to list every skill from both tracks. You can mix
tracks in one invocation:

```bash
/tmp/os/scripts/install.sh adr-management cra-evidence harness-audit --to /path/to/your-repo
```

**Commit** `.claude/skills/` in a project so the whole team gets the skill on
pull. **Verify:** restart Claude Code (or start a new session) in the target
repo and run `/skills` — the installed skill should be listed.

Full detail — personal scope, updating, the submodule option, why a plain
copy is safe — in [`docs/distribution.md`](docs/distribution.md).

## The contract

One contract binds every skill in both tracks:

- **Claude drafts, humans approve.** No artifact — ADR, SBOM, gap report,
  harness audit — is ever marked `Accepted`, `Compliant`, `Passing` or
  `Validated` by Claude on its own initiative. Everything ships `Proposed` or
  `Draft` until a human says otherwise.
- **Evidence, never assertion.** Every report states one of exactly three
  outcomes per item — **present**, **gap**, or **not applicable** — each with
  a pointer or a rationale. "Looks good" is not an output this repo produces;
  where it shows up, it's a bug.

## The two theses

**Compliance fails through friction, not ignorance.** Nobody doubts an SBOM
matters. Nobody regenerates one mid-sprint anyway, because nothing forces the
moment — there's a release to ship, and "regenerate the SBOM" competes with
that for attention and loses, every time, until an auditor or a regulator asks
for it and it doesn't exist. The `cra-evidence` skill exists to remove the
moment of choice: it does the assembly work as a side effect of the release
happening, not as a separate task someone has to remember to schedule. The
regulatory clock makes the friction expensive rather than theoretical — CRA
vulnerability-reporting obligations apply from **2026-09-11**, full CRA
obligations from **2027-12-11**, and the EAA has been in force since
**2025-06-28**.

**The harness fails through invisibility.** A `CLAUDE.md` grows past the point
where the agent can hold all of it and starts quietly dropping the half that
matters. A skill's `description:` drifts until it fires on everything, or on
nothing. Neither failure throws an error. Nobody sees a stack trace when a
skill stops triggering — they see an agent that used to catch a class of
mistake and no longer does, and the natural read is "the model got worse,"
not "our scaffolding rotted." The harness track's premise is that this
scaffolding is a maintained artifact like any other code: it can be
inventoried (`harness-audit`), authored deliberately
(`claude-md-authoring`, `subagent-authoring`), and — the part almost nobody
does — **tested** (`harness-eval`). `model-routing` was added mid-plan, for a
mirror reason: teams were hitting the five-hour usage limit and assuming the
fix was model choice, when the actual cost driver is usually context
accumulated in a long session, not the model tier.

Put the two together and the shape of the repo is one idea, applied twice:
**the things that quietly rot are the things nobody is required to verify.**
Both tracks answer that by producing evidence instead of confidence, and by
never letting Claude grade its own homework.

## Skill reference

The catalogue above, in detail: real trigger phrasing and what each skill
produces.

### Compliance track

| Skill | What it does | Triggers on (real phrasing) | Produces |
|-------|--------------|------------------------------|----------|
| [`adr-management`](skills/compliance/adr-management/) | Drafts Architecture Decision Records proactively whenever a significant decision is made, discussed or discovered — the human only reviews. | "document this decision", "why did we choose X", choosing/replacing a library or framework, a DB or auth strategy, an infra change, a breaking change or deprecation — even if nobody says "ADR" | `docs/adr/NNNN-slug.md`, status `Proposed`, plus an updated index |
| [`cra-evidence`](skills/compliance/cra-evidence/) | Generates and maintains the CRA/SBOM/EAA evidence package: SBOM, release-to-release SBOM diff, vulnerability scan and triage drafts, Annex I gap report, EAA/WCAG accessibility module. | "prepare the release", "cut v2.3", "are we CRA ready?", "check our dependencies", "any known CVEs?", "generate an SBOM", accessibility/EAA/WCOG/a11y requests | `compliance/COMPLIANCE.md` dossier, `compliance/sbom/`, `compliance/vulns/*.md`, `compliance/a11y/` |

### Harness track

| Skill | What it does | Triggers on (real phrasing) | Produces |
|-------|--------------|------------------------------|----------|
| [`harness-audit`](skills/harness/harness-audit/) | Inventories the 8 harness surfaces and reports present/gap/not-applicable for each. The entry point — start here. | "our .claude folder is a mess", "get this repo ready for Claude", "is our Claude setup any good?", "what's missing from our .claude directory?" | `docs/harness-audit.md`, status `Proposed` |
| [`claude-md-authoring`](skills/harness/claude-md-authoring/) | Writes and repairs `CLAUDE.md` as policy, not procedure. Diagnoses "the agent keeps ignoring X". | "this file has ballooned to 800 lines", "Claude keeps skipping the testing rule", "our CLAUDE.md is too long", "clean up our CLAUDE.md" | A CLAUDE.md diff, proposed not merged |
| [`subagent-authoring`](skills/harness/subagent-authoring/) | Chooses between skill, subagent, slash command and hook, then authors the chosen artifact. | "I want a subagent for research", "should this be a skill or a command?", "make this run automatically every time", "add a /deploy command" | `.claude/agents/*.md`, `.claude/commands/*.md`, or a hand-off to `update-config` for hooks |
| [`harness-eval`](skills/harness/harness-eval/) | Proves a skill actually fires when it should and stays quiet when it shouldn't; proves a harness change helped. | "does this skill trigger?", "the skill fires on everything", "why didn't Claude use the skill?", "did that change actually work?" | An evidence table — verdicts `PASS`/`FAIL`/`FLAKY`, never a verdict of "validated" |
| [`model-routing`](skills/harness/model-routing/) | Decides which model tier a task needs, whether a subagent is the cheaper move, and diagnoses the usage-limit complaint. | "why do I keep hitting the usage limit?", "this is burning through my usage", "should this run on Opus or Haiku?", a session that abruptly "dies" partway through | A routing recommendation, optionally a `CLAUDE.md` policy block |

Background: [`docs/harness/brief.md`](docs/harness/brief.md).

## How the skills compose

Run `harness-audit` first. It is the only skill in either track designed as
an entry point rather than a destination: it does not fix anything itself,
it produces one `Proposed` report — eight surfaces, each present, a gap, or
not applicable — and then hands each gap to the skill (or the built-in
capability) that owns the fix:

| Gap `harness-audit` finds | Handed to |
|---|---|
| `CLAUDE.md` missing, bloated, or carrying procedure instead of policy | `claude-md-authoring` |
| Needs a subagent, a slash command, or a hook | `subagent-authoring` |
| A skill's description over- or under-triggers | `harness-eval` |
| A genuinely new skill is needed | the built-in **Superpowers** `writing-skills` skill, plus this repo's [`docs/contributing-skills.md`](docs/contributing-skills.md) |
| No verify gate declared | Claude Code's built-in **`verify`** skill bootstraps one |
| Hooks need wiring into `settings.json` | Claude Code's built-in **`update-config`** skill — the only thing allowed to touch that file |
| No model-routing policy declared | `model-routing` |

The other four harness skills also hand off *to each other* at their own
boundaries, not just from `harness-audit`: `claude-md-authoring` hands a
"should this be a hook?" question to `subagent-authoring`, and a "does this
change actually help?" question to `harness-eval`'s Mode 2 (behavioral
regression). `subagent-authoring` hands the model-tier decision — deliberately
kept out of its own scope — to `model-routing`. None of the five re-implements
planning, TDD, debugging or code review; those hand off outward, to
**Superpowers**, every time (see below).

The compliance track composes internally the same way: `cra-evidence`'s W2
(release evidence) workflow produces triage drafts, and any triage decision
with architectural weight — "accept this CVE as non-exploitable", "pin this
dependency instead of upgrading" — hands off to `adr-management` (W5) rather
than re-implementing ADR numbering and lifecycle a second time.

`harness-audit` explicitly does **not** judge a single file's content or
tone — the moment a request includes a judgement about `CLAUDE.md` itself,
that routes to `claude-md-authoring` even if the same sentence also uses
onboarding vocabulary. And it does not judge product compliance readiness —
"are we CRA ready?" is `cra-evidence`'s question, not this skill's, even
though both skills use words like "ready" and "audit". Both boundaries were
found to be genuinely ambiguous by the trigger-validation quorum before being
tightened; see below.

## The 8 harness surfaces

`harness-audit`'s `scripts/inventory.sh` reports exactly these eight keys —
verified by running the script, not read off a slide:

```
claude_md, skills, agents, commands, hooks, mcp, verify_gate, model_routing
```

What a gap in each one actually costs:

| Surface | A gap costs |
|---|---|
| **`claude_md`** | The agent has no declared policy for the repo — no scope, no mandates, no definition of "done" — so it improvises one per session, inconsistently. |
| **`skills`** | Recurring procedures live only in someone's memory or in `CLAUDE.md` prose that competes with everything else for attention, instead of a self-triggering, on-demand capability. |
| **`agents`** | Read-heavy work (a 40-file survey, a review) happens in the main conversation, and every file read gets re-sent on every subsequent turn for the rest of the session — the exact mechanism `model-routing` exists to explain. |
| **`commands`** | The team keeps pasting the same prompt by hand, with the drift and typos that implies, instead of firing a saved one. |
| **`hooks`** | Things that must happen *every single time* — formatting, lint, secret-blocking — are instructions instead of deterministic scripts, so they get skipped under time pressure, silently. |
| **`mcp`** | An external system the agent genuinely needs is accessed through ad-hoc shell commands instead of a configured integration — more fragile, less auditable. |
| **`verify_gate`** | Nobody told the agent how to prove its work, so "done" means "looks right to the agent," which is exactly the unverified assertion this whole repo's contract exists to prevent. |
| **`model_routing`** | Every task defaults to the most capable model tier by default, and the team hits the usage limit on work that never needed it. |

`harness-audit` warns about its own instrument here too: if `inventory.sh`
comes back near-empty on every surface, that is more often a mis-targeted
audit — this repo's own `skills/<track>/<name>/` layout has no root
`CLAUDE.md` and would read as "all gaps" if pointed at itself — than a
genuinely empty harness. The skill is explicit that "all gaps" needs a sanity
check before it gets reported as a finding.

## How this repo tests itself

This is the section a skeptical reader should check hardest, because it's
also the one this repo is least entitled to get away with asserting.

### 435 automated checks, nine suites

```
tests/harness/verify_gate.sh.test        137 checks — stack detection and test-command
                                                        matching across 8 ecosystems
                                                        (PHP, Node, Python, Go, Rust,
                                                        Ruby, Java/Kotlin, .NET, Elixir)
tests/harness/state.sh.test               13 checks — the hook's key/value state store,
                                                        incl. an ENAMETOOLONG session-id
                                                        edge case
tests/harness/record_activity.sh.test     59 checks — PostToolUse activity recording:
                                                        which Bash patterns count as a
                                                        source edit, which count as a
                                                        passing test run
tests/harness/source_mutation.py.test     40 checks — the Bash-command text heuristic
                                                        that decides "did this command
                                                        just write to a file"
tests/harness/claims.py.test              46 checks — the completion-claim regex:
                                                        binary garbage, ~1MB input, and
                                                        unicode all exit clean, no crash
tests/harness/verify_before_done.sh.test  19 checks — the Stop hook itself: allow/block
                                                        decisions, stand-down conditions
tests/harness/inventory.sh.test           35 checks — inventory.sh's fact-finding, incl.
                                                        the fence-aware model-routing
                                                        heading detector and a missing-
                                                        python3 failure mode
tests/harness/eval_run.py.test            54 checks — the trigger-eval tooling itself:
                                                        spec validation, hostile input
                                                        (newlines, pipes, injected table
                                                        rows) rejected before it can
                                                        corrupt a Markdown table
tests/install.sh.test                     32 checks — the installer: flat layout, track
                                                        ambiguity, glob-name rejection,
                                                        reinstall behavior
                                                        ---
                                                        435 total
```

Run yourself:

```bash
for t in tests/harness/verify_gate.sh.test tests/harness/state.sh.test \
         tests/harness/record_activity.sh.test tests/harness/source_mutation.py.test \
         tests/harness/claims.py.test tests/harness/verify_before_done.sh.test \
         tests/harness/inventory.sh.test tests/harness/eval_run.py.test \
         tests/install.sh.test; do bash "$t"; done
```

All nine passed 100% at the point this README was written (137/137, 13/13,
59/59, 40/40, 46/46, 19/19, 35/35, 54/54, 32/32) — re-run them; a README
claiming a number is exactly the kind of unverified assertion this repo's
contract exists to prevent. CI (`.github/workflows/ci.yml`) runs the same
nine suites on `ubuntu-latest` and `macos-latest` on every PR.

### A fixture that is deliberately broken

[`tests/harness/fixtures/bad-harness/`](tests/harness/fixtures/bad-harness/)
is a repo built to fail every surface `harness-audit` checks, on purpose, and
its own `README.md` says outright: **do not "fix" these defects — they are
the test.** Five seeded defects, each mapped to the skill that must catch it:
a 190-plus-line `CLAUDE.md` that is pure procedure dump rather than policy
(D1); no `.claude/agents/` (D2); no `.claude/settings.json`, hence no hooks
(D3); no verify gate — `composer.json` has no `scripts.test` (D4); and a
`.claude/skills/do-everything/` whose description triggers on essentially any
prompt (D5) — the over-triggering failure mode `harness-eval` exists to
catch, planted as a working example rather than only described in prose.

### The adversarial trigger-validation quorum

Every skill's `description:` frontmatter is the *entire* test surface —
Claude sees only that text at trigger time, never the SKILL.md body. So the
ledger judges descriptions the same way: three independent subagents per
prompt, each shown **only** the description and one prompt, dispatched with
no filesystem or search tools and no visibility into the other two judges'
votes, the expected answer, or any other prompt in the spec. The full
procedure lives in `harness-eval`'s own SKILL.md; the ledger for the five
harness skills is
[`tests/harness/trigger-validation.md`](tests/harness/trigger-validation.md).

**Why blind:** a judge that can read the real SKILL.md body, or the repo it
lives in, is grading against material the router never has at trigger time.
That produces a confident, wrong result, not a cautious one.

**Why three:** triggering is a probabilistic decision. One judge returns one
sample of that decision and calls it evidence. Three judges can *disagree* —
and a 2-of-3 split is recorded as `FLAKY`, never rounded up to `PASS` just
because the majority happened to agree with the expected answer. A split is
the finding: it means a clause in the description reads two ways, and the
fix is to sharpen the clause, not to trust the majority vote.

The ledger's own count, read out of the file rather than asserted here:
**372 total judgements** across 124 row-instances (124 × 3 judges), covering
every round run — including five discarded `harness-audit` rounds and two
discarded `model-routing` rounds that turned up a real `FLAKY` split and one
genuine `FAIL` (a description under-triggering on "my session just died on me
again" — a real gap, closed by naming the symptom category rather than the
literal wording). The clean final state is 52/52 rows `PASS`, unanimous,
across all five harness skills — but the ledger keeps the failed rounds in
the file rather than only the final pass, on the theory that the rounds
before the clean sweep are the more informative part of the record. Small N:
ten-ish prompts per skill, judged three ways, is a smoke test for gross
triggering failures — not a benchmark, and the ledger says so itself.

The compliance track runs a lighter version of the same idea — single-pass
evaluation rather than a three-judge quorum, 20 rows across `adr-management`
and `cra-evidence`, in
[`tests/compliance/trigger-validation.md`](tests/compliance/trigger-validation.md) —
predating the harness track's quorum method. Read it as an earlier, less
adversarial iteration of the same practice, not as evidence held to the same
bar.

## Prerequisites

| Skill / track | Needs |
|---|---|
| `adr-management` | `bash`, `sed`, `find` — present by default on macOS and Linux |
| `cra-evidence` | `python3` (stdlib only), `syft` (SBOM generation, required), `grype` (primary vulnerability scanner) or `osv-scanner` (fallback), and — for the EAA module only — Node, `npx` and Chrome |
| Harness track (all 5 skills) | `bash`, `python3` (stdlib only), and the **Superpowers** plugin installed |

macOS quick install for the compliance scanners: `brew install syft grype`.

Every script degrades loudly rather than failing silently or dumping a stack
trace: a missing tool prints an install hint to stderr and exits non-zero.
`tests/harness/inventory.sh.test` specifically checks this for a missing
`python3` (exit 127, hint named, no traceback) — a behavior claim with a test
behind it, not just a sentence in this README.

## Dependency on Superpowers

The harness track is built assuming the
[Superpowers](https://github.com/obra/superpowers) plugin is already
installed, and deliberately does not re-implement anything it already owns.
**Superpowers owns *how to work*:** brainstorming, writing a plan, TDD,
systematic debugging, verification before claiming completion, code review,
and how to write a new skill in the first place. **This repo owns *what the
harness is made of, and whether it works*:** the inventory of surfaces, the
authoring conventions for `CLAUDE.md` and subagents, the trigger-eval
methodology, and the cost/routing model. Where a harness gap needs one of
Superpowers' workflows, our skills hand off by name — `harness-audit` points
a "needs a new skill" gap at Superpowers' `writing-skills`, `claude-md-authoring`
hands "does this change actually help?" to `harness-eval`'s regression mode,
which itself borrows nothing from Superpowers because proving a trigger fires
isn't a Superpowers workflow. Forking any of Superpowers' workflows into this
repo would buy independence at the cost of permanent drift between two
copies of the same idea — not worth it for either track.

## Repo map

| Path | Contents |
|------|----------|
| `skills/compliance/` | Compliance-track skills (`adr-management`, `cra-evidence`) |
| `skills/harness/` | Harness-track skills (`harness-audit`, `claude-md-authoring`, `subagent-authoring`, `harness-eval`, `model-routing`) |
| `.claude-plugin/` | Marketplace and plugin manifests (`marketplace.json`, `plugin.json`) — the primary install path |
| `hooks/` | The Stop-hook verification gate (`verify_before_done.sh`) and its PostToolUse activity recorder (`record_activity.sh`); shipped only via the plugin |
| `scripts/install.sh` | The fallback, skills-only installer (no hooks) — see [Install](#install) |
| `docs/harness/` | Harness track's brief and the verification-gate design doc |
| `docs/distribution.md` | Install options in full: scope ladder, submodule option, updating, prerequisites |
| `docs/contributing-skills.md` | House conventions for adding a skill to either track — short and binding |
| `tests/install.sh.test` | Installer behavior — 32 checks |
| `tests/harness/inventory.sh.test`, `tests/harness/eval_run.py.test` | Harness-tooling behavior — 35 + 54 checks |
| `tests/harness/trigger-validation.md` | The blind, 3-judge quorum ledger for all 5 harness skills |
| `tests/harness/fixtures/bad-harness/` | The deliberately broken repo `harness-audit`/`harness-eval` are tested against |
| `tests/compliance/` | Fixture repos (Laravel, Node, polyglot), script evidence notes, and the compliance track's own (lighter-weight) trigger validation |

## Contributing a skill

Read [`docs/contributing-skills.md`](docs/contributing-skills.md) first — it
is short and it is binding. The rules that actually bite:

- **The `description:` frontmatter *is* the router.** Claude sees it, and
  only it, when deciding whether to invoke a skill — the SKILL.md body is
  invisible at trigger time. A "do NOT use this for X" carve-out in the body
  cannot prevent a false trigger; it has to live in the description, and it
  has to be tested there (at least 5 trigger and 5 no-trigger prompts,
  including a neighboring skill's territory, recorded in
  `tests/<track>/trigger-validation.md`).
- **One skill, one capability.** If the SKILL.md body needs a branch that
  says "but when it's actually about X, do something entirely different,"
  that is two skills, not a conditional in one.
- **Progressive disclosure.** SKILL.md body stays under 500 lines.
  Deterministic operations go to `scripts/`; long reference material goes to
  `references/`, loaded on demand instead of paying for it on every
  invocation.

## License

MIT — Copyright © 2026 Oltrematica. See [LICENSE](LICENSE).
