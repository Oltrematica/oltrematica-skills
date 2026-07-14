# Distribution

How to get Oltrematica skills into a repo, and how the options relate.

## Scope ladder

Three levels, increasing in reach:

1. **Personal** — `~/.claude/skills/<name>`. Available to you only, in every
   project. This is pilot scope: how `adr-management` started.
2. **Project** — `.claude/skills/<name>` inside a repo, committed to git. Shared
   with the whole team on that repo. **This is the standard — use it unless you
   have a reason not to.**
3. **Plugin (future)** — a marketplace-distributed plugin covering every skill,
   installed once and updated centrally. Not built; see
   [Future: plugin conversion](#future-plugin-conversion).

## Install (standard)

```bash
git clone https://github.com/Oltrematica/oltrematica-skills.git /tmp/os
/tmp/os/scripts/install.sh <skill-name>... --to /path/to/your-repo
```

Run it with no arguments to list the available skills.

For personal scope, target your home Claude directory's parent — the installer
writes to `<target>/.claude/skills/`:

```bash
/tmp/os/scripts/install.sh adr-management --to ~
```

Commit `.claude/skills/` so the team gets the skill on pull.

**Verify:** restart Claude Code in the target repo (or start a new session) and
run `/skills` — the skill should be listed.

## Source layout vs. install layout

Skills live under `skills/<track>/<name>/` in this repo, but always install to
the **flat** path `.claude/skills/<name>/`. Claude Code discovers skills by
looking for `.claude/skills/<name>/SKILL.md`; it knows nothing about tracks.
The track directories organize *this* repo and never appear in a target repo.

**Why a plain copy works:** a skill's scripts resolve paths in one of two ways,
never a third. `new_adr.sh` computes its own directory
(`SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`) to find
`assets/template.md` next to it. `gen_sbom.sh`, `diff_sbom.py`, `scan_vulns.sh`,
and `a11y_scan.sh` have no path dependency at all — they take every input as a
CLI argument and never look for a sibling file. Either way, nothing points back
at this repo, which is why a plain copy is sufficient — no rewriting, no build
step. Verified by execution, not assumed.

## Submodule option

Claude Code needs `.claude/skills/<name>/SKILL.md` to resolve directly to a
single skill. A submodule pointing at the *whole* `oltrematica-skills` repo
cannot itself live at `.claude/skills/adr-management`, because that path would
resolve to a repo containing `skills/compliance/adr-management/`, not to a
`SKILL.md`.

Layout if you want submodule tracking anyway:

1. Add the submodule outside `.claude/`, e.g. `tools/oltrematica-skills`.
2. Run `tools/oltrematica-skills/scripts/install.sh <name> --to .` to copy each
   skill you need into `.claude/skills/<name>/`.

**Recommendation: skip the submodule.** It adds a second thing to keep in sync
(the pointer commit *and* the copy) for a benefit — a pinned upstream version —
that most repos don't need. Use it only if your repo already pins all external
tooling this way.

## Updating

There is no version manifest and no update command. To update:

1. `git pull` this repo.
2. Re-run `scripts/install.sh` — it replaces the existing skill directory.
3. Review the diff before committing, same as any other vendored code.

Changelog for one skill:

```bash
git log --oneline -- skills/compliance/cra-evidence
```

There are no tagged releases yet; updating means tracking `main`.

## External tool prerequisites

| Skill | Needs |
|-------|-------|
| `adr-management` | `bash`, `sed`, `find` — present by default on macOS and Linux |
| `cra-evidence` | `syft` (SBOM, required); `grype` (primary scanner) or `osv-scanner` (fallback); Node + `npx` + Chrome for the a11y module only |
| Harness-track skills | `bash`, `python3` (stdlib only). The Superpowers plugin must be installed. |

macOS quick install for the compliance scanners:

```bash
brew install syft grype
```

## Future: plugin conversion

Deliberate deviation from the original brief: this ships as a plain skills repo,
not a plugin marketplace (decided 2026-07-09) — rationale in
[the compliance repo design spec](superpowers/specs/2026-07-09-compliance-skills-repo-design.md).

Converting later is a sketch, not a design: add `.claude-plugin/marketplace.json`
at the repo root and a `plugin.json` per plugin, then teams install with
`/plugin marketplace add Oltrematica/oltrematica-skills` instead of cloning.
Nothing here is built; treat it as the shape of the next step, not a commitment.
