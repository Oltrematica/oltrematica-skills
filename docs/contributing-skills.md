# Contributing a skill

House conventions for every skill in this repo, both tracks. Short and binding.

## The contract

**Claude drafts, humans approve.** Every artifact a skill produces carries status
`Draft` or `Proposed`. A skill NEVER marks anything `Accepted`, `Compliant`,
`Conformant`, or `Passing` on its own initiative — only after explicit human
confirmation.

**Evidence, never assertion.** A report states *present / gap / not applicable*
per item, each with a rationale and a pointer to the evidence. A bare "looks
good" is a bug, not a summary.

## Structure

1. **One skill = one capability with a recognizable trigger.** If the SKILL.md
   body needs a branch that says "but when it's about X, do something entirely
   different", that is two skills. Split it.
2. **Progressive disclosure.** SKILL.md body stays **under 500 lines**. Anything
   longer moves to `references/`, loaded on demand. Deterministic operations move
   to `scripts/`.
3. **Layout:**

```
<skill-name>/
├── SKILL.md          # required — frontmatter + body
├── README.md         # optional — human-facing, for skills we share outward
├── scripts/          # deterministic operations (bash / python3 stdlib)
├── assets/           # templates the skill fills in
└── references/       # long material loaded on demand
```

4. **Scripts are self-relative.** Always resolve paths from the script's own
   directory, so the skill survives being copied into a target repo:

```bash
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
```

## The description IS the router

The `description:` frontmatter is the only thing Claude sees when deciding
whether to invoke a skill. The body is invisible at trigger time — a "do NOT use
this for X" carve-out in the body cannot prevent a false trigger.

Write descriptions with **concrete example phrasings** in the user's own words
("prepare the release", "why did we choose X?"), not abstract categories. Then
**test the description**: at least 5 trigger and 5 no-trigger prompts, recorded
in `tests/<track>/trigger-validation.md`. Include prompts that belong to a
*neighboring* skill — cross-triggering is the failure mode that actually bites.

## Portability

- `bash` (POSIX-leaning) or `python3` **stdlib only**.
- No new dependencies — no `pip install`, no `npm install` — without explicit
  permission.
- Assume macOS and Linux dev environments.
- **Degrade loudly.** A missing external tool produces an actionable message with
  an install hint on stderr and a non-zero exit. Never a stack trace, never a
  silent skip.

## Language

English. Skill content, scripts, comments, templates, generated output, commits.

## Superpowers

Assume the Superpowers plugin is installed. Do not re-implement planning, TDD,
debugging, code review, or skill authoring — reference the Superpowers skill
instead. Our skills add what it lacks.

## Evidence log

Every script gets tested standalone against a fixture before it is wired into a
SKILL.md, and the result — command, actual output, PASS/FAIL — is appended to
`tests/<track>/notes.md`. These notes are living documentation, not a formality:
they are how the next person knows what was actually verified versus assumed.
