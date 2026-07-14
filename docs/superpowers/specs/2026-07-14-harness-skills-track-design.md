# Design — Harness Engineering Skills Track

**Date:** 2026-07-14
**Owner:** Andrea Margiovanni
**Status:** Approved (design), not yet implemented
**Supersedes nothing.** Extends `2026-07-09-compliance-skills-repo-design.md`,
which remains authoritative for the compliance track.

---

## 1. Problem

The repo ships two compliance skills and presents itself, in its name, README
and every doc, as the *Oltrematica Compliance Skills Program*. We now want
skills that help developers do **harness engineering**: building, operating and
evaluating the scaffolding that coding agents run inside (`CLAUDE.md`, skills,
subagents, hooks, commands, verification gates).

That breaks the current framing. A repo whose name and docs say "compliance"
cannot credibly hold a second, unrelated track. Both the content and the
identity have to change.

## 2. Goals

1. Developers can bootstrap, audit and improve a repo's agent harness through
   skills, not folklore.
2. A harness change can be *proven* to help, not merely asserted to help.
3. The repo reads as a skills catalogue with two tracks, and the next track
   costs nothing structurally.
4. No installed skill anywhere in the estate breaks as a result.

## 3. Non-goals

- **No re-implementation of Superpowers.** These skills assume the Superpowers
  plugin is installed and declare that dependency. Planning, TDD, debugging,
  verification and code review are Superpowers' territory; we do not fork them.
- **No hooks-authoring skill.** Claude Code's built-in `update-config` skill
  already owns `settings.json`. `harness-audit` points at it.
- **No MCP-authoring skill.** Out of scope for this track.
- **No skill-authoring skill.** Superpowers `writing-skills` covers it; our
  house conventions go in `docs/contributing-skills.md` instead.

## 4. Repo restructure

Rename `oltrematica-compliance-skills` → **`oltrematica-skills`**. GitHub
redirects the old clone URL indefinitely, so rollout emails already sent keep
working; every in-repo reference is updated regardless.

```
oltrematica-skills/
├── README.md                            # catalogue: two tracks, contract, install
├── scripts/install.sh                   # NEW — install <skill>... into a target repo
├── skills/
│   ├── compliance/
│   │   ├── adr-management/              # moved, content unchanged
│   │   └── cra-evidence/                # moved, content unchanged
│   └── harness/
│       ├── harness-audit/
│       ├── claude-md-authoring/
│       ├── subagent-authoring/
│       └── harness-eval/
├── docs/
│   ├── contributing-skills.md           # NEW — house conventions for both tracks
│   ├── distribution.md                  # rewritten for the new source paths
│   ├── compliance/                      # development-brief, ci-gate-proposal, rollout-note
│   └── harness/                         # brief.md, rollout-note.md
└── tests/
    ├── compliance/                      # existing fixtures + notes, moved
    └── harness/                         # trigger validation + a bad-harness fixture
```

### Install paths do not break

Claude Code requires `.claude/skills/<name>/SKILL.md` in the **target** repo.
The source layout in this repo is unconstrained. The destination half of every
install command is therefore unchanged:

```bash
cp -R skills/compliance/cra-evidence /path/to/repo/.claude/skills/cra-evidence
```

Only the source half moves, and it appears in exactly two places
(`README.md`, `docs/distribution.md`), both rewritten. `scripts/install.sh`
replaces the copy-paste commands so the paths live in one place.

## 5. The four harness skills

Shared contract, inherited from the compliance track: **Claude drafts, humans
approve.** Every harness skill emits *evidence*, never an assertion. Reports are
`Proposed` until a human accepts them.

### 5.1 `harness-audit`

Entry point for the track. Triggers on repo onboarding and on "is our setup any
good?".

Workflow: detect stack → inventory the seven harness surfaces (`CLAUDE.md`,
`.claude/skills/`, `.claude/agents/`, hooks in `settings.json`, slash commands,
MCP servers, verify gate) → classify each as **present / gap / not applicable**
with a stated rationale, never a bare "good" → hand drafting of the missing
pieces to the other three skills → present **one** review batch, not one
interruption per surface.

Ships `scripts/inventory.sh`: a pure filesystem read emitting JSON. The facts
are deterministic; only the judgement is model-side.

Deliberately mirrors `cra-evidence` W3 (gap report), a shape the team already
reads fluently.

### 5.2 `claude-md-authoring`

Thesis, inherited from the compliance development brief: **CLAUDE.md is policy,
not routing.**

