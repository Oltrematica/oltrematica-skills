# Contributing

Thanks for considering a contribution to `oltrematica-skills`. This repo ships
Claude Code skills in two tracks — **compliance** (GDPR/CRA/PLD/AI Act/EAA
evidence generation) and **harness** (auditing and authoring the Claude Code
setup itself) — plus the hooks that back the verification gate. The house
rules below are short and they are binding: a pull request that doesn't
follow them will get bounced back before review, not silently merged.

The canonical, longer version of these conventions lives in
[`docs/contributing-skills.md`](docs/contributing-skills.md). Read it before
writing a skill. This file is the summary plus the parts that actually cause
PRs to fail.

## Before you start

- **One skill = one capability with a recognizable trigger.** If your
  SKILL.md body needs a branch that says "but when it's actually about X, do
  something entirely different," that's two skills. Split it.
- **No new runtime dependencies.** Every script is `bash` (portable — see
  below) or `python3` **stdlib only**. No `pip install`, no `npm install`, no
  vendored libraries, without a maintainer sign-off first. This is not a
  style preference: a skill that shells out to a tool the installer didn't
  bring is a skill that silently breaks on someone else's machine.
- **Scripts are self-relative.** Resolve paths from the script's own
  directory so the skill survives being copied into a target repo:

  ```bash
  SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  ```

- **Portable shell.** Scripts must run under both stock macOS bash (3.2 — no
  associative arrays, no `mapfile`) and Linux bash/`sh`. CI runs every test
  suite on `ubuntu-latest` and `macos-latest` for exactly this reason — a
  script that only works on your machine's bash 5 will fail there, and the
  PR will not be merged with a red CI run.
- **English.** Skill content, scripts, comments, templates, generated
  output, commit messages — all of it.

## The description IS the router — and it is the part you must test

This is the rule most likely to bite you, so it gets its own section.

At the moment Claude decides whether to invoke a skill, it sees the
`description:` frontmatter field and **nothing else**. Not the SKILL.md
body, not your `references/`, not a "do NOT use this for X" carve-out three
paragraphs down — none of that exists yet at trigger time. If your
description is vague, abstract, or written in your own vocabulary instead of
a real user's words, the skill will misfire: silent under-triggering (it
never fires when it should) or noisy over-triggering (it fires on everything
adjacent), and the body text you were relying on to disambiguate is invisible
to the part of Claude making that call.

So: **a skill's trigger behavior is a testable claim, and it must be
tested before the PR is opened**, not asserted in the description and
left on faith.

How to test it:

1. Read the [`harness-eval`](skills/harness/harness-eval/SKILL.md) skill.
   It defines the method: a spec of **at least 5 trigger and 5 no-trigger
   prompts** per skill, judged by a **quorum of three independent, blind,
   tool-less subagents** — one prompt per judge dispatch, one pinned model
   for the whole run. A single self-graded read of your own description is
   not evidence; a judge that can open your SKILL.md is grading against
   material the real router never sees. `harness-eval` explains exactly why
   each constraint is a MUST, not a nicety, and what happens to your results
   if you skip one.
2. Look at [`tests/harness/trigger-validation.md`](tests/harness/trigger-validation.md)
   for a worked example: real trigger/no-trigger prompts, real judge splits
   recorded honestly (`FLAKY` rows included, not rounded into `PASS`), and
   the description fixes that followed from them. This is what your own
   evidence log should look like, not a table where everything passes on
   the first try — if it does, be suspicious of your prompts, not proud of
   your description.
3. Include prompts belonging to a **neighboring skill's territory** as
   no-trigger cases. Cross-triggering between two skills that live near each
   other is the failure mode that actually shows up in a repo with several
   skills installed — an isolated trigger test that never checks a
   neighbor's phrasing will miss it.
4. Record the spec (`.claude/eval_spec.json` alongside the skill, or
   `tests/<track>/eval_spec.json`) and the results table in
   `tests/<track>/trigger-validation.md`. Evidence lives in git, not in a
   chat transcript that disappears with the session.

A PR that changes or adds a `description:` field without an updated
trigger-validation table attached is not reviewable — say so up front rather
than have it come back as a review comment.

## Structure

```
<skill-name>/
├── SKILL.md          # required — frontmatter + body, under 500 lines
├── README.md         # optional — human-facing, for skills shared outward
├── scripts/          # deterministic operations (bash / python3 stdlib)
├── assets/           # templates the skill fills in
└── references/       # long material loaded on demand
```

**Progressive disclosure**: SKILL.md's body stays under 500 lines. If it's
growing past that, the excess belongs in `references/` (loaded on demand,
not paid for on every invocation) or `scripts/` (deterministic work has no
business being prose the model re-derives every run).

## Evidence, never assertion

A skill's output states *present / gap / not applicable* per item, each with
a rationale and a pointer to the evidence that backs it. "Looks good" is a
bug in the output, not an acceptable summary. Nothing a skill produces is
self-certifying: an artifact is `Draft` or `Proposed` until a human says
otherwise, never `Accepted`/`Compliant`/`Conformant` on the skill's own say-so.

## Every script gets a contract test

If your PR adds or changes a script under `scripts/` or `hooks/scripts/`,
it needs a matching `*.test` file that exercises it standalone against a
fixture — inputs, expected output, exit codes — independent of any Claude
session. Contract tests are what CI actually runs; a script with no test is
a script CI cannot protect and a future refactor will silently break.

Existing suites are the pattern to follow:

- `tests/harness/verify_gate.sh.test`
- `tests/harness/state.sh.test`
- `tests/harness/record_activity.sh.test`
- `tests/harness/source_mutation.py.test`
- `tests/harness/claims.py.test`
- `tests/harness/verify_before_done.sh.test`
- `tests/harness/inventory.sh.test`
- `tests/harness/eval_run.py.test`
- `tests/install.sh.test`

## Running the test suites

All suites are self-contained shell/Python scripts — no test framework, no
install step. Run each with an explicit `bash` (don't rely on `sh` or an
aliased shell):

```bash
/bin/bash tests/harness/verify_gate.sh.test
/bin/bash tests/harness/state.sh.test
/bin/bash tests/harness/record_activity.sh.test
/bin/bash tests/harness/source_mutation.py.test
/bin/bash tests/harness/claims.py.test
/bin/bash tests/harness/verify_before_done.sh.test
/bin/bash tests/harness/inventory.sh.test
/bin/bash tests/harness/eval_run.py.test
/bin/bash tests/install.sh.test
```

**All of them must be green before you open a PR.** CI
(`.github/workflows/ci.yml`) runs the same list on `ubuntu-latest` and
`macos-latest` and fails the job — not just a step — if any suite fails on
either OS. If a suite fails locally on macOS but you believe it's
Linux-only-broken (or vice versa), say so explicitly in the PR description;
don't just skip it.

## Pull requests

Use the PR template checklist. In short: tests green (all suites, both
OSes, per CI), the trigger description tested and the evidence table
updated if a skill's `description:` changed, no new dependencies, docs
updated if you touched a public surface (`README.md`, `docs/`).

Commit messages follow `type(scope): subject`, imperative present tense,
≤72 characters for the subject line. Types: `feat`, `fix`, `refactor`,
`test`, `docs`, `chore`, `ci`. One commit, one logical change.

## Questions

Open an issue, or start with the
[`skill_proposal`](.github/ISSUE_TEMPLATE/skill_proposal.md) template if
you're proposing a new skill rather than reporting a bug.
