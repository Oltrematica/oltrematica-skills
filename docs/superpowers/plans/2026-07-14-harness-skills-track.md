# Harness Engineering Skills Track — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn this repo from a compliance-skills repo into a two-track skills catalogue, and add four harness-engineering skills that let developers build, operate and evaluate a repo's Claude Code harness.

**Architecture:** Phase 1 restructures the repo (`skills/compliance/`, `skills/harness/`, track-scoped `docs/` and `tests/`) and rewrites the docs, with zero new skill content. Phase 2 adds the four skills on top: `harness-audit` (inventory + gap report), `claude-md-authoring` (policy-not-routing), `subagent-authoring` (artifact selector + `.claude/agents/`), `harness-eval` (trigger validation + behavioral regression). Every skill assumes the Superpowers plugin is installed and does not re-implement it.

**Tech Stack:** Markdown skills (Claude Code SKILL.md format), `bash` (POSIX-leaning), `python3` **stdlib only**. No package manager, no build step, no runtime dependencies.

**Source spec:** [`docs/superpowers/specs/2026-07-14-harness-skills-track-design.md`](../specs/2026-07-14-harness-skills-track-design.md)

## Global Constraints

Every task's requirements implicitly include this section.

- **Language:** English — all skill content, scripts, comments, commits, docs.
- **One skill = one capability with a recognizable trigger.** No monolithic skill.
- **Progressive disclosure:** SKILL.md body **< 500 lines**. Longer material goes to `references/`; deterministic operations go to `scripts/`.
- **Claude drafts, humans approve.** No artifact is ever labeled `Accepted`/`Compliant`/`Passing` autonomously. Reports default to `Proposed`.
- **Evidence, never assertion.** Every report states *present / gap / not applicable* with a rationale — never a bare "looks good".
- **Portability:** `bash` or `python3` **stdlib only**. No `pip install`, no `npm install`, no new dependencies of any kind without explicit permission.
- **Degrade loudly:** a missing external tool produces an actionable message + install hint on stderr and a non-zero exit — never a stack trace, never a silent skip.
- **Superpowers is a dependency, not a thing to copy.** Harness skills reference `superpowers:writing-skills`, `superpowers:brainstorming`, etc. They never re-implement planning, TDD, debugging, review, or skill-authoring.
- **Commit convention:** `type(scope): short description`, imperative, ≤72 chars subject. One commit = one logical change.
- **Evidence log:** every task that runs a script appends a dated section to the relevant `tests/*/notes.md`, in the existing format (command, actual output, PASS/FAIL). This is the repo's living documentation convention.

**Deliberate deviation from the spec:** the design doc says `assets/eval_spec.yaml`. This plan uses **`assets/eval_spec.example.json`** instead. Python's stdlib has `json` but not `yaml`; YAML would require PyYAML, which the portability constraint forbids. Same content, no dependency.

---

# PHASE 1 — Restructure (PR 1)

No new skill content. Independently valuable and reviewable.

---

### Task 1: Move skills into tracks and repair internal paths

Moving `skills/adr-management/` down one level breaks two things that a naive `git mv` leaves silently broken: the relative links in `skills/adr-management/README.md` (which walk up to `docs/` and `LICENSE`), and the `.gitignore` fixture pattern once tests move in Task 2. This task catches the first; Task 2 catches the second.

**Files:**
- Move: `skills/adr-management/` → `skills/compliance/adr-management/`
- Move: `skills/cra-evidence/` → `skills/compliance/cra-evidence/`
- Modify: `skills/compliance/adr-management/README.md` (relative links, install commands)

**Interfaces:**
- Produces: the source paths `skills/compliance/<name>/` and `skills/harness/<name>/` that Task 3's `install.sh` resolves against, and that Task 4's docs reference.
- Note for later tasks: **destination** paths in a target repo are unchanged — always `.claude/skills/<name>/`, never nested by track. Track dirs exist only in *this* repo.

- [ ] **Step 1: Move the two skills with git mv (preserves history)**

```bash
mkdir -p skills/compliance
git mv skills/adr-management skills/compliance/adr-management
git mv skills/cra-evidence   skills/compliance/cra-evidence
git status --short
```

Expected: six-ish `R` (renamed) entries, no `D`/`A` pairs.

- [ ] **Step 2: Find every path that the move broke**

```bash
grep -rn "\.\./\.\./docs\|\.\./\.\./LICENSE\|skills/adr-management\|skills/cra-evidence" \
  --include="*.md" --include="*.sh" --include="*.py" . \
  | grep -v "^./.superpowers/" | grep -v "^./docs/superpowers/"
```

Expected: hits in `skills/compliance/adr-management/README.md` (the `../../docs/distribution.md` and `../../LICENSE` links, now one level too shallow), plus references in `README.md`, `docs/distribution.md`, `docs/rollout-note.md`, `tests/notes.md`. Only the README.md inside the skill is fixed here — the repo-root docs are rewritten wholesale in Task 4, and `tests/notes.md` is a historical evidence log that is **not** rewritten (it records what was true on 2026-07-09).

- [ ] **Step 3: Fix the relative links inside adr-management/README.md**

Three edits in `skills/compliance/adr-management/README.md`:

1. The install commands (two of them) gain the track segment:

```bash
cp -R skills/compliance/adr-management /path/to/your-project/.claude/skills/adr-management
```

```bash
cp -R skills/compliance/adr-management ~/.claude/skills/adr-management
```

2. The distribution link gains one `../`:

```markdown
See [`docs/distribution.md`](../../../docs/distribution.md) for submodule and
plugin options.
```

3. The LICENSE link gains one `../`:

```markdown
Proprietary — Copyright © 2026 Oltrematica. All rights reserved. See the
repository [LICENSE](../../../LICENSE).
```

- [ ] **Step 4: Verify no relative link is left dangling**

```bash
python3 - <<'PY'
import os, re, sys
bad = []
for root, dirs, files in os.walk('skills'):
    for f in files:
        if not f.endswith('.md'):
            continue
        p = os.path.join(root, f)
        for link in re.findall(r']\((\.\.?/[^)#]+)', open(p).read()):
            target = os.path.normpath(os.path.join(root, link))
            if not os.path.exists(target):
                bad.append(f"{p} -> {link} (resolves to {target})")
print("\n".join(bad) if bad else "OK: all relative links in skills/ resolve")
sys.exit(1 if bad else 0)
PY
```

Expected: `OK: all relative links in skills/ resolve`, exit 0.

- [ ] **Step 5: Verify the moved scripts still run (self-relative paths must survive)**

`new_adr.sh` and `gen_sbom.sh` both resolve their own directory via `SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`, so the move should be transparent. Prove it rather than assume it:

```bash
SCRATCH=$(mktemp -d)
mkdir -p "$SCRATCH/docs/adr"
(cd "$SCRATCH" && bash "$OLDPWD/skills/compliance/adr-management/scripts/new_adr.sh" "Test the move")
ls "$SCRATCH/docs/adr/"
rm -rf "$SCRATCH"
```