Teaches what belongs in CLAUDE.md (scope, mandates, exceptions, stack versions,
what "done" means in *this* repo) versus what must become a skill (any "how to
do X" procedure). Enforces layering: user `~/.claude/CLAUDE.md` for personal
habits, project CLAUDE.md for team policy, subdirectory CLAUDE.md for
module-local rules.

Includes a **diagnostic mode**: "the agent keeps ignoring X" is usually a
CLAUDE.md that is too long, not too short. `references/antipatterns.md` catalogues
the failure modes, chief among them the 400-line procedure dump nobody reads and
the agent silently drops.

### 5.3 `subagent-authoring`

Starts with the decision, not the file. A one-screen selector:

| Artifact | Use when |
|---|---|
| **Skill** | A procedure the main agent should follow |
| **Subagent** | Isolated context, own tool budget, returns a conclusion |
| **Slash command** | A prompt the human fires deliberately |
| **Hook** | Deterministic, must run every time — Claude cannot be trusted to remember |

Only after that does it author `.claude/agents/*.md`: frontmatter, description as
trigger surface, tool allowlist under least privilege (a research agent gets no
`Write`), model tier.

### 5.4 `harness-eval`

The differentiator. Two modes:

**Trigger validation.** Given a skill, generate N positive and N negative
prompts, then judge each with an **adversarial quorum**: three independent fresh
subagents, each seeing only the `description:` and the prompt, reporting *did skill
X fire*. Catches misses **and** over-triggering — and, because the judges can
disagree, catches the failure a single judge structurally cannot see: **ambiguity**.
A split vote is recorded as `FLAKY`, never rounded up to `PASS`. Generalizes the
hand-written `tests/trigger-validation.md` table into something runnable.

**Behavioral regression.** Pin a small set of task prompts plus expected
observable outcomes for the repo; run before and after a harness change; diff. Then
dispatch a **skeptic** to argue the change is *not* responsible for the difference
(run-to-run variance, a prompt that would have passed anyway). An improvement the
skeptic can explain away has not been demonstrated. This is how a CLAUDE.md edit is
proven to have helped rather than felt to have helped.

**Why adversarial, and why here.** Both modes ask a model to grade work a model
produced — the classic setup for confident, self-flattering evidence. A single judge
returns one sample of a probabilistic decision and calls it a result. A quorum can
disagree, and the disagreement is the signal: it is what a flaky trigger looks like
from outside. (Decision D-6.)

Ships `scripts/eval_run.sh` and `assets/eval_spec.yaml`, so the prompt set lives
in git rather than in a chat log.

## 6. Documentation rewrite

**README** becomes a catalogue: the shared contract in one paragraph, then a
table per track, then install, then repo map. The compliance-specific narrative
(CRA deadlines, program framing) moves out of the README and stays in
`docs/compliance/development-brief.md`, which is an archived program record and
is not otherwise edited.

**`docs/harness/brief.md`** (new): why the track exists — the AI-native pilot
requires the harness to be a maintained artifact, not folklore — what it
deliberately excludes (§3), and the Superpowers dependency, restated in each
SKILL.md.

**`docs/contributing-skills.md`** (new): house rules currently buried as
"architecture principles" inside the compliance brief — one skill = one
capability with a recognizable trigger; progressive disclosure with a <500-line
SKILL.md; `scripts/` for determinism; English; graceful degradation on a missing
tool; `Proposed` by default. Both tracks point here, so the next skill author
does not have to do archaeology.

**`docs/distribution.md`**: rewritten for the new source paths and both tracks;
documents `scripts/install.sh`.

## 7. Testing

`tests/harness/` contains:

- A trigger-validation table per new skill: 5 positive / 5 negative prompts, the
  existing format.
- One fixture repo with a **deliberately bad harness**: bloated CLAUDE.md, no
  verify gate, an over-triggering skill. A bad fixture exercises `harness-audit`
  and `harness-eval` far better than a good one.

Existing compliance fixtures move to `tests/compliance/` unchanged.

## 8. Sequencing

Two PRs, not one.

1. **Restructure.** Rename; move skills into tracks; rewrite README and
   `distribution.md`; add `scripts/install.sh` and `docs/contributing-skills.md`;
   move compliance docs and tests into their subdirectories. Zero new skill
   content. Independently valuable and reviewable in ten minutes.
2. **Harness track.** The four skills, the fixtures, the brief, the rollout note,
   on top of the new structure.

## 9. Decisions taken

| # | Decision | Rationale |
|---|---|---|
| D-1 | Build on Superpowers, do not duplicate it | Re-implementing planning/TDD/review would create drift we own forever |
| D-2 | Rename to `oltrematica-skills` and restructure into tracks | Name must stop lying; track dirs make a third track free |
| D-3 | Four skills, not one workflow-based mega-skill | Binding architecture principle: one skill = one capability |
| D-4 | No hooks / MCP / skill-authoring skills | Already covered by `update-config`, out of scope, and Superpowers `writing-skills` respectively |
| D-5 | `harness-eval` ships a git-tracked eval spec | An eval that lives in a chat log is not an eval |
| D-6 | Adversarial verification lives *inside* `harness-eval`, not in a new skill | A standalone `adversarial-review` skill would collide with `superpowers:requesting-code-review` and the built-in `/code-review` — the duplication D-1 forbids. The place adversarial verification is genuinely load-bearing is where a model grades a model: a trigger quorum that can disagree, and a skeptic that tries to refute a claimed improvement. Added 2026-07-14 on Andrea's prompt |

## 10. Open questions

None blocking. Deferred: whether `harness-audit` should eventually run as a CI
job (parallel to the compliance CI gate proposal) — revisit after the track has
run on one real repo.
