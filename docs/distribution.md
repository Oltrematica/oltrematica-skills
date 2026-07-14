# Distribution

How to get Oltrematica skills into a repo, and how the options relate.

## Scope ladder

Three levels, increasing in reach:

1. **Personal** — `~/.claude/skills/<name>`. Available to you only, in every
   project. This is pilot scope: how `adr-management` started.
2. **Project** — `.claude/skills/<name>` inside a repo, committed to git. Shared
   with the whole team on that repo.
3. **Plugin** — this repo installed as a marketplace plugin, once, updated
   centrally. **This is the standard — use it unless you have a reason not
   to.** It is the only path that also ships the Stop-hook verification gate;
   see [Install (primary): plugin marketplace](#install-primary-plugin-marketplace).

## Install (primary): plugin marketplace

The repo is a Claude Code plugin (`.claude-plugin/marketplace.json`,
`.claude-plugin/plugin.json`, `hooks/hooks.json`). One install gives every repo
the seven skills **and** the verification-gate hooks, and updates are pulled
centrally instead of re-copied per repo.

**Why this is primary, not `scripts/install.sh`:** hooks live in
`settings.json`, and the only alternative to a plugin is editing that file by
hand in every one of the ~190 repos this could reach, then re-merging it by
hand on every update. Plugin hooks merge automatically across scopes —
nothing in a repo's own `settings.json` has to change. That's a functional
difference, not a packaging preference: `scripts/install.sh` cannot deliver
hooks at all (see [Fallback](#fallback-scriptsinstallsh-skills-only) below).

Add the marketplace once, then install the plugin:

```bash
claude plugin marketplace add https://github.com/Oltrematica/oltrematica-skills.git
claude plugin install oltrematica-skills@oltrematica
```

Both commands were run against `claude` 2.1.207 — the CLI's `plugin`
subcommands are what actually exists, not a guess. `marketplace add` against a
URL was verified as far as it can be before this branch is merged: it clones
the ref and looks for `.claude-plugin/marketplace.json`, and correctly fails
with "Marketplace file not found" against `main` today because that file
doesn't exist there yet — it exists on this branch. The full end-to-end path
(marketplace add → plugin install → hooks load → Stop hook blocks a stale
completion claim in a real session) was verified against the **local
directory form** instead, which is equivalent for everything except the fetch
step:

```bash
claude plugin marketplace add /path/to/oltrematica-compliance-skills --scope local
claude plugin install oltrematica-skills@oltrematica --scope local
```

Full transcript, including the `--debug hooks` log lines and the actual block
message, is in `tests/harness/notes.md`. Re-verify the URL form once this
branch reaches `main`.

Default scope is `user` (available in every project on your machine). Pass
`--scope project` to declare it in the repo's own `.claude/settings.json` so
the whole team gets it on pull, or `--scope local` to keep it out of git
(`.claude/settings.local.json`, personal-only, same repo).

**Verify:** in an interactive session, `/hooks` lists `record_activity.sh`
(PostToolUse, two matchers) and `verify_before_done.sh` (Stop) with source
`Plugin`. Headless, there is no `/hooks` equivalent (`/hooks` itself replies
"isn't available in this environment" under `-p`); use
`claude --debug hooks -p "..." --debug-file <path>` and grep the log for
`Read hooks.json for plugin oltrematica-skills` and
`Loading hooks from plugin: oltrematica-skills` — both are logged at session
start. Full transcript in `tests/harness/notes.md`.

## Fallback: `scripts/install.sh` (skills only)

For a repo that cannot add a marketplace (offline CI runner, no outbound git
access, policy blocks it), `scripts/install.sh` still works — but it installs
**skills only, not hooks**. The verification gate needs `${CLAUDE_PLUGIN_ROOT}`,
which only the plugin loader sets; a plain file copy has no such variable and
the hook scripts have nothing to attach to. If you need the Stop-hook gate,
the plugin is not optional — there is no `settings.json`-only equivalent
shipped by this repo.

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

Plugin install: `claude plugin marketplace update oltrematica` refreshes the
marketplace, then `claude plugin update oltrematica-skills@oltrematica`
updates the plugin (restart the session to apply).

Fallback install: there is no version manifest and no update command. To
update:

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
| `cra-evidence` | `python3` (stdlib only — `diff_sbom.py` is a Python script and `gen_sbom.sh` calls `python3`); `syft` (SBOM, required); `grype` (primary scanner) or `osv-scanner` (fallback); Node + `npx` + Chrome for the a11y module only |
| Harness-track skills | `bash`, `python3` (stdlib only). The Superpowers plugin must be installed. |

macOS quick install for the compliance scanners:

```bash
brew install syft grype
```

## History: plugin conversion

The repo shipped as a plain skills repo at first — no plugin marketplace
(decided 2026-07-09, rationale in
[the compliance repo design spec](superpowers/specs/2026-07-09-compliance-skills-repo-design.md))
— because at that point there was nothing a plugin needed to deliver beyond a
file copy. That changed once the Stop-hook verification gate
(`hooks/scripts/verify_before_done.sh`) needed a mechanism `settings.json`
alone can't provide across ~190 repos: automatic hook merging. The plugin
(`.claude-plugin/marketplace.json`, `.claude-plugin/plugin.json`,
`hooks/hooks.json`) was built for that reason and is now the primary install
path — see [Install (primary): plugin marketplace](#install-primary-plugin-marketplace).

One deviation from a first draft worth recording: `plugin.json` was originally
planned at the repo root. `claude plugin validate` rejects that layout —
"Expected .claude-plugin/marketplace.json or .claude-plugin/plugin.json" — so
it lives at `.claude-plugin/plugin.json` instead. Verified by running the
validator against both layouts, not assumed from a template.

A known gap, also verified rather than assumed: the plugin's component
inventory (`claude plugin details`) reports `Skills (0)`. The seven skills are
present in the installed plugin bundle (`skills/compliance/...`,
`skills/harness/...`), but Claude Code's default skill auto-discovery for
plugins does not descend into the two-level `skills/<track>/<name>/` layout
this repo uses for its own organization — see
[Source layout vs. install layout](#source-layout-vs-install-layout). This
does not affect the hooks, which are declared explicitly in `hooks/hooks.json`
and load correctly regardless of skill discovery (confirmed in
`tests/harness/notes.md`). Skills remain reachable in a plugin install via the
`Skill` tool and are unaffected for `scripts/install.sh` installs, which copy
by name and do not rely on this auto-discovery at all.