Expected: `0001-test-the-move.md` exists (created from the skill's `assets/template.md`, which the script found via its own relative path).

- [ ] **Step 6: Commit**

```bash
git add -A skills/
git commit -m "refactor(skills): move skills under a compliance/ track

Track directories exist only in this repo; install destinations in target
repos remain .claude/skills/<name>/ and are unchanged."
```

---

### Task 2: Move docs and tests into tracks, fix .gitignore

**Files:**
- Move: `docs/development-brief.md`, `docs/ci-gate-proposal.md`, `docs/rollout-note.md` → `docs/compliance/`
- Move: `tests/fixtures/`, `tests/notes.md`, `tests/trigger-validation.md` → `tests/compliance/`
- Modify: `.gitignore:2`
- Keep in place: `docs/distribution.md` (cross-track, rewritten in Task 4), `docs/superpowers/` (spec + plan)

**Interfaces:**
- Consumes: nothing.
- Produces: `tests/compliance/` and `docs/compliance/` — Phase 2 mirrors these as `tests/harness/` and `docs/harness/`.

- [ ] **Step 1: Prove the gitignore breakage exists before fixing it (RED)**

`.gitignore` line 2 is `tests/fixtures/*/compliance/` — it ignores generated SBOM output inside fixtures. After the move, that path is `tests/compliance/fixtures/*/compliance/` and the pattern no longer matches, so generated evidence would get committed.

```bash
mkdir -p tests/fixtures/node-minimal/compliance/sbom
touch tests/fixtures/node-minimal/compliance/sbom/probe.json
git check-ignore -q tests/fixtures/node-minimal/compliance/sbom/probe.json && echo "IGNORED (correct today)" || echo "NOT IGNORED"
rm -f tests/fixtures/node-minimal/compliance/sbom/probe.json
```

Expected: `IGNORED (correct today)` — this is the behavior that must survive the move.

- [ ] **Step 2: Move docs and tests**

```bash
mkdir -p docs/compliance tests/compliance
git mv docs/development-brief.md  docs/compliance/development-brief.md
git mv docs/ci-gate-proposal.md   docs/compliance/ci-gate-proposal.md
git mv docs/rollout-note.md       docs/compliance/rollout-note.md
git mv tests/fixtures             tests/compliance/fixtures
git mv tests/notes.md             tests/compliance/notes.md
git mv tests/trigger-validation.md tests/compliance/trigger-validation.md
git status --short
```

- [ ] **Step 3: Update .gitignore**

Replace line 2 of `.gitignore`:

```gitignore
.DS_Store
tests/compliance/fixtures/*/compliance/
node_modules/
```

- [ ] **Step 4: Verify the ignore rule works at the new path (GREEN)**

```bash
mkdir -p tests/compliance/fixtures/node-minimal/compliance/sbom
touch tests/compliance/fixtures/node-minimal/compliance/sbom/probe.json
git check-ignore -q tests/compliance/fixtures/node-minimal/compliance/sbom/probe.json \
  && echo "PASS: generated evidence still ignored" \
  || echo "FAIL: generated evidence would be committed"
rm -f tests/compliance/fixtures/node-minimal/compliance/sbom/probe.json
```

Expected: `PASS: generated evidence still ignored`.

- [ ] **Step 5: Fix cross-links between the moved compliance docs**

`docs/compliance/rollout-note.md` links to `distribution.md` as a sibling; it is now one level down. Update that link (and any other sibling link the grep finds):

```bash
grep -n "](distribution.md)\|](development-brief.md)\|](ci-gate-proposal.md)" docs/compliance/*.md
```

For each hit, rewrite `](distribution.md)` → `](../distribution.md)`. Links between two docs that both moved (e.g. rollout-note → development-brief) stay as-is — they are still siblings.

Then re-run the link checker from Task 1 Step 4 with `'skills'` changed to `'docs'`, excluding `docs/superpowers/`:

```bash
python3 - <<'PY'
import os, re, sys
bad = []
for root, dirs, files in os.walk('docs'):
    if 'superpowers' in root.split(os.sep):
        continue
    for f in files:
        if not f.endswith('.md'):
            continue
        p = os.path.join(root, f)
        for link in re.findall(r']\((\.\.?/[^)#]+)', open(p).read()):
            target = os.path.normpath(os.path.join(root, link))
            if not os.path.exists(target):
                bad.append(f"{p} -> {link}")
print("\n".join(bad) if bad else "OK: all relative links in docs/ resolve")
sys.exit(1 if bad else 0)
PY
```

Expected: `OK: all relative links in docs/ resolve`, exit 0.

**Note:** `docs/distribution.md` still contains stale `skills/cra-evidence` source paths at this point. That is expected — it is rewritten wholesale in Task 4. The checker above only validates *relative markdown links*, not shell commands inside code fences.

- [ ] **Step 6: Commit**

```bash
git add -A .gitignore docs/ tests/
git commit -m "refactor(repo): move compliance docs and tests into a track dir

Fixes the .gitignore fixture pattern, which no longer matched after the move
and would have started committing generated SBOM output."
```

---

### Task 3: `scripts/install.sh`

Replaces the copy-paste `cp -R` commands scattered across four docs with one command that resolves a skill by name across tracks. TDD: the script does not exist, so the test fails first.

**Files:**
- Create: `scripts/install.sh`
- Create: `tests/install.bats.sh` — a plain bash test script (no bats dependency; the name is illustrative, the file is `#!/usr/bin/env bash`)

**Interfaces:**
- Produces: `scripts/install.sh <skill-name>... --to <target-repo>` — resolves each `<skill-name>` to `skills/*/<skill-name>/`, copies it to `<target-repo>/.claude/skills/<skill-name>/`. Exit 0 on success, 1 on unknown skill name, 2 on usage error. Task 4's docs call exactly this.

- [ ] **Step 1: Write the failing test**

Create `tests/install.sh.test`:

```bash
#!/usr/bin/env bash
# Test contract for scripts/install.sh. Run from repo root: bash tests/install.sh.test
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$REPO_ROOT/scripts/install.sh"
PASS=0; FAIL=0
check() { # check <description> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1))
  else echo "  FAIL: $1 (expected '$2', got '$3')"; FAIL=$((FAIL+1)); fi
}

TARGET=$(mktemp -d)
trap 'rm -rf "$TARGET"' EXIT

echo "1. installs a compliance skill to .claude/skills/<name>/"
bash "$INSTALL" adr-management --to "$TARGET" >/dev/null 2>&1
check "exit code" "0" "$?"
check "SKILL.md landed at the flat destination path" "yes" \
  "$([ -f "$TARGET/.claude/skills/adr-management/SKILL.md" ] && echo yes || echo no)"
check "script came along" "yes" \
  "$([ -f "$TARGET/.claude/skills/adr-management/scripts/new_adr.sh" ] && echo yes || echo no)"
check "track dir is NOT recreated in the target" "no" \
  "$([ -d "$TARGET/.claude/skills/compliance" ] && echo yes || echo no)"

echo "2. installs multiple skills in one call"
bash "$INSTALL" adr-management cra-evidence --to "$TARGET" >/dev/null 2>&1
check "exit code" "0" "$?"
check "second skill landed" "yes" \
  "$([ -f "$TARGET/.claude/skills/cra-evidence/SKILL.md" ] && echo yes || echo no)"

echo "3. unknown skill name fails loudly"
ERR=$(bash "$INSTALL" no-such-skill --to "$TARGET" 2>&1); RC=$?
check "exit code" "1" "$RC"
check "names the unknown skill" "yes" "$(echo "$ERR" | grep -q "no-such-skill" && echo yes || echo no)"
check "lists what IS available" "yes" "$(echo "$ERR" | grep -q "adr-management" && echo yes || echo no)"

echo "4. missing --to is a usage error"
bash "$INSTALL" adr-management >/dev/null 2>&1
check "exit code" "2" "$?"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run it to confirm it fails (RED)**

```bash
bash tests/install.sh.test
```

Expected: every check FAILs; the first line of output includes `No such file or directory` for `scripts/install.sh`. Confirm `PASS=0` and a non-zero exit.

- [ ] **Step 3: Write the minimal implementation**

Create `scripts/install.sh`:

```bash
#!/usr/bin/env bash
# install.sh — copy one or more skills from this repo into a target repo's
# .claude/skills/ directory.
#
# Usage: scripts/install.sh <skill-name>... --to <target-repo>
#
# Skills live under skills/<track>/<name>/ here, but always install to the flat
# path .claude/skills/<name>/ — Claude Code requires .claude/skills/<name>/SKILL.md
# and knows nothing about tracks.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

usage() {
  cat >&2 <<EOF
Usage: scripts/install.sh <skill-name>... --to <target-repo>

Available skills:
$(available | sed 's/^/  - /')
EOF
  exit 2
}

available() {
  find "$REPO_ROOT/skills" -mindepth 2 -maxdepth 2 -type d -exec basename {} \; | sort
}

SKILLS=()
TARGET=""
while [ $# -gt 0 ]; do
  case "$1" in
    --to) [ $# -ge 2 ] || usage; TARGET="$2"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "ERROR: unknown option: $1" >&2; usage ;;
    *) SKILLS+=("$1"); shift ;;
  esac
done

[ ${#SKILLS[@]} -gt 0 ] || usage
[ -n "$TARGET" ] || usage
[ -d "$TARGET" ] || { echo "ERROR: target repo not found: $TARGET" >&2; exit 2; }

for name in "${SKILLS[@]}"; do
  src=$(find "$REPO_ROOT/skills" -mindepth 2 -maxdepth 2 -type d -name "$name" | head -1)
  if [ -z "$src" ]; then
    echo "ERROR: no skill named '$name' in this repo." >&2
    echo "Available skills:" >&2
    available | sed 's/^/  - /' >&2
    exit 1
  fi
  dest="$TARGET/.claude/skills/$name"
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  cp -R "$src" "$dest"
  echo "installed $name -> $dest"
done

echo
echo "Done. Restart Claude Code in $TARGET and run /skills to verify."
```

Make it executable:

```bash
chmod +x scripts/install.sh
```

- [ ] **Step 4: Run the test to verify it passes (GREEN)**

```bash
bash tests/install.sh.test
```

Expected: `PASS=8 FAIL=0`, exit 0.

- [ ] **Step 5: Record the evidence**

Append to `tests/compliance/notes.md`... **no** — `install.sh` is cross-track. Create `tests/notes.md` (repo-level, cross-track) with a first section:

```markdown
# Test notes (cross-track)

Evidence for repo-level tooling that belongs to no single track. Track-specific
evidence lives in `tests/compliance/notes.md` and `tests/harness/notes.md`.

## 2026-07-14 — scripts/install.sh

| Step | Test | Result |
|------|------|--------|
| 2 | Script missing (RED) | FAIL: `No such file or directory`, PASS=0 ✓ |
| 4 | Full contract (GREEN) | PASS=8 FAIL=0 ✓ |

Contract verified: resolves a skill by name across tracks; installs to the flat
`.claude/skills/<name>/` path (track dir is *not* recreated in the target);
handles multiple skills per call; exits 1 with the available-skill list on an
unknown name; exits 2 on a missing `--to`.
```

- [ ] **Step 6: Commit**

```bash
git add scripts/install.sh tests/install.sh.test tests/notes.md
git commit -m "feat(install): add scripts/install.sh for track-aware skill install

Resolves a skill by name across tracks and installs it to the flat
.claude/skills/<name>/ path a target repo requires."
```

---

### Task 4: Rewrite README, distribution.md, and add contributing-skills.md

This is the "repo is no longer compliance-only" task. Three docs, one commit — they are one editorial change and a reviewer would reject or accept them together.

**Files:**
- Rewrite: `README.md`
- Rewrite: `docs/distribution.md`
- Create: `docs/contributing-skills.md`

**Interfaces:**
- Consumes: `scripts/install.sh` (Task 3), the track layout (Tasks 1–2).
- Produces: `docs/contributing-skills.md` — the house conventions every Phase 2 skill must satisfy, and the doc that Task 12's `docs/harness/brief.md` links to instead of restating.

- [ ] **Step 1: Rewrite README.md**

The harness track does not exist yet, so its table lists the four skills as **planned** with a link to the spec. Task 12 flips them to shipped. Do not pretend they exist.

```markdown
# Oltrematica Skills

Claude Code skills for the Oltrematica portfolio, in two tracks:

- **Compliance** — produce and maintain regulatory evidence (CRA, SBOM, EAA) and
  decision records.
- **Harness** — build, operate and evaluate the agent harness itself: the
  `CLAUDE.md`, skills, subagents, hooks and verification gates that coding agents
  run inside.

**The contract shared by every skill here: Claude drafts, humans approve.** No
artifact is ever marked Accepted, Compliant, or Passing by Claude autonomously,
and every report states its evidence rather than asserting a verdict.

## Compliance track

| Skill | Purpose |
|-------|---------|
| [`adr-management`](skills/compliance/adr-management/) | Drafts Architecture Decision Records proactively whenever a significant decision is made; the human reviews and approves. |
| [`cra-evidence`](skills/compliance/cra-evidence/) | Generates the CRA evidence package: SBOM (CycloneDX), SBOM release diff, vulnerability scan + triage drafts, Annex I gap report, EAA/WCAG accessibility module. |

Regulatory clock: CRA vulnerability-reporting obligations from **2026-09-11**;
full CRA obligations from **2027-12-11**; EAA in force since 2025-06-28.
Background in [`docs/compliance/development-brief.md`](docs/compliance/development-brief.md).

## Harness track

*Planned — see [the design spec](docs/superpowers/specs/2026-07-14-harness-skills-track-design.md).*

| Skill | Purpose |
|-------|---------|
| `harness-audit` | Inventories a repo's harness surfaces and reports present / gap / not applicable. |
| `claude-md-authoring` | Writes and repairs `CLAUDE.md` — policy, not routing. |
| `subagent-authoring` | Chooses between skill, subagent, command and hook — then authors it. |
| `harness-eval` | Proves a skill fires when it should, and that a harness change actually helped. |

These skills assume the [Superpowers](https://github.com/obra/superpowers) plugin
is installed. They deliberately do not re-implement planning, TDD, debugging or
code review — Superpowers owns those.

## Install

```bash
git clone https://github.com/Oltrematica/oltrematica-skills.git /tmp/os
/tmp/os/scripts/install.sh adr-management cra-evidence --to /path/to/your-repo
```

Skills install to `.claude/skills/<name>/`. Commit that directory so the team
gets them on pull. Full options — personal scope, submodule, updating — in
[`docs/distribution.md`](docs/distribution.md).

## Repo map

| Path | Contents |
|------|----------|
| `skills/compliance/` | Compliance-track skills |
| `skills/harness/` | Harness-track skills |
| `scripts/install.sh` | Track-aware installer |
| `docs/` | Distribution, contributing conventions, per-track briefs |
| `tests/` | Fixture repos, trigger validation, test evidence (living documentation) |

## Contributing a skill

Read [`docs/contributing-skills.md`](docs/contributing-skills.md) first. It is
short, and it is binding.

## License

Proprietary — Copyright © 2026 Oltrematica. All rights reserved. See
[LICENSE](LICENSE).
```

- [ ] **Step 2: Rewrite docs/distribution.md**

Keep the parts that are still true (the scope ladder, why a plain copy works, the submodule analysis, the tool prerequisites), and replace every stale source path and hand-rolled `cp` command with `install.sh`.

```markdown
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

**Why a plain copy works:** every script inside a skill resolves paths relative
to its own directory (`SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`),
not to this repo. A copy is sufficient — no rewriting, no build step. Verified
by execution, not assumed.

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
```

- [ ] **Step 3: Create docs/contributing-skills.md**

These rules currently exist only as "architecture principles" buried in the compliance development brief, where a harness-skill author would never find them.

```markdown
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
```

- [ ] **Step 4: Verify no stale references survive**

```bash
grep -rn "oltrematica-compliance-skills\|skills/cra-evidence\|skills/adr-management" \
  README.md docs/distribution.md docs/contributing-skills.md
```

Expected: **no output** (exit 1). Every source path is now track-qualified and the clone URL is the new one. Historical documents (`docs/compliance/*`, `docs/superpowers/specs/2026-07-09-*`, `tests/compliance/notes.md`) legitimately still contain the old strings and are excluded from this check — they record what was true when written.

Then re-run the docs link checker from Task 2 Step 5. Expected: `OK`.

- [ ] **Step 5: Verify the README's install command actually runs**

Do not ship a README command nobody executed:

```bash
TARGET=$(mktemp -d)
./scripts/install.sh adr-management cra-evidence --to "$TARGET"
find "$TARGET/.claude/skills" -name SKILL.md
rm -rf "$TARGET"
```

Expected: both `SKILL.md` paths listed, flat under `.claude/skills/<name>/`.

- [ ] **Step 6: Commit**

```bash
git add README.md docs/distribution.md docs/contributing-skills.md
git commit -m "docs: reframe repo as a two-track skills catalogue

README becomes a catalogue (compliance + harness); distribution.md documents
the source-vs-install layout and install.sh; contributing-skills.md lifts the
house conventions out of the compliance brief where nobody would find them."
```

---

### Task 5: Rename the repository

Requires a human with GitHub admin rights. The agent prepares everything and stops.

**Files:**
- Modify: local git remote URL
- Modify: local directory name (optional, cosmetic)

**Interfaces:**
- Consumes: Task 4's docs, which already reference the new URL.
- Produces: nothing consumed by later tasks. Phase 2 works whether or not the rename has happened.

- [ ] **Step 1: Ask the human to rename on GitHub**

Present this, then wait:

> Rename `Oltrematica/oltrematica-compliance-skills` → `Oltrematica/oltrematica-skills`
> (Settings → General → Repository name). GitHub redirects the old clone URL
> indefinitely, so the commands in rollout emails already sent keep working.
> Tell me when it's done — or tell me to skip, and I'll revert the URL in the docs.

- [ ] **Step 2: Point the local remote at the new name**

```bash
git remote set-url origin git@github.com:Oltrematica/oltrematica-skills.git
git remote -v
git fetch origin --dry-run && echo "PASS: new remote URL resolves"
```

Expected: `PASS: new remote URL resolves`.

- [ ] **Step 3: Rename the local working directory (optional)**

```bash
cd .. && mv oltrematica-compliance-skills oltrematica-skills && cd oltrematica-skills
git status --short
```

Expected: clean tree; git does not care about the containing directory's name.

- [ ] **Step 4: No commit**

Nothing to commit — the repo name lives on GitHub and in `.git/config`, neither of which is tracked. Phase 1 ends here.

---

# PHASE 2 — The harness track (PR 2)

---

### Task 6: The bad-harness fixture

Build the fixture *before* the skills that consume it, so `harness-audit` and
`harness-eval` are developed against a target that has known, deliberate defects.
A good fixture proves nothing; a bad one proves the audit works.

**Files:**
- Create: `tests/harness/fixtures/bad-harness/CLAUDE.md`
- Create: `tests/harness/fixtures/bad-harness/composer.json`
- Create: `tests/harness/fixtures/bad-harness/.claude/skills/do-everything/SKILL.md`
- Create: `tests/harness/fixtures/bad-harness/README.md`
- Create: `tests/harness/notes.md`

**Interfaces:**
- Produces: `tests/harness/fixtures/bad-harness/` — a repo root with **five known
  defects**, each of which a later task asserts against by name:
  - **D1** — `CLAUDE.md` is a procedure dump (routing, not policy), well over 200 lines
  - **D2** — no `.claude/agents/` directory
  - **D3** — no `.claude/settings.json`, therefore no hooks
  - **D4** — no verify gate (`composer.json` has no `scripts.test`)
  - **D5** — `.claude/skills/do-everything/` has an over-broad description that
    would trigger on nearly any prompt

- [ ] **Step 1: Create the defective CLAUDE.md (D1)**

`tests/harness/fixtures/bad-harness/CLAUDE.md` — must exceed 200 lines and must be
procedure, not policy. Generate it deterministically rather than hand-writing
slop:

```bash
mkdir -p tests/harness/fixtures/bad-harness/.claude/skills/do-everything
python3 - <<'PY'
lines = [
    "# CLAUDE.md",
    "",
    "## How to add a controller",
    "",
]
# Deliberate anti-pattern: step-by-step procedure that belongs in a skill.
for i in range(1, 61):
    lines.append(f"{i}. Step {i} of the controller procedure: "
                 f"open the file, make the edit, save it, then check the result.")
lines += ["", "## How to add a model", ""]
for i in range(1, 61):
    lines.append(f"{i}. Step {i} of the model procedure: "
                 f"open the file, make the edit, save it, then check the result.")
lines += ["", "## How to write a test", ""]
for i in range(1, 61):
    lines.append(f"{i}. Step {i} of the test procedure: "
                 f"open the file, make the edit, save it, then check the result.")
lines += [
    "",
    "## Misc",
    "",
    "- Be careful.",
    "- Try to write good code.",
    "- Don't break things.",
    "",
]
open("tests/harness/fixtures/bad-harness/CLAUDE.md", "w").write("\n".join(lines) + "\n")
print(len(lines) + 1, "lines written")
PY
```

Expected: `194 lines written` — **check the number**. If it is under 200, the D1
assertion in Task 7 (`> 200 lines`) will not fire. Raise each range to 70 and
re-run until the count exceeds 200.

- [ ] **Step 2: Create the over-triggering skill (D5)**

`tests/harness/fixtures/bad-harness/.claude/skills/do-everything/SKILL.md`:

```markdown
---
name: do-everything
description: Use this skill for any coding task, any question, any file change, or anything else the user asks about. Always use it.
---

# Do Everything

Do whatever the user asks. Be helpful.
```

- [ ] **Step 3: Create the no-verify-gate manifest (D4)**

`tests/harness/fixtures/bad-harness/composer.json` — a valid manifest with **no**
`scripts.test` key:

```json
{
  "name": "oltrematica/bad-harness-fixture",
  "description": "Deliberately defective harness. Test fixture — not a real project.",
  "type": "project",
  "require": {
    "php": "^8.4"
  },
  "scripts": {
    "lint": "pint"
  }
}
```

- [ ] **Step 4: Document the defects so the fixture is self-explaining**

`tests/harness/fixtures/bad-harness/README.md`:

```markdown
# bad-harness fixture

A repo with a deliberately defective Claude Code harness. `harness-audit` and
`harness-eval` are developed and tested against it.

**Do not "fix" these defects.** They are the test.

| ID | Defect | Which skill must catch it |
|----|--------|---------------------------|
| D1 | `CLAUDE.md` is a 190+ line procedure dump — routing, not policy | `harness-audit`, `claude-md-authoring` |
| D2 | No `.claude/agents/` directory | `harness-audit` |
| D3 | No `.claude/settings.json`, therefore no hooks | `harness-audit` |
| D4 | No verify gate — `composer.json` has no `scripts.test` | `harness-audit` |
| D5 | `.claude/skills/do-everything/` triggers on essentially any prompt | `harness-audit`, `harness-eval` |
```

- [ ] **Step 5: Verify the fixture has exactly the defects claimed**

```bash
F=tests/harness/fixtures/bad-harness
echo "D1 CLAUDE.md lines: $(wc -l < $F/CLAUDE.md)  (must be > 200)"
echo "D2 agents dir absent: $([ -d $F/.claude/agents ] && echo NO-BUG-PRESENT || echo yes)"
echo "D3 settings.json absent: $([ -f $F/.claude/settings.json ] && echo NO-BUG-PRESENT || echo yes)"
echo "D4 no test script: $(grep -q '"test"' $F/composer.json && echo NO-BUG-PRESENT || echo yes)"
echo "D5 over-broad skill present: $([ -f $F/.claude/skills/do-everything/SKILL.md ] && echo yes || echo MISSING)"
```

Expected: D1 > 200; D2/D3/D4 all `yes`; D5 `yes`. Any `NO-BUG-PRESENT` means the
fixture is not defective enough — fix it before proceeding.

- [ ] **Step 6: Start the harness evidence log**

Create `tests/harness/notes.md`:

```markdown
# Test notes — harness track

Living documentation: evidence from standalone script tests against the fixture in
`tests/harness/fixtures/`. Append a dated section per test run.

## Fixture

`bad-harness` — a repo with five deliberate harness defects (D1–D5). See its
[README](fixtures/bad-harness/README.md). Do not fix the defects; they are the test.

## 2026-07-14 — fixture construction

| Defect | Assertion | Result |
|--------|-----------|--------|
| D1 | `CLAUDE.md` > 200 lines, procedure not policy | ✓ |
| D2 | no `.claude/agents/` | ✓ |
| D3 | no `.claude/settings.json` | ✓ |
| D4 | `composer.json` has no `scripts.test` | ✓ |
| D5 | `do-everything` skill with an any-prompt description | ✓ |
```

Fill in the actual line count for D1 from Step 5's output.

- [ ] **Step 7: Commit**

```bash
git add tests/harness/
git commit -m "test(harness): add the bad-harness fixture

Five deliberate defects (D1-D5) for harness-audit and harness-eval to catch.
A good fixture proves nothing; a bad one proves the audit works."
```

---

### Task 7: `harness-audit` skill

**Files:**
- Create: `skills/harness/harness-audit/SKILL.md`
- Create: `skills/harness/harness-audit/scripts/inventory.sh`
- Create: `skills/harness/harness-audit/assets/audit_report_template.md`

**Interfaces:**
- Consumes: `tests/harness/fixtures/bad-harness/` (Task 6).
- Produces: `inventory.sh <repo-root>` → JSON on stdout with exactly these seven
  top-level keys: `claude_md`, `skills`, `agents`, `hooks`, `commands`, `mcp`,
  `verify_gate`. Exit 0 on success, 1 if `<repo-root>` is not a directory.
  Tasks 8, 9 and 10 are handed off to *by* this skill; they do not import from it.

- [ ] **Step 1: Write the failing test**

Create `tests/harness/inventory.sh.test`:

```bash
#!/usr/bin/env bash
# Contract test for harness-audit/scripts/inventory.sh against the bad-harness fixture.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INV="$REPO_ROOT/skills/harness/harness-audit/scripts/inventory.sh"
FIXTURE="$REPO_ROOT/tests/harness/fixtures/bad-harness"
PASS=0; FAIL=0
check() {
  if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1))
  else echo "  FAIL: $1 (expected '$2', got '$3')"; FAIL=$((FAIL+1)); fi
}

OUT=$(bash "$INV" "$FIXTURE" 2>/dev/null); RC=$?
check "exit code 0 on a valid repo" "0" "$RC"
check "stdout is valid JSON" "yes" \
  "$(printf '%s' "$OUT" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null && echo yes || echo no)"

q() { printf '%s' "$OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

check "all seven surfaces reported" "yes" \
  "$(q "'yes' if sorted(d) == sorted(['claude_md','skills','agents','hooks','commands','mcp','verify_gate']) else sorted(d)")"
check "D1: CLAUDE.md found and over 200 lines" "True" "$(q "d['claude_md']['exists'] and d['claude_md']['lines'] > 200")"
check "D2: no agents"        "0"     "$(q "len(d['agents'])")"
check "D3: no hooks"         "False" "$(q "d['hooks']['configured']")"
check "D4: no verify gate"   "False" "$(q "d['verify_gate']['detected']")"
check "D5: the bad skill is inventoried" "True" "$(q "'do-everything' in d['skills']")"

echo "error path: non-existent repo root"
bash "$INV" /no/such/path >/dev/null 2>&1
check "exit code 1" "1" "$?"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run it to confirm it fails (RED)**

```bash
bash tests/harness/inventory.sh.test
```

Expected: `No such file or directory` for `inventory.sh`; `PASS=0`; non-zero exit.

- [ ] **Step 3: Write inventory.sh**

Create `skills/harness/harness-audit/scripts/inventory.sh`:

```bash
#!/usr/bin/env bash
# inventory.sh — read-only inventory of a repo's Claude Code harness surfaces.
#
# Usage: inventory.sh [repo-root]     (default: current directory)
# Output: JSON on stdout describing seven surfaces.
# Exit: 0 on success; 1 if repo-root is not a directory.
#
# This script reports FACTS ONLY. It never judges. Classification into
# present/gap/not-applicable is the skill's job, not the script's.
set -euo pipefail

ROOT="${1:-.}"
[ -d "$ROOT" ] || { echo "ERROR: not a directory: $ROOT" >&2; exit 1; }
ROOT=$(cd "$ROOT" && pwd)

# Emit a JSON array of the basenames of a directory's entries (empty array if absent).
list_names() {
  local dir="$1"
  if [ ! -d "$dir" ]; then printf '[]'; return; fi
  python3 - "$dir" <<'PY'
import json, os, sys
d = sys.argv[1]
print(json.dumps(sorted(e for e in os.listdir(d) if not e.startswith('.'))))
PY
}

json_bool() { [ "$1" = "1" ] && printf 'true' || printf 'false'; }

# --- Surface 1: CLAUDE.md ---
CLAUDE_MD="$ROOT/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
  CM_EXISTS=true
  CM_LINES=$(wc -l < "$CLAUDE_MD" | tr -d ' ')
else
  CM_EXISTS=false
  CM_LINES=0
fi

# --- Surfaces 2, 3, 5: skills, agents, commands ---
SKILLS=$(list_names "$ROOT/.claude/skills")
AGENTS=$(list_names "$ROOT/.claude/agents")
COMMANDS=$(list_names "$ROOT/.claude/commands")

# --- Surface 4: hooks ---
SETTINGS="$ROOT/.claude/settings.json"
HOOKS_FILE=false
HOOKS_CONFIGURED=false
if [ -f "$SETTINGS" ]; then
  HOOKS_FILE=true
  if python3 -c "import json,sys; d=json.load(open('$SETTINGS')); sys.exit(0 if d.get('hooks') else 1)" 2>/dev/null; then
    HOOKS_CONFIGURED=true
  fi
fi

# --- Surface 6: MCP ---
MCP_FILE=false
[ -f "$ROOT/.mcp.json" ] && MCP_FILE=true

# --- Surface 7: verify gate ---
# A verify gate is any declared way to run the test suite.
GATE_DETECTED=false
GATE_SOURCE=""
if [ -f "$ROOT/composer.json" ] && python3 -c "import json,sys; d=json.load(open('$ROOT/composer.json')); sys.exit(0 if 'test' in d.get('scripts',{}) else 1)" 2>/dev/null; then
  GATE_DETECTED=true; GATE_SOURCE="composer.json scripts.test"
elif [ -f "$ROOT/package.json" ] && python3 -c "import json,sys; d=json.load(open('$ROOT/package.json')); sys.exit(0 if 'test' in d.get('scripts',{}) else 1)" 2>/dev/null; then
  GATE_DETECTED=true; GATE_SOURCE="package.json scripts.test"
elif [ -f "$ROOT/Makefile" ] && grep -qE '^test:' "$ROOT/Makefile" 2>/dev/null; then
  GATE_DETECTED=true; GATE_SOURCE="Makefile test target"
elif [ -d "$ROOT/.github/workflows" ] && grep -rqlE 'run:.*(test|pest|phpunit|vitest|jest)' "$ROOT/.github/workflows" 2>/dev/null; then
  GATE_DETECTED=true; GATE_SOURCE="GitHub Actions workflow"
fi

cat <<JSON
{
  "repo_root": "$ROOT",
  "claude_md": { "exists": $CM_EXISTS, "lines": $CM_LINES },
  "skills": $SKILLS,
  "agents": $AGENTS,
  "commands": $COMMANDS,
  "hooks": { "settings_file": $HOOKS_FILE, "configured": $HOOKS_CONFIGURED },
  "mcp": { "config_file": $MCP_FILE },
  "verify_gate": { "detected": $GATE_DETECTED, "source": "$GATE_SOURCE" }
}
JSON
```

```bash
chmod +x skills/harness/harness-audit/scripts/inventory.sh
```

- [ ] **Step 4: Run the test to verify it passes (GREEN)**

```bash
bash tests/harness/inventory.sh.test
```

Expected: `PASS=9 FAIL=0`.

Also run it against *this* repo, which has a healthy-ish harness, to prove the
script does not just always report gaps:

```bash
bash skills/harness/harness-audit/scripts/inventory.sh . | python3 -m json.tool
```

Expected: valid JSON; `claude_md.exists` reflects reality; no crash.

- [ ] **Step 5: Write the audit report template**

`skills/harness/harness-audit/assets/audit_report_template.md`:

```markdown
# Harness audit — {{REPO_NAME}}

**Status:** Proposed
**Date:** {{DATE}}
**Auditor:** Claude (drafted) — awaiting human review

## Summary

{{ONE_PARAGRAPH_PLAIN_LANGUAGE_SUMMARY}}

## Surfaces

Each surface is **present**, a **gap**, or **not applicable** — with a reason.
No surface is silently skipped, and none is marked simply "good".

| Surface | State | Evidence / rationale |
|---------|-------|----------------------|
| CLAUDE.md | | |
| Skills (`.claude/skills/`) | | |
| Subagents (`.claude/agents/`) | | |
| Hooks (`.claude/settings.json`) | | |
| Slash commands (`.claude/commands/`) | | |
| MCP servers (`.mcp.json`) | | |
| Verify gate | | |

## Recommended actions

Ordered by impact. Each names the skill that does the work.

| # | Action | Skill | Why it matters |
|---|--------|-------|----------------|
| 1 | | | |

## Not applicable

Surfaces deliberately excluded for this repo, and why.

## Review

- [ ] Reviewed by: ____________  Date: ________
- [ ] Accepted / Changes requested
```

- [ ] **Step 6: Write SKILL.md**

`skills/harness/harness-audit/SKILL.md`. Body must stay under 500 lines.

```markdown
---
name: harness-audit
description: >-
  Audit, bootstrap or improve a repository's Claude Code harness — the CLAUDE.md,
  skills, subagents, hooks, slash commands, MCP servers and verification gate that
  coding agents run inside. Use when onboarding a repo to agentic development
  ("set up Claude Code for this repo", "onboard this project", "get this repo
  ready for Claude"), when harness quality is in question ("is our Claude setup
  any good?", "audit our harness", "what's missing from our .claude directory?"),
  or when an agent keeps underperforming in a repo and the cause may be missing or
  rotten scaffolding rather than the task itself. Produces a present/gap/not-
  applicable report — never a bare "looks good".
---

# Harness Audit

The entry point to the harness track. It answers one question — *what scaffolding
does this repo give a coding agent, and what is missing?* — and hands the fixing
to the skill that owns each surface.

## Core contract

1. **Claude drafts, humans approve.** The report ships as `Proposed`. Never mark a
   harness "compliant", "healthy" or "done" on your own initiative.
2. **Facts from the script, judgement from you.** `scripts/inventory.sh` reports
   what exists. It never judges. You classify. Do not eyeball the filesystem and
   skip the script — the script is what makes the facts reproducible.
3. **Three states, no fourth.** Every surface is **present**, a **gap**, or **not
   applicable**, each with a stated reason. "Looks fine" is not a state.
4. **One review batch.** Audit all seven surfaces, then present *one* report. Do
   not interrupt the human seven times.

## Workflow

### 1. Inventory (deterministic)

```bash
scripts/inventory.sh <repo-root>
```

Returns JSON with seven keys: `claude_md`, `skills`, `agents`, `hooks`,
`commands`, `mcp`, `verify_gate`. If the script cannot run, say so and stop —
do not fall back to guessing.

### 2. Classify each surface

| Surface | Present when | Gap when | Typically N/A when |
|---------|--------------|----------|--------------------|
| **CLAUDE.md** | Exists, and is policy: scope, mandates, exceptions, what "done" means here | Absent, **or** it is procedure/routing rather than policy, **or** it is long enough that the agent demonstrably drops parts of it | Never — every repo an agent works in needs one |
| **Skills** | The repo's recurring procedures are skills | Procedures live in CLAUDE.md prose instead, or a skill's description is so broad it fires on everything | A repo with no recurring agent procedures |
| **Subagents** | Isolated-context work (research, review) has a definition in `.claude/agents/` | Heavy read-only work is done in the main context, blowing the window | Small repos where nothing needs isolation |
| **Hooks** | Things that MUST happen every time (format, lint, block secrets) are hooks | Those things are written as CLAUDE.md instructions and therefore sometimes skipped | No deterministic must-run steps |
| **Slash commands** | Frequent human-fired prompts are commands | The team pastes the same prompt repeatedly | No repeated prompts |
| **MCP** | Configured where external systems are genuinely needed | An external system is accessed by ad-hoc shell instead | No external system in the loop — the common case |
| **Verify gate** | A declared way to run the tests, and CLAUDE.md says it must pass before "done" | No test command, or one that nobody told the agent to run | A repo with no executable code |

**Line count is a signal, not a verdict.** A long CLAUDE.md is evidence to
investigate, not an automatic gap. Read it and ask: is this *policy* (what is
mandatory here) or *procedure* (how to do a thing)? Procedure is a skill wearing
a CLAUDE.md costume — that is the gap.

### 3. Report

Fill `assets/audit_report_template.md`. Write it to `docs/harness-audit.md` in the
target repo unless the human says otherwise. Lead with a plain-language paragraph:
a tech lead who has never opened `.claude/` should understand the state of things
without reading the table.

### 4. Hand off the fixes — do not do them here

This skill diagnoses. It does not author.

| Gap | Hand off to |
|-----|-------------|
| CLAUDE.md missing, bloated, or full of procedure | `claude-md-authoring` |
| Needs a subagent, a command, or a hook | `subagent-authoring` |
| A skill's description over- or under-triggers | `harness-eval` |
| Needs a new skill written | `superpowers:writing-skills` (+ `docs/contributing-skills.md`) |
| No verify gate | The built-in `verify` skill bootstraps one |
| Hooks need wiring into settings.json | The built-in `update-config` skill owns settings.json |

Propose the handoffs in priority order and let the human pick. Do not silently
chain into four skills and rewrite the repo.

## Bootstrap mode (empty harness)

When a repo has no `.claude/` at all, the audit is trivially "all gaps" — say so
in one line and move straight to proposing the minimum viable harness, in this
order:

1. **CLAUDE.md** — policy only. Without it nothing else lands.
2. **Verify gate** — the agent must know how to prove its work.
3. **Skills** — only for procedures that actually recur. Do not invent three
   speculative skills on day one.
4. Everything else, later, driven by observed friction rather than by this list.

Resist installing the full seven surfaces on a repo that needs two. An unused hook
is a liability; an unused MCP server is a bigger one.
```

- [ ] **Step 7: Verify the skill meets the house rules**

```bash
S=skills/harness/harness-audit/SKILL.md
echo "SKILL.md lines: $(wc -l < $S)  (must be < 500)"
grep -c "^name:\|^description:" $S   # expect 2
grep -qiE '\*\*status:\*\* *(accepted|compliant|passing)' -r skills/harness/harness-audit/ \
  && echo "FAIL: an artifact defaults to an approved status" \
  || echo "PASS: nothing defaults to Accepted/Compliant/Passing"
```

Expected: under 500 lines; both frontmatter keys present; the status check PASSes.

- [ ] **Step 8: Record the evidence**

Append to `tests/harness/notes.md`:

```markdown
## 2026-07-14 — inventory.sh

**Step 2: RED** — script missing, `PASS=0`, exit non-zero ✓

**Step 4: GREEN**

| # | Test | Result |
|---|------|--------|
| 1 | Exit 0 + valid JSON on the fixture | ✓ |
| 2 | All seven surfaces present as keys | ✓ |
| 3 | D1 detected (CLAUDE.md > 200 lines) | ✓ |
| 4 | D2 detected (0 agents) | ✓ |
| 5 | D3 detected (hooks not configured) | ✓ |
| 6 | D4 detected (no verify gate) | ✓ |
| 7 | D5 inventoried (`do-everything` in skills) | ✓ |
| 8 | Non-existent repo root → exit 1, no traceback | ✓ |
| 9 | Run against this repo → valid JSON, no crash (proves it doesn't always report gaps) | ✓ |

**Summary**: inventory.sh contract verified — facts only, no judgement; all five
fixture defects surfaced in the JSON; error path clean.
```

Paste the real command output, not a copy of this table if the numbers differ.

- [ ] **Step 9: Commit**

```bash
git add skills/harness/harness-audit tests/harness/
git commit -m "feat(harness-audit): inventory a repo's harness and report gaps

Deterministic inventory.sh (facts only) plus a SKILL.md that classifies each of
the seven surfaces as present/gap/not-applicable and hands fixes to the skill
that owns them."
```

---

### Task 8: `claude-md-authoring` skill

**Files:**
- Create: `skills/harness/claude-md-authoring/SKILL.md`
- Create: `skills/harness/claude-md-authoring/references/antipatterns.md`
- Create: `skills/harness/claude-md-authoring/assets/claude_md_skeleton.md`

**Interfaces:**
- Consumes: nothing at runtime. `harness-audit` hands off to this skill by name.
- Produces: no script. This skill is pure judgement; there is nothing deterministic
  to extract.

- [ ] **Step 1: Write the skeleton asset**

`skills/harness/claude-md-authoring/assets/claude_md_skeleton.md`:

```markdown
# CLAUDE.md

> Policy for this repo. What is mandatory, what is out of scope, what "done"
> means. Procedures live in skills, not here.

## Stack

<!-- Only versions an agent would otherwise guess wrong. Not a full manifest. -->

## Definition of done

<!-- The exact commands that must pass, and the standard they must meet. -->

- [ ] `<test command>` passes
- [ ] `<lint command>` clean

## Mandatory

<!-- Things that must happen, that an agent would not infer. Each one imperative
     and verifiable: "before X, always Y" — not "be careful with X". -->

## Out of scope / exceptions

<!-- Directories, modules or workflows this policy does not govern, and why. -->

## Skills

<!-- Which skills are mandatory in this repo and WHEN — never HOW. The skill
     owns how. If you find yourself explaining a procedure here, stop: that
     paragraph is a skill. -->
```

- [ ] **Step 2: Write the antipatterns reference**

`skills/harness/claude-md-authoring/references/antipatterns.md`:

```markdown
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
```

- [ ] **Step 3: Write SKILL.md**

`skills/harness/claude-md-authoring/SKILL.md`:

```markdown
---
name: claude-md-authoring
description: >-
  Write, restructure or debug a CLAUDE.md file at user, project or subdirectory
  scope. Use when a CLAUDE.md is being created or edited ("write a CLAUDE.md for
  this repo", "add this rule to CLAUDE.md", "our CLAUDE.md is too long", "clean up
  our CLAUDE.md"), and when Claude repeatedly ignores or misapplies a documented
  instruction ("the agent keeps forgetting to run the tests", "why is Claude
  ignoring our conventions?", "it keeps doing X even though CLAUDE.md says not
  to") — the usual cause is a CLAUDE.md carrying procedure that belongs in a skill,
  or grown long enough that instructions compete. Enforces CLAUDE.md as policy,
  not routing.
---

# CLAUDE.md Authoring

## The one rule

**CLAUDE.md is policy, not routing.**

*Policy* is what is mandatory in this repo, what is out of scope, and what "done"
means. It is short, imperative, verifiable, and it is loaded into every context
whether or not it is relevant.

*Routing* — "when the user asks about X, do Y" — is what a skill's `description:`
frontmatter already does, and does better. *Procedure* — "how to do X" — is what a
skill body is for.

The test for any line you are about to add: **would this still be true on a task
that has nothing to do with it?** If not, it is not policy, and it should not be
paying rent in every context window.

## Scopes

| File | Holds | Shared with |
|------|-------|-------------|
| `~/.claude/CLAUDE.md` | Personal working habits | Nobody |
| `<repo>/CLAUDE.md` | Team policy for this repo | The team, via git |
| `<repo>/<module>/CLAUDE.md` | Rules binding only inside that module | The team; loaded only when working in there |

Putting a personal preference in a shared file is how a team ends up arguing about
someone's tone preferences in code review. Putting a module rule at repo root is
how you pay for it on every unrelated task.

## Authoring workflow

1. **Read what exists.** Never write over a CLAUDE.md without reading it — some of
   what is in there was hard-won and is load-bearing.
2. **Draft from `assets/claude_md_skeleton.md`.** Fill only the sections that have
   real content. An empty section is worse than a missing one.
3. **Every rule imperative and verifiable.** "Before Y, always check Z" — never
   "be careful with Y". If you cannot state how to check compliance, you cannot
   state the rule.
4. **Route by mandate, not by trigger.** Say *when a skill is mandatory in this
   repo*; never restate what the skill's description already says.
5. **Show the diff and stop.** CLAUDE.md is the human's constitution for the repo.
   Propose; do not merge.

## Diagnostic workflow — "the agent keeps ignoring X"

This is the most common reason this skill gets invoked, and the instinct — *add a
stronger instruction, in caps* — makes it worse. Work the list in order:

1. **Measure the length.** `wc -l CLAUDE.md`. Past a couple of hundred lines,
   instruction-following degrades measurably: rule 80 competes with rule 3, and one
   of them loses. The fix is subtraction, not emphasis.
2. **Classify every section as policy or procedure.** Procedure is usually the bulk
   of it. Each procedure section is a skill that has not been extracted yet.
   Extracting it shortens the file *and* makes the procedure available on demand —
   strictly better on both axes.
3. **Ask whether X must hold *every single time*.** If yes, it is not an
   instruction — it is a **hook**. Instructions are probabilistic; hooks are
   deterministic. "Always run the formatter after editing" belongs in
   `settings.json` (use the built-in `update-config` skill), not in prose. This is
   the single highest-value move in this workflow, and it is the one people skip.
4. **Check the scope.** A rule about a module, sitting at repo root, is diluted
   across every task that never touches that module.
5. **Only now, rewrite the rule.** If it survived steps 1–4, it may genuinely be
   badly phrased — vague, unverifiable, or contradicted by another rule elsewhere
   in the file. Contradictions are common in files that have grown by accretion.

Full catalogue with symptoms and fixes: `references/antipatterns.md`.

## What good looks like

Short. Verifiable. Every line earns its place in every context window. If you
cannot say why a section would matter on a task unrelated to it, cut the section.
```

- [ ] **Step 4: Verify against the fixture (the skill must catch D1)**

There is no script here, so the verification is a judgement rehearsal against the
known-bad fixture. Run the diagnostic workflow's step 1 and step 2 by hand:

```bash
F=tests/harness/fixtures/bad-harness
wc -l < $F/CLAUDE.md
grep -c "^## How to" $F/CLAUDE.md
```

Expected: over 200 lines, and 3 `## How to ...` sections. Confirm that the skill's
diagnostic workflow, followed literally, reaches the right conclusion: **D1 is a
procedure dump; the three `How to` sections are three skills; the fix is extraction,
not emphasis.** Record that conclusion in the notes (Step 6) — if following your own
skill on the fixture does not reach it, the skill is wrong and must be fixed now.

- [ ] **Step 5: Verify house rules**

```bash
S=skills/harness/claude-md-authoring/SKILL.md
echo "SKILL.md lines: $(wc -l < $S)  (must be < 500)"
python3 - <<'PY'
import re
src = open('skills/harness/claude-md-authoring/SKILL.md').read()
assert src.startswith('---'), "missing frontmatter"
fm = src.split('---')[1]
assert 'name:' in fm and 'description:' in fm, "frontmatter incomplete"
print("PASS: frontmatter well-formed")
PY
```

- [ ] **Step 6: Record the evidence**

Append to `tests/harness/notes.md`:

```markdown
## 2026-07-14 — claude-md-authoring (no script; judgement rehearsal)

Ran the SKILL.md diagnostic workflow against the `bad-harness` fixture by hand:

| Step | Check | Result |
|------|-------|--------|
| 1 | `wc -l CLAUDE.md` → over the 200-line threshold | ✓ (actual: <N>) |
| 2 | Classify sections: 3 × `## How to ...` = procedure, not policy | ✓ |
| 3 | Conclusion reached by following the skill literally | ✓ D1 identified as a procedure dump; fix is extraction into three skills, not stronger wording |

SKILL.md under 500 lines; frontmatter well-formed. No script — this skill is pure
judgement and has nothing deterministic to extract.
```

- [ ] **Step 7: Commit**

```bash
git add skills/harness/claude-md-authoring tests/harness/notes.md
git commit -m "feat(claude-md-authoring): CLAUDE.md as policy, not routing

Authoring workflow plus a diagnostic workflow for 'the agent keeps ignoring X',
whose usual root cause is a file long enough that instructions compete, or a
must-run rule that should have been a hook."
```

---

### Task 9: `subagent-authoring` skill

**Files:**
- Create: `skills/harness/subagent-authoring/SKILL.md`
- Create: `skills/harness/subagent-authoring/assets/agent_template.md`

**Interfaces:**
- Consumes: nothing at runtime.
- Produces: no script.

- [ ] **Step 1: Write the agent template**

`skills/harness/subagent-authoring/assets/agent_template.md`:

```markdown
---
name: <kebab-case-name>
description: <When to dispatch this agent, in the words the main agent would think. This is the router — it is the only thing seen at dispatch time.>
tools: <comma-separated allowlist — least privilege. Omit Write/Edit for read-only agents.>
model: <sonnet | opus | haiku — omit to inherit the session model>
---

# <Agent Name>

<One paragraph: what this agent is for, and what it returns.>

## Your task

<Imperative instructions. The agent sees only its dispatch prompt and this file —
it has none of the main conversation's context. Say what it needs, explicitly.>

## Return

<Exactly what the final message must contain. The agent's final message IS the
return value handed back to the main agent — not a human-facing summary. Be
specific about format.>
```

- [ ] **Step 2: Write SKILL.md**

`skills/harness/subagent-authoring/SKILL.md`:

```markdown
---
name: subagent-authoring
description: >-
  Decide between a skill, a subagent, a slash command and a hook — then author the
  chosen artifact, in particular subagent definitions in .claude/agents/. Use when
  new agent capability is being added to a repo ("create an agent that reviews
  migrations", "I want a subagent for research", "should this be a skill or a
  command?", "make this run automatically every time", "add a /deploy command"),
  or when an existing subagent needs its tool allowlist, model tier or description
  tuned. Starts with the choice of artifact, because the most common harness
  mistake is building the wrong one.
---

# Subagent Authoring

## Start with the artifact, not the file

The most common harness mistake is not a badly written subagent — it is a subagent
that should have been a hook. Choose first.

| Build a... | When | Because |
|-----------|------|---------|
| **Skill** | A procedure the main agent should follow, in the main context, with the conversation's full history | It needs to see what happened; it should mutate the work in flight |
| **Subagent** | Isolated work that returns a *conclusion*: research, a survey, an audit, a review | It would otherwise flood the main context with material nobody needs after the answer |
| **Slash command** | A prompt the human fires deliberately and repeatedly | The human decides when. There is no autonomous trigger to define |
| **Hook** | It must happen **every time**, without exception | Instructions are probabilistic. Hooks are deterministic. If "must always" is in the requirement, stop reading this table and build a hook |

The decisive question for skill-versus-subagent: **does the main agent need the
work, or the conclusion?** If it needs the work — the files read, the edits made —
that is a skill. If it needs only the answer, dispatch a subagent and keep the
context clean.

The decisive question for anything-versus-hook: **is it acceptable for this to be
skipped once in twenty runs?** If no, it is a hook. No amount of capitalization in
CLAUDE.md makes a model deterministic.

Hooks live in `settings.json` — hand off to the built-in `update-config` skill,
which owns that file. Do not hand-edit it here.

## Authoring a subagent

Definitions live in `.claude/agents/<name>.md`. Start from
`assets/agent_template.md`.

### The description is the dispatcher

The main agent sees **only** the `description:` when deciding whether to dispatch.
Write it as the condition under which delegating is right, in the words the main
agent would actually think — not as a job title.

Weak: `Reviews database migrations.`
Strong: `Use when a migration file has been added or changed and needs review for
reversibility, locking behavior and data loss, before it is committed.`

### Tools: least privilege, and mean it

Grant the minimum. A research agent that can `Write` will eventually write
something, at the worst possible moment, with no one watching.

| Agent kind | Tools |
|-----------|-------|
| Research / survey / audit | `Read, Grep, Glob, Bash` — **no** `Write`, **no** `Edit` |
| Review | `Read, Grep, Glob, Bash` — reviews produce findings, not fixes |
| Implementation | `Read, Write, Edit, Bash` |

If you cannot name why an agent needs `Write`, it does not need `Write`.

### Model tier

Omit `model:` and inherit the session's. Set it only when you are confident:
a cheaper tier for mechanical, high-volume work; a stronger one for the hardest
judgement. Guessing here costs money on every dispatch, forever.

### It has none of your context

A subagent starts cold. It cannot see the conversation, the plan, or the file you
were just looking at. Everything it needs goes in the dispatch prompt or the
definition. The single most common subagent bug is a prompt written as though the
agent were listening the whole time.

### Its final message is the return value

Say exactly what the final message must contain, and say that it is a return
value, not a status report for a human. "Return the file paths and line numbers,
one per line, no prose" beats "summarize what you found".

## Verify it before you rely on it

A subagent whose description never matches is dead code that looks alive. Dispatch
it once against a real case and confirm it both fires and returns the shape you
specified. For a proper trigger check — including the negative cases — use
`harness-eval`.
```

- [ ] **Step 3: Verify house rules**

```bash
S=skills/harness/subagent-authoring/SKILL.md
echo "SKILL.md lines: $(wc -l < $S)  (must be < 500)"
grep -q "update-config" $S && echo "PASS: hands hooks off to update-config rather than editing settings.json" || echo "FAIL: no handoff"
grep -q "least privilege\|Least privilege" $S && echo "PASS: tool allowlist guidance present" || echo "FAIL"
```

Expected: under 500 lines, both PASS.

- [ ] **Step 4: Verify the artifact selector is actually decisive**

The selector is the skill's whole value; a table that leaves a reader undecided is
worthless. Test it against four real cases and confirm each lands on exactly one row:

| Case | Must select |
|------|-------------|
| "Format every file after editing it" | **Hook** — "every" is in the requirement |
| "Survey how auth is done across 40 files and tell me the pattern" | **Subagent** — the main agent needs the conclusion, not the 40 files |
| "Draft an ADR whenever we make an architectural decision" | **Skill** — mutates the work in flight, needs conversation context |
| "Let me fire a release checklist prompt on demand" | **Slash command** — the human decides when |

Walk each case through the table in the SKILL.md. If any case is ambiguous, the
table is wrong — fix it now rather than shipping a coin-flip.

- [ ] **Step 5: Record the evidence**

Append to `tests/harness/notes.md`:

```markdown
## 2026-07-14 — subagent-authoring (no script; selector validation)

Artifact selector walked against four cases; each landed on exactly one row:

| Case | Selected | Ambiguous? |
|------|----------|------------|
| "Format every file after editing" | Hook | no — "every" is decisive |
| "Survey auth across 40 files" | Subagent | no — conclusion, not work |
| "Draft an ADR when a decision is made" | Skill | no — mutates work in flight |
| "Fire a release checklist on demand" | Slash command | no — human-triggered |

SKILL.md under 500 lines; hooks handed off to `update-config`; least-privilege
tool guidance present.
```

- [ ] **Step 6: Commit**

```bash
git add skills/harness/subagent-authoring tests/harness/notes.md
git commit -m "feat(subagent-authoring): choose the artifact, then author it

Leads with the skill/subagent/command/hook selector, because the most common
harness mistake is building a subagent where a hook was required."
```

---

### Task 10: `harness-eval` skill

The differentiator. Trigger validation plus behavioral regression, with the eval
spec in git rather than in a chat log.

**Files:**
- Create: `skills/harness/harness-eval/SKILL.md`
- Create: `skills/harness/harness-eval/scripts/eval_run.py`
- Create: `skills/harness/harness-eval/assets/eval_spec.example.json`

**Interfaces:**
- Consumes: `tests/harness/fixtures/bad-harness/` (Task 6, defect D5).
- Produces:
  - `eval_run.py --validate <spec.json>` → exit 0 if valid, 2 with reasons if not.
  - `eval_run.py --emit-table <spec.json>` → markdown results table on stdout,
    `Expected` filled, `Result` blank for Claude to fill.
  - Spec format: `{"skills": [{"name": str, "prompts": [{"prompt": str, "expect": "trigger"|"no-trigger"}]}], "regressions": [{"prompt": str, "expect_observable": str}]}`

- [ ] **Step 1: Write the failing test**

Create `tests/harness/eval_run.py.test`:

```bash
#!/usr/bin/env bash
# Contract test for harness-eval/scripts/eval_run.py
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVAL="$REPO_ROOT/skills/harness/harness-eval/scripts/eval_run.py"
SPEC="$REPO_ROOT/skills/harness/harness-eval/assets/eval_spec.example.json"
PASS=0; FAIL=0
check() {
  if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1))
  else echo "  FAIL: $1 (expected '$2', got '$3')"; FAIL=$((FAIL+1)); fi
}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

echo "1. the shipped example spec is valid"
python3 "$EVAL" --validate "$SPEC" >/dev/null 2>&1
check "exit 0" "0" "$?"

echo "2. a spec with too few prompts is rejected"
cat > "$TMP/thin.json" <<'JSON'
{"skills": [{"name": "thin", "prompts": [
  {"prompt": "a", "expect": "trigger"},
  {"prompt": "b", "expect": "no-trigger"}
]}]}
JSON
ERR=$(python3 "$EVAL" --validate "$TMP/thin.json" 2>&1); RC=$?
check "exit 2" "2" "$RC"
check "explains the 5/5 minimum" "yes" "$(echo "$ERR" | grep -qi "5" && echo yes || echo no)"

echo "3. duplicate prompts are rejected"
python3 - "$TMP/dupe.json" <<'PY'
import json, sys
p = [{"prompt": "same", "expect": "trigger"}] * 5 + \
    [{"prompt": f"neg {i}", "expect": "no-trigger"} for i in range(5)]
json.dump({"skills": [{"name": "dupe", "prompts": p}]}, open(sys.argv[1], "w"))
PY
ERR=$(python3 "$EVAL" --validate "$TMP/dupe.json" 2>&1); RC=$?
check "exit 2" "2" "$RC"
check "names the duplicate" "yes" "$(echo "$ERR" | grep -qi "duplicate" && echo yes || echo no)"

echo "4. an unreadable spec fails cleanly, without a traceback"
ERR=$(python3 "$EVAL" --validate /no/such/spec.json 2>&1); RC=$?
check "exit 2" "2" "$RC"
check "no traceback" "no" "$(echo "$ERR" | grep -q "Traceback" && echo yes || echo no)"

echo "5. --emit-table renders a markdown table"
OUT=$(python3 "$EVAL" --emit-table "$SPEC" 2>/dev/null)
check "exit 0" "0" "$?"
check "has a table header" "yes" "$(echo "$OUT" | grep -q '| # | Prompt | Expected | Result |' && echo yes || echo no)"
check "Result column left blank for Claude" "yes" "$(echo "$OUT" | grep -qE '\| *\|$' && echo yes || echo no)"

echo
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Run it to confirm it fails (RED)**

```bash
bash tests/harness/eval_run.py.test
```

Expected: `can't open file ... eval_run.py`; `PASS=0`; non-zero exit.

- [ ] **Step 3: Write the example spec**

`skills/harness/harness-eval/assets/eval_spec.example.json` — a real spec for the
fixture's defective skill (D5), so the example doubles as a regression case:

```json
{
  "$comment": "Eval spec. Copy to <repo>/.claude/eval_spec.json and edit. JSON, not YAML: python3 stdlib has json and not yaml, and this repo adds no dependencies.",
  "skills": [
    {
      "name": "do-everything",
      "prompts": [
        {"prompt": "add a controller for invoices", "expect": "no-trigger"},
        {"prompt": "what is the capital of France?", "expect": "no-trigger"},
        {"prompt": "rename this variable", "expect": "no-trigger"},
        {"prompt": "explain this stack trace", "expect": "no-trigger"},
        {"prompt": "update the changelog", "expect": "no-trigger"},
        {"prompt": "do everything", "expect": "trigger"},
        {"prompt": "use the do-everything skill", "expect": "trigger"},
        {"prompt": "run the do-everything workflow", "expect": "trigger"},
        {"prompt": "invoke do-everything on this repo", "expect": "trigger"},
        {"prompt": "do-everything, please", "expect": "trigger"}
      ]
    }
  ],
  "regressions": [
    {
      "prompt": "add a controller for invoices",
      "expect_observable": "The agent does NOT invoke do-everything, and runs the repo's declared test command before claiming completion."
    }
  ]
}
```

- [ ] **Step 4: Write eval_run.py**

`skills/harness/harness-eval/scripts/eval_run.py`:

```python
#!/usr/bin/env python3
"""eval_run.py — validate a harness eval spec and render its results table.

This script does the deterministic half of an eval: it checks the spec is
well-formed and worth running, and renders the table Claude fills in.

It does NOT judge whether a skill fired. That judgement is the model's, made by
dispatching each prompt to a fresh subagent — see SKILL.md. A script cannot do it,
and a script that pretended to would be the worst kind of evidence: confident and
wrong.

Usage:
  eval_run.py --validate   <spec.json>   exit 0 if valid, 2 with reasons if not
  eval_run.py --emit-table <spec.json>   markdown results table on stdout

Spec format:
  {
    "skills": [
      {"name": str,
       "prompts": [{"prompt": str, "expect": "trigger" | "no-trigger"}, ...]}
    ],
    "regressions": [{"prompt": str, "expect_observable": str}, ...]   # optional
  }

Python stdlib only. No dependencies.
"""
import argparse
import json
import sys

MIN_PER_CLASS = 5
VALID_EXPECT = ("trigger", "no-trigger")


def load(path):
    try:
        with open(path) as fh:
            return json.load(fh)
    except FileNotFoundError:
        sys.exit(f"ERROR: spec not found: {path}")
    except json.JSONDecodeError as exc:
        sys.exit(f"ERROR: spec is not valid JSON: {path}\n  {exc}")


def validate(spec, path):
    """Return a list of human-readable problems. Empty list means valid."""
    problems = []

    skills = spec.get("skills")
    if not isinstance(skills, list) or not skills:
        return [f"{path}: 'skills' must be a non-empty list"]

    for i, skill in enumerate(skills):
        name = skill.get("name") or f"<skills[{i}] has no name>"
        prompts = skill.get("prompts")
        if not isinstance(prompts, list):
            problems.append(f"{name}: 'prompts' must be a list")
            continue

        counts = {"trigger": 0, "no-trigger": 0}
        seen = set()
        for entry in prompts:
            text = entry.get("prompt")
            expect = entry.get("expect")
            if not text:
                problems.append(f"{name}: an entry has no 'prompt'")
                continue
            if expect not in VALID_EXPECT:
                problems.append(
                    f"{name}: prompt {text!r} has expect={expect!r}; "
                    f"must be one of {VALID_EXPECT}"
                )
                continue
            if text in seen:
                problems.append(f"{name}: duplicate prompt {text!r}")
                continue
            seen.add(text)
            counts[expect] += 1

        for expect in VALID_EXPECT:
            if counts[expect] < MIN_PER_CLASS:
                problems.append(
                    f"{name}: only {counts[expect]} {expect!r} prompts; "
                    f"at least {MIN_PER_CLASS} are required. A description tested "
                    f"on fewer cases has not been tested."
                )

    for entry in spec.get("regressions", []):
        if not entry.get("prompt") or not entry.get("expect_observable"):
            problems.append(
                "regressions: each entry needs both 'prompt' and 'expect_observable'"
            )

    return problems


def emit_table(spec):
    out = []
    for skill in spec["skills"]:
        out.append(f"## {skill['name']}")
        out.append("")
        out.append("| # | Prompt | Expected | Result |")
        out.append("|---|--------|----------|--------|")
        for n, entry in enumerate(skill["prompts"], start=1):
            prompt = entry["prompt"].replace("|", "\\|")
            out.append(f"| {n} | \"{prompt}\" | {entry['expect']} | |")
        out.append("")

    regressions = spec.get("regressions", [])
    if regressions:
        out.append("## Behavioral regressions")
        out.append("")
        out.append("| # | Prompt | Expected observable | Before | After |")
        out.append("|---|--------|---------------------|--------|-------|")
        for n, entry in enumerate(regressions, start=1):
            prompt = entry["prompt"].replace("|", "\\|")
            expected = entry["expect_observable"].replace("|", "\\|")
            out.append(f"| {n} | \"{prompt}\" | {expected} | | |")
        out.append("")

    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--validate", metavar="SPEC")
    group.add_argument("--emit-table", metavar="SPEC")
    args = parser.parse_args()

    path = args.validate or args.emit_table
    spec = load(path)

    problems = validate(spec, path)
    if problems:
        print("Spec is not valid:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        sys.exit(2)

    if args.validate:
        print(f"OK: {path} is a valid eval spec")
        return

    print(emit_table(spec))


if __name__ == "__main__":
    main()
```

Note: `sys.exit(str)` prints to stderr and exits 1; the explicit `sys.exit(2)` in
`main()` covers the validation path. Test 4 asserts exit **2** for a missing file,
so `load()` must exit 2 as well — change both `sys.exit(f"ERROR: ...")` calls to:

```python
        print(f"ERROR: spec not found: {path}", file=sys.stderr)
        sys.exit(2)
```

and likewise for the `JSONDecodeError` branch. Make that change before running the
test.

```bash
chmod +x skills/harness/harness-eval/scripts/eval_run.py
```

- [ ] **Step 5: Run the test to verify it passes (GREEN)**

```bash
bash tests/harness/eval_run.py.test
```

Expected: `PASS=10 FAIL=0`.

- [ ] **Step 6: Write SKILL.md**

`skills/harness/harness-eval/SKILL.md`:

```markdown
---
name: harness-eval
description: >-
  Test whether a skill actually fires when it should — and stays quiet when it
  shouldn't — and whether a harness change measurably improved agent behavior. Use
  when a skill's triggering is in question ("does this skill trigger?", "test my
  skill's description", "the skill fires on everything", "the skill never fires",
  "why didn't Claude use the skill?"), before a skill is shared with the team, and
  when a CLAUDE.md or harness edit needs proof it helped ("did that change actually
  work?", "regression-test the harness"). Produces evidence tables, never an
  assertion.
---

# Harness Eval

A skill that never fires is dead code that looks alive. A skill that fires on
everything is worse — it is noise with a good reputation. Both failures are
invisible until someone measures them, and almost nobody does.

## Core contract

1. **Evidence, never assertion.** Output is a table of prompts, expectations and
   observed results. "The description looks good" is not a result.
2. **The description is the whole test surface.** At trigger time Claude sees the
   `description:` frontmatter and *nothing else*. A "do NOT use this for X"
   carve-out in the SKILL.md body cannot prevent a false trigger, because the body
   is invisible when the decision is made. Judge prompts against the description
   alone. This is the single most common mistake in skill testing.
3. **The spec lives in git.** An eval that lives in a chat log is not an eval; it
   is a memory. Prompts and expectations go in `.claude/eval_spec.json`, versioned
   alongside the skill they test.

## Mode 1 — Trigger validation

### 1. Write or locate the spec

Start from `assets/eval_spec.example.json`. Per skill: **at least 5 trigger and 5
no-trigger prompts.**

Choosing prompts is where the value is. Weak specs test the obvious cases and pass
trivially. A useful spec includes:

- **Verbatim phrasings** the description itself quotes — these must pass, and if
  they do not, the description is broken outright.
- **Natural phrasings the description does *not* quote** — real users do not read
  your frontmatter. This is where under-triggering hides.
- **Prompts belonging to a neighboring skill.** Cross-triggering is the failure
  mode that actually bites in a repo with several skills. If two skills sit near
  each other, each one's spec must include the other's territory as `no-trigger`.
- **Adjacent-but-unrelated prompts** — same vocabulary, different intent. "Why did
  we choose Redis?" versus "scan Redis for CVEs" share a noun and nothing else.

Validate before running. The script rejects a spec that is too thin to prove
anything:

```bash
scripts/eval_run.py --validate .claude/eval_spec.json
```

### 2. Run each prompt in a fresh, blind subagent

Dispatch one subagent per prompt. Each is given the skill's `description:` text
and the prompt, and asked exactly one thing:

> Given ONLY this skill description and this user prompt, would this skill be
> invoked? Answer `trigger` or `no-trigger`, then one sentence of reasoning.
> Judge the description alone — you have no access to the skill body.

Fresh subagents matter. Asking yourself, in the context where you just *wrote* the
description, produces a graded exam marked by its own author. You know what you
meant; the router will not.

### 3. Tabulate

```bash
scripts/eval_run.py --emit-table .claude/eval_spec.json
```

Fill the `Result` column: `PASS` / `FAIL`, each with the one-line reasoning. Write
the table to `tests/<track>/trigger-validation.md`, or to the repo's equivalent.

### 4. Interpret

| Pattern | Diagnosis | Fix |
|---------|-----------|-----|
| Trigger prompts fail | Under-triggering. The description is abstract, or written in your vocabulary rather than the user's | Add concrete example phrasings **in the user's words** |
| No-trigger prompts fire | Over-triggering. A clause is too broad — usually one that opens with a category rather than an example | Anchor the clause with specific examples; narrow the category |
| A neighbor's prompts fire | Cross-triggering | Sharpen the boundary in *both* descriptions, then re-run *both* specs |
| Everything passes first try | Suspect the spec, not the skill | Your prompts are probably paraphrases of the description. Add prompts you expect to fail |

A description edit invalidates every previous result. Re-run the whole spec — not
just the row that failed.

## Mode 2 — Behavioral regression

Trigger validation proves a skill *fires*. It says nothing about whether the
harness *works*. For that: pin the behavior, change the harness, compare.

1. **Pin the observable.** In the spec's `regressions` array, each entry is a task
   prompt plus an `expect_observable` — something you can *see* in a transcript,
   not a vibe. "Runs the declared test command before claiming completion" is
   observable. "Writes better code" is not.
2. **Run before.** Dispatch each regression prompt to a fresh subagent against the
   current harness. Record what actually happened.
3. **Change the harness.** One change. Two changes at once and you learn nothing
   about either.
4. **Run after.** Same prompts, fresh subagents, same recording.
5. **Diff and report.** State plainly what improved, what regressed, and what did
   not move. **A change that moves nothing is a finding**, and a valuable one: it
   is how you learn that the paragraph you just added to CLAUDE.md is dead weight
   competing for attention with the rules that work.

## Honesty rules

- **Small N.** Ten prompts is not a benchmark. Say so. This is a smoke test that
  catches gross triggering failures, and it is worth doing precisely because the
  alternative is zero evidence — not because it is rigorous.
- **Non-determinism is real.** A prompt that fires four times in five is a finding,
  not a PASS. Record it as flaky and investigate the clause responsible.
- **Never mark a skill "validated".** Report the rows. The human reads the table
  and decides.
```

- [ ] **Step 7: Verify house rules and self-consistency**

The example spec must satisfy the skill's own stated 5/5 minimum — a skill that
ships an example violating its own rule is not a skill anyone will trust:

```bash
S=skills/harness/harness-eval/SKILL.md
echo "SKILL.md lines: $(wc -l < $S)  (must be < 500)"
python3 skills/harness/harness-eval/scripts/eval_run.py \
  --validate skills/harness/harness-eval/assets/eval_spec.example.json
```

Expected: under 500 lines; `OK: ... is a valid eval spec`.

- [ ] **Step 8: Record the evidence**

Append to `tests/harness/notes.md`:

```markdown
## 2026-07-14 — eval_run.py

**Step 2: RED** — script missing, `PASS=0` ✓

**Step 5: GREEN**

| # | Test | Result |
|---|------|--------|
| 1 | Shipped example spec validates | ✓ exit 0 |
| 2 | Under-5-prompts spec rejected, explains the minimum | ✓ exit 2 |
| 3 | Duplicate prompts rejected by name | ✓ exit 2 |
| 4 | Missing spec file → exit 2, no traceback | ✓ |
| 5 | `--emit-table` renders a markdown table with a blank Result column | ✓ |

**Summary**: eval_run.py does the deterministic half only — spec validation and
table rendering. It deliberately does NOT judge whether a skill fired; that is the
model's job via fresh subagents (SKILL.md Mode 1 step 2). A script that pretended
to judge would produce confident, wrong evidence.

Deviation from the design spec: the eval spec is **JSON, not YAML**. python3 stdlib
has `json` and not `yaml`; YAML would require PyYAML, and this repo adds no
dependencies.
```

- [ ] **Step 9: Commit**

```bash
git add skills/harness/harness-eval tests/harness/
git commit -m "feat(harness-eval): prove a skill fires, and that a change helped

Trigger validation (fresh blind subagents judge the description alone) plus
behavioral regression against a git-tracked eval spec. eval_run.py validates the
spec and renders the table; the firing judgement stays with the model."
```

---

### Task 11: Trigger-validate the four new skills

Eat the dog food: run `harness-eval`'s own method against the four skills this plan
just wrote. Descriptions are frozen after this task unless a row fails.

**Files:**
- Create: `tests/harness/trigger-validation.md`
- Create: `tests/harness/eval_spec.json`
- Modify (only if a row FAILs): the offending skill's `description:` frontmatter

**Interfaces:**
- Consumes: `eval_run.py` (Task 10); the four SKILL.md descriptions (Tasks 7–10).

- [ ] **Step 1: Write the eval spec for all four skills**

Create `tests/harness/eval_spec.json`. Per skill: 5 trigger + 5 no-trigger. The
no-trigger prompts **must** include the neighboring harness skills' territory and
the compliance skills' territory — cross-triggering across seven skills in one repo
is the realistic failure, and it is what this spec exists to catch.

```json
{
  "skills": [
    {
      "name": "harness-audit",
      "prompts": [
        {"prompt": "set up Claude Code for this repo", "expect": "trigger"},
        {"prompt": "is our Claude setup any good?", "expect": "trigger"},
        {"prompt": "what's missing from our .claude directory?", "expect": "trigger"},
        {"prompt": "onboard this project to agentic development", "expect": "trigger"},
        {"prompt": "audit our harness", "expect": "trigger"},
        {"prompt": "our CLAUDE.md is too long", "expect": "no-trigger"},
        {"prompt": "create an agent that reviews migrations", "expect": "no-trigger"},
        {"prompt": "does this skill trigger?", "expect": "no-trigger"},
        {"prompt": "prepare the release", "expect": "no-trigger"},
        {"prompt": "fix the failing invoice test", "expect": "no-trigger"}
      ]
    },
    {
      "name": "claude-md-authoring",
      "prompts": [
        {"prompt": "write a CLAUDE.md for this repo", "expect": "trigger"},
        {"prompt": "our CLAUDE.md is too long", "expect": "trigger"},
        {"prompt": "the agent keeps forgetting to run the tests", "expect": "trigger"},
        {"prompt": "why is Claude ignoring our conventions?", "expect": "trigger"},
        {"prompt": "add this rule to CLAUDE.md", "expect": "trigger"},
        {"prompt": "audit our harness", "expect": "no-trigger"},
        {"prompt": "should this be a skill or a command?", "expect": "no-trigger"},
        {"prompt": "test my skill's description", "expect": "no-trigger"},
        {"prompt": "why did we choose Redis for queues?", "expect": "no-trigger"},
        {"prompt": "update the README badges", "expect": "no-trigger"}
      ]
    },
    {
      "name": "subagent-authoring",
      "prompts": [
        {"prompt": "create an agent that reviews migrations", "expect": "trigger"},
        {"prompt": "should this be a skill or a command?", "expect": "trigger"},
        {"prompt": "I want a subagent for research", "expect": "trigger"},
        {"prompt": "make this run automatically every time", "expect": "trigger"},
        {"prompt": "add a /deploy command", "expect": "trigger"},
        {"prompt": "write a CLAUDE.md for this repo", "expect": "no-trigger"},
        {"prompt": "is our Claude setup any good?", "expect": "no-trigger"},
        {"prompt": "the skill fires on everything", "expect": "no-trigger"},
        {"prompt": "generate an SBOM for v2.1", "expect": "no-trigger"},
        {"prompt": "refactor UserController into a service class", "expect": "no-trigger"}
      ]
    },
    {
      "name": "harness-eval",
      "prompts": [
        {"prompt": "does this skill trigger?", "expect": "trigger"},
        {"prompt": "test my skill's description", "expect": "trigger"},
        {"prompt": "the skill fires on everything", "expect": "trigger"},
        {"prompt": "why didn't Claude use the skill?", "expect": "trigger"},
        {"prompt": "did that CLAUDE.md change actually work?", "expect": "trigger"},
        {"prompt": "write a CLAUDE.md for this repo", "expect": "no-trigger"},
        {"prompt": "create an agent that reviews migrations", "expect": "no-trigger"},
        {"prompt": "set up Claude Code for this repo", "expect": "no-trigger"},
        {"prompt": "are we CRA ready?", "expect": "no-trigger"},
        {"prompt": "write a migration for the orders table", "expect": "no-trigger"}
      ]
    }
  ]
}
```

- [ ] **Step 2: Validate the spec, then render the table**

```bash
python3 skills/harness/harness-eval/scripts/eval_run.py --validate tests/harness/eval_spec.json
python3 skills/harness/harness-eval/scripts/eval_run.py --emit-table tests/harness/eval_spec.json > /tmp/trigger-table.md
head -20 /tmp/trigger-table.md
```

Expected: `OK: ... is a valid eval spec`, then a four-section markdown table with
`Result` blank.

- [ ] **Step 3: Judge every row with fresh, blind subagents**

Follow `harness-eval` Mode 1 step 2 literally — this is the dog-food test of the
skill itself. For each of the 40 rows, dispatch a subagent with **only** the
skill's `description:` text and the prompt:

> Given ONLY this skill description and this user prompt, would this skill be
> invoked? Answer `trigger` or `no-trigger`, then one sentence of reasoning. You
> have no access to the skill body — judge the description alone.

Dispatch the 40 in parallel batches. Do **not** judge them yourself: you wrote the
descriptions, and you will mark your own homework generously.

- [ ] **Step 4: Write the results file**

Create `tests/harness/trigger-validation.md`, matching the format already used in
`tests/compliance/trigger-validation.md`:

```markdown
# Trigger validation — harness track

Method: each prompt judged against the skill's `description:` frontmatter only —
that is all the router sees at trigger time; the SKILL.md body is invisible.
Judged by fresh subagents with no access to the skill body and no knowledge of who
wrote it. Spec: [`eval_spec.json`](eval_spec.json). Date: 2026-07-14.

<!-- Paste the four filled tables from eval_run.py --emit-table here. -->

## Outcome

<!-- Rows passed / total. Any description edited, and why. Any cross-trigger risk
     that passed but only narrowly — say so plainly; a close call recorded is worth
     more than a clean-looking table. -->
```

Paste the filled tables. In **Outcome**, be honest: if a row failed, say which
description was edited and re-run *that skill's whole spec* (a description edit
invalidates every previous row for that skill, per the skill's own rule).

- [ ] **Step 5: Fix any failing description and re-run**

If any row FAILs, edit that skill's `description:` per `harness-eval`'s
interpretation table (Mode 1 step 4), then repeat Steps 3–4 **for that entire
skill**, not just the failing row. Record both passes in the Outcome section — the
first result and the fix are the interesting part of the evidence, not an
embarrassment to hide.

- [ ] **Step 6: Commit**

```bash
git add tests/harness/eval_spec.json tests/harness/trigger-validation.md skills/harness/
git commit -m "test(harness): trigger-validate the four harness skills

40 rows judged by fresh blind subagents against the descriptions alone. Includes
each skill's neighbors (and the compliance skills) as no-trigger cases, since
cross-triggering across seven skills is the realistic failure."
```

---

### Task 12: Harness track docs, and flip the README to shipped

**Files:**
- Create: `docs/harness/brief.md`
- Create: `docs/harness/rollout-note.md`
- Modify: `README.md` (harness table: planned → shipped)

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Write docs/harness/brief.md**

```markdown
# Harness Track — Brief

## Why this track exists

Oltrematica's AI-native pilot rests on a premise that nobody has been checking: that
the harness — the `CLAUDE.md`, skills, subagents, hooks and verification gates a
coding agent runs inside — is any good. Today that harness is folklore. It is
assembled once per repo by whoever set the repo up, never reviewed, never measured,
and it rots silently: a `CLAUDE.md` grows until the agent quietly stops obeying the
half of it that matters, a skill's description drifts until it fires on everything
or on nothing.

The compliance track exists because *compliance fails through friction, not
ignorance*. The harness track exists for the mirror reason: **the harness fails
through invisibility.** Nothing tells you it broke. The agent just gets worse, and
the team concludes the model got worse.

These four skills make the harness a maintained artifact: something you can audit,
author deliberately, and — the part nobody does — **test**.

## The skills

| Skill | Answers |
|-------|---------|
| [`harness-audit`](../../skills/harness/harness-audit/) | What scaffolding does this repo give an agent, and what is missing? |
| [`claude-md-authoring`](../../skills/harness/claude-md-authoring/) | Is this CLAUDE.md policy, or is it a skill in disguise? |
| [`subagent-authoring`](../../skills/harness/subagent-authoring/) | Should this be a skill, a subagent, a command, or a hook? |
| [`harness-eval`](../../skills/harness/harness-eval/) | Does this skill actually fire? Did that change actually help? |

`harness-audit` is the entry point; it diagnoses and hands each fix to the skill
that owns it.

## Dependency: Superpowers

These skills **assume the [Superpowers](https://github.com/obra/superpowers) plugin
is installed** and deliberately do not re-implement it. Superpowers owns *how to
work*: brainstorming, planning, TDD, systematic debugging, verification, code
review. This track owns *what the harness is made of* and *whether it works*.

Where a harness gap needs one of those workflows, our skills hand off by name
rather than duplicating. Forking them would buy independence and cost us permanent
drift.

## Non-goals

- **No hooks-authoring skill.** Claude Code's built-in `update-config` skill already
  owns `settings.json`. `subagent-authoring` decides *that* you need a hook and hands
  off; it does not hand-edit the file.
- **No MCP-authoring skill.** Out of scope for this track.
- **No skill-authoring skill.** `superpowers:writing-skills` covers it. Our house
  conventions live in [`docs/contributing-skills.md`](../contributing-skills.md).
- **No CI enforcement.** `harness-audit` reports; it does not block a merge. Whether
  it should eventually run in CI — as the compliance track is proposing for its own
  gate — is deferred until the track has run on a real repo.

## The shared contract

Same as the compliance track, for the same reason: **Claude drafts, humans approve**,
and every report is **evidence, never an assertion**. A harness audit that says
"looks good" is worth exactly as much as a compliance dossier that says "we're
compliant" — nothing, and worse than nothing if anyone believes it.
```

- [ ] **Step 2: Write docs/harness/rollout-note.md**

Model it on the compliance rollout note, which worked.

```markdown
# Rollout note: Harness Skills

## What shipped

Four Claude Code skills for working on the harness itself:

- `harness-audit` — inventories a repo's `.claude/` scaffolding and reports what is
  missing. **Start here.**
- `claude-md-authoring` — writes and repairs `CLAUDE.md`. Also the thing to reach for
  when the agent keeps ignoring an instruction.
- `subagent-authoring` — decides between a skill, a subagent, a command and a hook,
  then writes it.
- `harness-eval` — tests whether a skill actually fires, and whether a harness change
  actually helped.

Install:

```bash
git clone https://github.com/Oltrematica/oltrematica-skills.git /tmp/os
/tmp/os/scripts/install.sh harness-audit claude-md-authoring subagent-authoring harness-eval --to /path/to/repo
```

They assume the Superpowers plugin is installed. They do not replace it — they add
what it does not cover.

## What changes for you

**Run `harness-audit` once on your repo.** It takes a couple of minutes and produces
a `Proposed` report: seven surfaces, each marked present / gap / not applicable, with
the reason. It never says "looks good" — if a surface is fine, it says why it is fine.

Then fix what the report says is worth fixing. It will tell you which skill does each
fix. Do not fix everything; a harness with an unused hook in it is worse than one
without.

## Two things worth knowing

**If the agent keeps ignoring an instruction, the answer is almost never a stronger
instruction.** It is usually that your `CLAUDE.md` has grown long enough that rules
compete for attention, or that the rule needed to hold *every* time — in which case it
was never an instruction at all, it was a hook. `claude-md-authoring` walks the
diagnosis.

**A skill you did not test probably does not fire.** Or it fires on everything, which
is worse, because it looks like it is working. `harness-eval` runs your description
past fresh subagents that have never seen the skill body — the same thing the router
sees, and nothing more. It takes ten minutes and it is routinely humbling.

## The contract, unchanged

Claude drafts, humans approve. Nothing gets marked healthy, validated or done without
you. Evidence, never assertion — on the harness as on compliance.
```

- [ ] **Step 3: Flip the README harness table to shipped**

In `README.md`, remove the *"Planned — see the design spec"* line and link each skill
to its directory:

```markdown
## Harness track

| Skill | Purpose |
|-------|---------|
| [`harness-audit`](skills/harness/harness-audit/) | Inventories a repo's harness surfaces and reports present / gap / not applicable. Start here. |
| [`claude-md-authoring`](skills/harness/claude-md-authoring/) | Writes and repairs `CLAUDE.md` — policy, not routing. Diagnoses "the agent keeps ignoring X". |
| [`subagent-authoring`](skills/harness/subagent-authoring/) | Chooses between skill, subagent, command and hook — then authors it. |
| [`harness-eval`](skills/harness/harness-eval/) | Proves a skill fires when it should, and that a harness change actually helped. |

These skills assume the [Superpowers](https://github.com/obra/superpowers) plugin is
installed. They deliberately do not re-implement planning, TDD, debugging or code
review — Superpowers owns those. Background: [`docs/harness/brief.md`](docs/harness/brief.md).
```

- [ ] **Step 4: Full-repo verification**

Everything, one pass:

```bash
# 1. Every relative markdown link in the repo resolves (excluding scratch dirs)
python3 - <<'PY'
import os, re, sys
bad = []
skip = {'.git', '.superpowers', 'node_modules'}
for root, dirs, files in os.walk('.'):
    dirs[:] = [d for d in dirs if d not in skip]
    for f in files:
        if not f.endswith('.md'):
            continue
        p = os.path.join(root, f)
        for link in re.findall(r']\((\.\.?/[^)#]+)', open(p, errors='ignore').read()):
            target = os.path.normpath(os.path.join(root, link))
            if not os.path.exists(target):
                bad.append(f"{p} -> {link}")
print("\n".join(bad) if bad else "OK: every relative link resolves")
sys.exit(1 if bad else 0)
PY

# 2. Every SKILL.md is under the 500-line budget
for s in skills/*/*/SKILL.md; do
  printf "%-55s %s\n" "$s" "$(wc -l < "$s")"
done

# 3. Nothing defaults to an approved status
grep -rniE '\*\*status:\*\* *(accepted|compliant|passing|validated)' skills/ && \
  echo "FAIL: an artifact defaults to approved" || \
  echo "PASS: nothing defaults to approved"

# 4. All three script contract tests still pass
bash tests/install.sh.test          | tail -1
bash tests/harness/inventory.sh.test | tail -1
bash tests/harness/eval_run.py.test  | tail -1

# 5. The installer works for the harness skills too
TARGET=$(mktemp -d)
./scripts/install.sh harness-audit claude-md-authoring subagent-authoring harness-eval --to "$TARGET"
find "$TARGET/.claude/skills" -name SKILL.md | sort
rm -rf "$TARGET"
```

Expected: link check `OK`; all six SKILL.md files under 500 lines; status check
`PASS`; all three contract tests `FAIL=0`; four `SKILL.md` paths installed flat.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/harness/
git commit -m "docs(harness): add the track brief and rollout note

README's harness table flips from planned to shipped. The brief states the
premise plainly: the compliance track exists because compliance fails through
friction; this one exists because the harness fails through invisibility."
```

---

## Self-Review

**Spec coverage** — every section of the design doc maps to a task:

| Spec section | Task |
|---|---|
| §4 Repo restructure | 1, 2 |
| §4 Install paths don't break | 3 (install.sh), 4 (docs), verified in 1 Step 5 |
| §4 Rename | 5 |
| §5.1 `harness-audit` | 7 |
| §5.2 `claude-md-authoring` | 8 |
| §5.3 `subagent-authoring` | 9 |
| §5.4 `harness-eval` | 10 |
| §6 README / brief / contributing-skills / distribution | 4, 12 |
| §7 Testing (trigger validation + bad fixture) | 6, 11 |
| §8 Sequencing (2 PRs) | Phase 1 = Tasks 1–5; Phase 2 = Tasks 6–12 |

**Placeholder scan** — no TBDs. The only intentionally-blank items are the ones a
human or a live subagent run must fill: the `Result` column in Task 11's table, the
actual line count in Task 6 Step 6, and Task 5's GitHub rename, which needs admin
rights the agent does not have.

**Type consistency** — `inventory.sh`'s seven JSON keys are named identically in the
script (Task 7 Step 3), its contract test (Step 1) and the SKILL.md workflow (Step 6).
`eval_run.py`'s two flags (`--validate`, `--emit-table`) and the spec schema are
identical across the script, its test, the example spec, and both SKILL.md references
(Tasks 10, 11). `install.sh`'s signature (`<skill-name>... --to <target>`) is identical
in the script, its test, the README, `distribution.md`, and both rollout notes.

**One correction found and fixed during review:** Task 10's `load()` originally used
`sys.exit(str)`, which exits **1**, while its own contract test asserts exit **2** for
a missing spec file. Step 4 now calls this out explicitly and gives the corrected code.
