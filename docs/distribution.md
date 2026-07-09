# Distribution

How to get `adr-management` and `cra-evidence` into a repo, and how the
options relate to each other.

## Scope ladder

Three levels, increasing in reach:

1. **Personal** — `~/.claude/skills/<name>`. Available to you only, in every
   project. This is the pilot scope: how `adr-management` started.
2. **Project** — `.claude/skills/<name>` inside a repo, committed to git.
   Shared with the whole team on that repo. This is the current standard —
   use it unless you have a reason not to.
3. **Plugin (future)** — a marketplace-distributed plugin covering both
   skills, installed once and updated centrally. Not built yet; see
   [Future: plugin conversion](#future-plugin-conversion) below.

## Install per repo (standard)

```bash
git clone https://github.com/Oltrematica/oltrematica-compliance-skills.git /tmp/ocs
cp -R /tmp/ocs/skills/cra-evidence  /path/to/repo/.claude/skills/cra-evidence
cp -R /tmp/ocs/skills/adr-management /path/to/repo/.claude/skills/adr-management
```

Commit `.claude/skills/` so the team gets it on pull.

**Verify:** restart Claude Code in the target repo (or start a new session)
and run `/skills` — both skills should be listed.

**Why a plain copy works:** every script inside a skill uses paths relative
to the skill's own directory, not to this repo. A `cp -R` (or a `git clone`
followed by a copy, as above) is sufficient — no rewriting, no build step.
This was verified during the skills' preparation for in-repo distribution
(relative script paths survive the move).

## Submodule option

Claude Code discovers skills by looking for `.claude/skills/<name>/SKILL.md`.
A git submodule that points at the *whole* `oltrematica-compliance-skills`
repo cannot itself live at `.claude/skills/adr-management`, because that path
must resolve directly to a single skill's `SKILL.md` — not to a repo
containing `skills/adr-management/`.

Practical layout if you want submodule tracking instead of an untracked copy:

1. Add the submodule outside `.claude/`, e.g. `tools/oltrematica-skills`.
2. Copy (or symlink) each skill you need from
   `tools/oltrematica-skills/skills/<name>` into
   `.claude/skills/<name>`.

**Recommendation: skip the submodule and use a plain copy.** A submodule adds
a second thing to keep in sync (the pointer commit *and* the copy/symlink)
for a benefit — pinned upstream version — that most repos don't need. Use the
submodule only if your repo already has a policy of pinning all external
tooling this way.

## Updating

There is no version manifest or update command. To update:

1. Re-clone or `git pull` this repo (or its submodule, if you used one).
2. Re-run the `cp -R` install commands above — they overwrite the existing
   skill directory.
3. Review the diff before committing, same as any other vendored code.

For a changelog of what changed in a skill, use `git log` scoped to its
directory in this repo, e.g.:

```bash
git log --oneline -- skills/cra-evidence
```

There are no tagged releases of this repo yet; updating means tracking
`main`.

## Future: plugin conversion

Deliberate deviation from the original brief: this repo ships as a plain
skills repo (`skills/`, `docs/`, `tests/`), not a plugin marketplace — see
[`docs/superpowers/specs/2026-07-09-compliance-skills-repo-design.md`](superpowers/specs/2026-07-09-compliance-skills-repo-design.md)
for the rationale. Converting to a plugin later is a sketch, not a design:
add a `.claude-plugin/marketplace.json` at the repo root, a `plugin.json` per
skill, move each skill under its plugin's own directory (or keep `skills/`
and point `plugin.json` at it), and teams install with
`/plugin marketplace add Oltrematica/oltrematica-compliance-skills` instead
of cloning and copying. Nothing here is built; treat it as the shape of the
next step, not a commitment to a timeline.

## External tool prerequisites per skill

- **`adr-management`** — none beyond `bash`, `sed`, `find` (present on macOS
  and Linux by default).
- **`cra-evidence`**:
  - `syft` — required, generates the SBOM.
  - `grype` — primary vulnerability scanner. `osv-scanner` is an accepted
    fallback if `grype` is unavailable.
  - Node.js + `npx` + a local Chrome install — required only for the a11y
    module (W4), which runs `@axe-core/cli`. Repos without frontend routes
    don't need this.

macOS quick install for the required scanning tools:

```bash
brew install syft grype
```
