# CLAUDE.md antipatterns

The failure modes, in rough order of how often they actually bite.

## 1. The procedure dump

**Symptom:** sections titled "How to add a controller", "How to write a test" —
numbered steps, hundreds of lines.

**Why it fails:** CLAUDE.md is loaded into *every* context, for every task. A
procedure is relevant to maybe one task in twenty. You are paying full context
cost on every turn for material that is usually noise, and noise is what the model
drops first.

**Fix:** the procedure becomes a skill. CLAUDE.md keeps one line: *"Adding a
controller: use the `controller-scaffold` skill."* That is routing-by-mandate,
which is policy. Explaining the steps inline is routing-by-repetition, which is
not.

## 2. The unverifiable exhortation

**Symptom:** "Be careful with migrations." "Write good tests." "Think about
security."

**Why it fails:** nothing to check. The agent cannot tell whether it complied, and
neither can you.

**Fix:** make it imperative and verifiable. Not *"be careful with migrations"* but
*"every migration must have a working `down()`; before committing one, run
`php artisan migrate:rollback` against a scratch database."*

## 3. The rotting stack list

**Symptom:** a pinned version table that stopped being true two quarters ago.

**Why it fails:** the agent trusts it. A stale CLAUDE.md is worse than none —
it actively misinforms, confidently.

**Fix:** date the section, list only versions an agent would otherwise get wrong,
and delete anything the lockfile already states. The lockfile cannot go stale;
your prose can.

## 4. Length as a proxy for care

**Symptom:** a 400-line CLAUDE.md, added to whenever something goes wrong, never
removed from.

**Why it fails:** instruction-following degrades as instructions accumulate. Rule
80 competes with rule 3 for attention, and the agent silently drops one. This is
the mechanism behind almost every "the agent keeps ignoring X" complaint.

**Fix:** treat it as a budget. Adding a rule means asking which existing rule it
replaces, or whether it should have been a skill or a hook instead. If a rule must
hold *every single time*, it is not a rule — it is a **hook**, and it belongs in
`settings.json` where compliance is deterministic rather than probabilistic.

## 5. Routing that duplicates a description

**Symptom:** "When the user mentions SBOMs, use the cra-evidence skill."

**Why it fails:** the skill's own `description:` frontmatter already does this, and
does it better. Now you maintain the trigger in two places and they drift.

**Fix:** delete the line. State only what CLAUDE.md alone can state: that in *this*
repo, the skill is **mandatory** ("every tagged release must produce a
cra-evidence dossier"). Mandate is policy. Triggering is the description's job.

## 6. Wrong-scope rules

**Symptom:** a personal preference ("always explain your reasoning to me") in a
team-shared project CLAUDE.md; or a module-specific rule at repo root.

**Fix:** three scopes, three homes. `~/.claude/CLAUDE.md` for personal habits.
Project CLAUDE.md for team policy. Subdirectory CLAUDE.md for rules that only bind
inside that module — it loads only when the agent works in there, which is exactly
the point.
