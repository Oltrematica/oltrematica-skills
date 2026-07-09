# Oltrematica Compliance Skills Repo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate the `adr-management` skill and build the full Compliance Skills Program (brief Phases 1–3) in the `oltrematica-compliance-skills` repo: `cra-evidence` skill (W1–W5), templates, references, fixtures, tests, and distribution/CI docs.

**Architecture:** A plain skills repo (`skills/`, `docs/`, `tests/`). Each skill is a self-contained directory (SKILL.md + scripts + assets + references) with all script paths relative to the skill directory so a copy into any repo's `.claude/skills/` works unchanged. Generated evidence always lands in the *target* repo under `compliance/`. Deterministic operations live in scripts; judgment (triage, gap analysis, drafting) stays in SKILL.md instructions.

**Tech Stack:** bash (POSIX-leaning), Python 3 stdlib only, syft (SBOM), grype (scanner, primary) / osv-scanner (fallback), axe-core via `npx @axe-core/cli`, git.

## Global Constraints

- Repo root: `/Users/andreamargiovanni/dev/skills/oltrematica-compliance-skills` (existing git repo, branch `main`, remote `Oltrematica/oltrematica-compliance-skills`). All paths below are relative to this root unless absolute.
- Source for migration: `/Users/andreamargiovanni/dev/skills/adr-management-skill` (read-only — NEVER modify this directory; it is a separate git repo).
- All content in English. Commit convention: `type(scope): description`, imperative, ≤72 chars subject.
- No new project dependencies. Scripts: bash or Python 3 stdlib only. External tools (syft, grype, node/npx) are runtime tools the scripts check for — never assumed.
- Every script MUST: (1) check tool presence first and exit non-zero with an actionable install hint when missing — never a stack trace; (2) print its primary output path(s) on stdout as the last line so workflows can chain them.
- Core contract: no template, example, or generated artifact may carry status `Accepted`, `Compliant`, or `Final` — default status is always `Proposed` / `Draft`.
- `cra-evidence/SKILL.md` must stay under 500 lines.
- Commit after every task. Do not push unless asked.
- Test evidence goes in `tests/notes.md` (append a dated section per task that runs tests). Generated scan output under `tests/fixtures/*/compliance/` is gitignored, never committed.
- The spec is at `docs/superpowers/specs/2026-07-09-compliance-skills-repo-design.md` — consult it if a detail here seems ambiguous.

---

### Task 1: Repo foundation (LICENSE, README, program brief)

**Files:**
- Create: `LICENSE`
- Create: `README.md` (overwrite the one-line stub)
- Create: `docs/development-brief.md`
- Create: `.gitignore`

**Interfaces:**
- Produces: repo skeleton and the program brief that later docs tasks reference by path `docs/development-brief.md`.

- [ ] **Step 1: Copy the proprietary license from the adr repo**

```bash
cp /Users/andreamargiovanni/dev/skills/adr-management-skill/LICENSE \
   /Users/andreamargiovanni/dev/skills/oltrematica-compliance-skills/LICENSE
```

- [ ] **Step 2: Write `.gitignore`**

```gitignore
.DS_Store
tests/fixtures/*/compliance/
node_modules/
```

- [ ] **Step 3: Write `README.md`**

```markdown
# Oltrematica Compliance Skills

Claude Code skills that produce and maintain compliance evidence (CRA, SBOM,
EAA) and decision records (ADR) across Oltrematica repositories.

**Core contract for every skill here: Claude drafts, humans approve.** No
artifact is ever marked Accepted/Compliant by Claude autonomously.

## Skills

| Skill | Purpose |
|-------|---------|
| [`skills/adr-management`](skills/adr-management/) | Drafts Architecture Decision Records proactively whenever a significant decision is made; human reviews and approves. |
| [`skills/cra-evidence`](skills/cra-evidence/) | Generates the CRA evidence package: SBOM (CycloneDX), SBOM release diff, vulnerability scan + triage drafts, Annex I gap report, EAA/WCAG accessibility module. |

## Install (per repo)

Copy the skill directory into the target repo:

```bash
cp -R skills/cra-evidence /path/to/repo/.claude/skills/cra-evidence
cp -R skills/adr-management /path/to/repo/.claude/skills/adr-management
```

Full options (submodule, personal scope, future plugin) in
[`docs/distribution.md`](docs/distribution.md).

## Repo map

- `skills/` — the distributable skills
- `docs/` — program brief, distribution guide, CI gate proposal, rollout note
- `tests/` — fixture repos and test notes (living documentation)

## Program context

Driven by the Oltrematica Compliance Skills Program
([`docs/development-brief.md`](docs/development-brief.md)). Regulatory
deadlines: CRA vulnerability-reporting obligations from **2026-09-11**; full
CRA obligations from **2027-12-11**; EAA already in force since 2025-06-28.

## License

Proprietary — Copyright © 2026 Oltrematica. All rights reserved. See
[LICENSE](LICENSE).
```

- [ ] **Step 4: Write `docs/development-brief.md`** — the program brief, verbatim record. Content:

````markdown
# Development Brief — Oltrematica Compliance Skills Program

**Owner:** Andrea Margiovanni (Head of Tech)
**Audience:** Claude Code agents (implementation) + Mircha/Alex (review)
**Version:** 1.0 — 2026-07-09
**Related work:** `adr-management` skill (already in pilot; treat as reference implementation and integration point)

> Archived program record. Decisions taken during implementation (scope, OQ
> resolutions, layout deviation) are in
> `docs/superpowers/specs/2026-07-09-compliance-skills-repo-design.md`.

---

## 1. Problem statement

Oltrematica must produce and maintain compliance evidence (CRA, SBOM, EAA, GDPR-adjacent) across a portfolio of ~190 repos for itself and its clients. Compliance fails through friction, not ignorance: nobody regenerates an SBOM, triages CVEs, or updates the technical file mid-sprint. The `adr-management` pilot validated the pattern that fixes this: **Claude drafts proactively, humans only review.** This program extends that pattern to compliance evidence.

Regulatory clock: CRA vulnerability-reporting obligations apply from **September 11, 2026** (~2 months away); full CRA obligations from **December 11, 2027**; EAA is **already in force** (June 28, 2025). Internal milestone: board presentation on the AI-native pilot on **July 15, 2026** — Phase 1 should be demoable by then.

## 2. Goals

1. Any repo can produce a current, review-ready CRA evidence dossier with one invocation and zero manual assembly.
2. Every tagged release automatically gets an SBOM, an SBOM diff vs. the previous release, and a vulnerability triage draft.
3. Compliance-relevant decisions leave a paper trail by feeding the existing ADR workflow.
4. Skills are distributable per-repo via git (`.claude/skills/`), converging later on an internal plugin.

## 3. Non-goals

- **No DPIA/GDPR skill in this phase.** Requires organizational inputs that don't live in the repo. Parking lot.
- **No AI Act skill in this phase.** Only relevant to a subset of projects. Parking lot.
- **No legal advice generation.** Output is evidence and gap analysis; legal interpretation stays with counsel.
- **No SaaS/platform product.** These are internal skills; productization for clients is a separate initiative.
- **No CI enforcement in Phase 1.** The skill orchestrates and interprets; the blocking CI gate is Phase 3.

## 4. Architecture principles (binding for all deliverables)

1. **One skill = one capability with a recognizable trigger.** No monolithic "compliance" skill. If a skill body needs "when instead it's about X, do something entirely different", split it.
2. **Progressive disclosure.** SKILL.md body stays lean (<500 lines); anything longer goes to `references/` files loaded on demand; deterministic operations go to `scripts/`.
3. **Core contract (inherited from adr-management):** Claude drafts, humans approve. No artifact is marked final/accepted/compliant by Claude autonomously.
4. **CLAUDE.md is policy, not routing.** Skills self-trigger via description. Per-repo CLAUDE.md declares *when things are mandatory* for that repo (scope, exceptions, cadence) — never re-explains *how*.
5. **Language:** all skill content, templates, and generated dossiers in English (team convention). Client-facing exports may be localized later.
6. **Portability:** scripts in bash (POSIX-leaning) or Python stdlib; assume Linux/macOS dev environments and GitHub-hosted repos. Pin or version-check external tools (syft, grype/osv-scanner, axe-core); degrade gracefully with a clear message when a tool is missing rather than failing silently.

## 5. Deliverable 1 — `cra-evidence` skill (P0)

A Claude Code skill that generates and maintains the CRA evidence package for any repo.

### Structure

```
cra-evidence/
├── SKILL.md
├── scripts/
│   ├── gen_sbom.sh          # syft → CycloneDX JSON, stable output path
│   ├── diff_sbom.py         # component-level diff between two CycloneDX files
│   ├── scan_vulns.sh        # grype and/or osv-scanner against the SBOM
│   └── a11y_scan.sh         # axe-core against configured routes (frontend repos)
├── assets/
│   ├── dossier_template.md      # COMPLIANCE.md / per-release dossier skeleton
│   ├── vuln_record_template.md  # single-CVE triage record (registry entry + ENISA-notification draft fields)
│   └── claude_md_snippet.md     # the compliance policy block to paste into a repo's CLAUDE.md
└── references/
    ├── cra_annex1_checklist.md  # Annex I essential requirements as checkable items
    ├── triage_guidance.md       # exploitability assessment heuristics, severity mapping
    └── eaa_wcag_checklist.md    # WCAG 2.1 AA subset for automated + manual checks
```

### Workflows the SKILL.md must define

**W1 — Initialize.** Detect stack (composer.lock, package-lock, go.mod, requirements/poetry, Dockerfiles); create `compliance/` directory with dossier skeleton; propose the CLAUDE.md policy block; register the repo's product scope (CRA class, EAA applicability) as questions for the human — never assume scope.

**W2 — Release evidence.** On request or when a release/tag is being prepared: generate SBOM → diff vs. previous release SBOM ("what entered/left the supply chain") → vulnerability scan → draft triage per finding (exploitable in context? mitigated? accepted?) → update dossier → present summary for review. Triage drafts are always `Proposed`.

**W3 — Gap report.** Walk `cra_annex1_checklist.md` against the repo; output three-state result per item: *conformant* (with pointer to evidence), *gap* (with suggested remediation), *not applicable* (with stated rationale). Never output a bare "compliant".

**W4 — EAA module (frontend repos only).** Run axe-core against routes listed in the repo's CLAUDE.md policy block; merge results into the same dossier; flag items that require manual verification (automated a11y coverage is partial — say so explicitly in output).

**W5 — ADR handoff.** Any triage decision with architectural or risk-acceptance weight (e.g. "accept CVE-X as non-exploitable", "pin dependency Y") triggers a proposed ADR via the `adr-management` skill conventions (same directory detection, same numbering). Do not duplicate ADR logic — reference it.

### Acceptance criteria (P0)

- [ ] On a Laravel repo and on a Node repo, W2 produces: CycloneDX SBOM, human-readable diff, vulnerability list with triage drafts, updated dossier — in one invocation.
- [ ] SBOM diff correctly identifies added/removed/version-changed components between two releases.
- [ ] Gap report covers 100% of checklist items with one of the three states; no item silently skipped.
- [ ] Missing external tool (e.g. syft not installed) produces an actionable message with install hint, not a stack trace.
- [ ] No artifact is ever labeled "Accepted"/"Compliant" without a human step; templates carry `Proposed` status by default.
- [ ] Dossier is readable by a non-developer (test: would external counsel understand it without opening a terminal?).
- [ ] Skill triggers from natural phrasing ("prepare the release", "are we CRA ready?", "check our dependencies") — validate description against at least 5 trigger and 5 non-trigger prompts.

### Annex I checklist source

Draft `cra_annex1_checklist.md` from CRA Annex I Part I (product security requirements) and Part II (vulnerability handling requirements), phrased as verifiable repo-level checks where possible, with a "requires organizational evidence" tag where the repo alone cannot prove it. Flag the draft for review by Andrea + external counsel before it is treated as authoritative. **Open question OQ-1 below.**

## 6. Deliverable 2 — CLAUDE.md compliance policy template (P0)

A short, copy-pasteable block (in `assets/claude_md_snippet.md`) declaring per-repo policy:

```markdown
## Compliance policy (this repo)
- CRA scope: [in scope / out of scope] — class: [default / important I / important II]
- Evidence dossier: regenerate on every tagged release (cra-evidence W2)
- EAA scope: [yes: routes listed below / no]
  - a11y audit routes: [/, /login, ...]
- Compliance-relevant decisions always produce an ADR (docs/adr/)
- Exceptions: [e.g. legacy module /import excluded from scan until TICKET-ID]
```

Constraint: ≤ 15 lines. It states *when* and *what scope*; the skill owns *how*.

## 7. Deliverable 3 — Distribution: repo-level skills + plugin skeleton (P1)

1. Prepare `adr-management` and `cra-evidence` for in-repo distribution under `.claude/skills/` (verify relative script paths survive the move; document install in each skill's README section).
2. Scaffold an internal plugin repository (`oltrematica-skills`) with marketplace manifest, containing both skills, so team-wide updates happen in one place. Do not publish; skeleton + working local install instructions are sufficient for this phase.
3. Migration note for the team: personal `~/.claude/skills/` = pilot; `.claude/skills/` in repo = project standard; plugin = company standard.

## 8. Phasing and timeline

| Phase | Content | Target |
|-------|---------|--------|
| 1 (P0) | `cra-evidence` W1+W2+W3, dossier + templates, CLAUDE.md snippet; demo on one active repo | **July 14** (demoable for July 15 board) |
| 2 (P0) | W4 EAA module, W5 ADR handoff, triage guidance reference, trigger validation | End of July |
| 3 (P1) | Plugin skeleton, in-repo distribution of both skills, CI gate design proposal (GitHub Actions: SBOM on release, fail on critical CVE) | Aligned with CRA reporting readiness, well before **Sept 11** |

Phase 1 scope is deliberately tight; anything discovered during build that isn't listed goes to the parking lot, not into scope.

## 9. Testing requirements

- Test each script standalone on fixture repos (minimal Laravel, minimal Node, one polyglot) before wiring into SKILL.md.
- Include at least one fixture with a known-vulnerable pinned dependency to verify scan + triage draft end-to-end.
- Trigger testing per acceptance criteria (5 positive / 5 negative prompts per skill).
- Keep fixtures and test notes in the plugin repo under `tests/` — they double as living documentation.

## 10. Open questions

- **OQ-1 (blocking, Andrea + counsel):** Is there an existing internal Annex I checklist to use as `references/` source, or do agents draft from the regulation text as baseline? → **Resolved 2026-07-09: draft from regulation text, DRAFT banner pending counsel review.**
- **OQ-2 (blocking, Andrea):** Which repo is the Phase 1 demo target? Needs high activity and a plausible upcoming release. → **Still open.**
- **OQ-3 (non-blocking, Mircha/Alex):** grype vs. osv-scanner as default — pick one as primary during Phase 1, keep the other as optional fallback; decide from fixture results. → **Resolved 2026-07-09: grype primary (free/Apache-2.0), osv-scanner fallback.**
- **OQ-4 (non-blocking):** Should the dossier export also produce a client-facing PDF/Word variant? Defer decision to after Phase 1 demo. → **Deferred.**

## 11. Definition of done (program level)

Both skills installable from git, Phase 1–2 acceptance criteria green, one real repo running the full W1→W5 loop with at least one human-approved dossier and one ADR generated via handoff, and a one-page rollout note for the team modeled on the adr-management pilot email.
````

- [ ] **Step 5: Verify and commit**

Run: `cd /Users/andreamargiovanni/dev/skills/oltrematica-compliance-skills && ls LICENSE README.md .gitignore docs/development-brief.md`
Expected: all four paths listed, no error.

```bash
git add LICENSE README.md .gitignore docs/development-brief.md
git commit -m "chore: add license, README, gitignore and program brief"
```

---

### Task 2: Migrate adr-management skill

**Files:**
- Create: `skills/adr-management/SKILL.md` (copy, unchanged)
- Create: `skills/adr-management/scripts/new_adr.sh` (copy, unchanged, executable)
- Create: `skills/adr-management/assets/template.md` (copy, unchanged)
- Create: `skills/adr-management/README.md` (copy, then edit install/license sections)

**Interfaces:**
- Consumes: source files in `/Users/andreamargiovanni/dev/skills/adr-management-skill/` (read-only).
- Produces: `skills/adr-management/` — referenced by cra-evidence W5 (Task 8) and `docs/distribution.md` (Task 9). The script contract other tasks rely on: `skills/adr-management/scripts/new_adr.sh "Title" [adr-dir]` prints the created ADR file path.

- [ ] **Step 1: Copy the skill, excluding repo-only files**

```bash
cd /Users/andreamargiovanni/dev/skills/oltrematica-compliance-skills
mkdir -p skills/adr-management
rsync -a --exclude .git --exclude .DS_Store --exclude LICENSE \
  /Users/andreamargiovanni/dev/skills/adr-management-skill/ skills/adr-management/
chmod +x skills/adr-management/scripts/new_adr.sh
```

- [ ] **Step 2: Update `skills/adr-management/README.md` — replace the Installation section**

Replace everything from `## Installation` up to (not including) `## How it behaves once installed` with:

```markdown
## Installation

This skill now lives in the
[`oltrematica-compliance-skills`](https://github.com/Oltrematica/oltrematica-compliance-skills)
repo. Install it in one of two scopes:

### Per project (shared with the team via git)

```bash
cp -R skills/adr-management /path/to/your-project/.claude/skills/adr-management
```

### For your user account (available in every project)

```bash
cp -R skills/adr-management ~/.claude/skills/adr-management
```

See [`docs/distribution.md`](../../docs/distribution.md) for submodule and
plugin options.

### Verify

Restart Claude Code (or start a new session) and run `/skills` —
`adr-management` should appear. No build step, no dependencies:
`new_adr.sh` only needs `bash`, `sed`, and `find` (present on macOS and Linux).
```

- [ ] **Step 3: Update the License section at the bottom of the same README**

Replace:

```markdown
Proprietary — Copyright © 2026 Oltrematica. All rights reserved. See [LICENSE](LICENSE).
```

with:

```markdown
Proprietary — Copyright © 2026 Oltrematica. All rights reserved. See the
repository [LICENSE](../../LICENSE).
```

- [ ] **Step 4: Smoke-test the script survives the move**

```bash
cd "$(mktemp -d)" && /Users/andreamargiovanni/dev/skills/oltrematica-compliance-skills/skills/adr-management/scripts/new_adr.sh "Test decision"
```

Expected: prints `docs/adr/0001-test-decision.md`; the file contains `# 0001. Test decision` and `**Status**: Proposed` (proves the template is resolved relative to the script, not the CWD). Remove the temp dir afterwards.

- [ ] **Step 5: Verify SKILL.md is byte-identical to the source, then commit**

Run: `diff /Users/andreamargiovanni/dev/skills/adr-management-skill/SKILL.md skills/adr-management/SKILL.md && echo IDENTICAL`
Expected: `IDENTICAL`

```bash
git add skills/adr-management
git commit -m "feat(adr-management): migrate skill from standalone repo"
```

---

### Task 3: Test fixtures

**Files:**
- Create: `tests/fixtures/node-minimal/package.json`
- Create: `tests/fixtures/node-minimal/package-lock.json`
- Create: `tests/fixtures/laravel-minimal/composer.json`
- Create: `tests/fixtures/laravel-minimal/composer.lock`
- Create: `tests/fixtures/polyglot/package.json`, `tests/fixtures/polyglot/package-lock.json`, `tests/fixtures/polyglot/composer.json`, `tests/fixtures/polyglot/composer.lock`, `tests/fixtures/polyglot/Dockerfile`
- Create: `tests/notes.md`

**Interfaces:**
- Produces: fixture paths used by every script task (4–7). Known-vulnerable pins: `lodash 4.17.15` (CVE-2020-8203, CVE-2021-23337, CVE-2020-28500) in node-minimal and polyglot; `guzzlehttp/guzzle 7.4.0` (CVE-2022-31042/31043/31090/31091) in laravel-minimal and polyglot.

- [ ] **Step 1: Write `tests/fixtures/node-minimal/package.json`**

```json
{
  "name": "node-minimal-fixture",
  "version": "1.0.0",
  "private": true,
  "description": "Fixture: minimal Node repo with a known-vulnerable pinned dependency (lodash 4.17.15)",
  "dependencies": {
    "lodash": "4.17.15"
  }
}
```

- [ ] **Step 2: Write `tests/fixtures/node-minimal/package-lock.json`**

```json
{
  "name": "node-minimal-fixture",
  "version": "1.0.0",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": {
      "name": "node-minimal-fixture",
      "version": "1.0.0",
      "dependencies": {
        "lodash": "4.17.15"
      }
    },
    "node_modules/lodash": {
      "version": "4.17.15",
      "resolved": "https://registry.npmjs.org/lodash/-/lodash-4.17.15.tgz",
      "integrity": "sha512-8xOcRHvCjnocdS5cpwXQXVzmmh5e5+saE2QGoeQmbKmRS6J3VQppPOIt0MnmE+4xlZoumy0GPG0D0MVIQbNA1A=="
    }
  }
}
```

- [ ] **Step 3: Write `tests/fixtures/laravel-minimal/composer.json`**

```json
{
  "name": "oltrematica/laravel-minimal-fixture",
  "description": "Fixture: minimal PHP/Laravel-style repo with a known-vulnerable pinned dependency (guzzle 7.4.0)",
  "type": "project",
  "require": {
    "php": "^8.4",
    "guzzlehttp/guzzle": "7.4.0"
  }
}
```

- [ ] **Step 4: Write `tests/fixtures/laravel-minimal/composer.lock`**

```json
{
  "_readme": [
    "Fixture lockfile — hand-written for scanner testing, not installable."
  ],
  "content-hash": "fixture0000000000000000000000000000000000",
  "packages": [
    {
      "name": "guzzlehttp/guzzle",
      "version": "7.4.0",
      "source": {
        "type": "git",
        "url": "https://github.com/guzzle/guzzle.git",
        "reference": "868b3571a039f0ebc11ac8f344f4080babe2cb94"
      },
      "type": "library",
      "license": ["MIT"],
      "description": "Guzzle is a PHP HTTP client library"
    }
  ],
  "packages-dev": [],
  "aliases": [],
  "minimum-stability": "stable",
  "stability-flags": {},
  "prefer-stable": true,
  "prefer-lowest": false,
  "platform": { "php": "^8.4" },
  "platform-dev": {},
  "plugin-api-version": "2.6.0"
}
```

- [ ] **Step 5: Create the polyglot fixture**

Copy both ecosystems' files (adjusting only the `name` fields to `polyglot-fixture` / `oltrematica/polyglot-fixture`):

```bash
cd /Users/andreamargiovanni/dev/skills/oltrematica-compliance-skills
mkdir -p tests/fixtures/polyglot
cp tests/fixtures/node-minimal/package.json tests/fixtures/node-minimal/package-lock.json tests/fixtures/polyglot/
cp tests/fixtures/laravel-minimal/composer.json tests/fixtures/laravel-minimal/composer.lock tests/fixtures/polyglot/
```

Then edit the `"name"` values in the copied `package.json` (→ `"polyglot-fixture"`), `package-lock.json` (both occurrences → `"polyglot-fixture"`), and `composer.json` (→ `"oltrematica/polyglot-fixture"`). Write `tests/fixtures/polyglot/Dockerfile`:

```dockerfile
# Fixture Dockerfile — exists so W1 stack detection sees a container build.
FROM php:8.4-fpm-alpine
WORKDIR /app
COPY . /app
CMD ["php-fpm"]
```

- [ ] **Step 6: Start `tests/notes.md`**

```markdown
# Test notes

Living documentation: evidence from standalone script tests against the
fixtures in `tests/fixtures/`. Append a dated section per test run.

## Fixtures

| Fixture | Ecosystems | Known-vulnerable pin |
|---------|------------|----------------------|
| `node-minimal` | npm (lockfileVersion 3) | lodash 4.17.15 — CVE-2020-8203, CVE-2021-23337, CVE-2020-28500 |
| `laravel-minimal` | composer | guzzlehttp/guzzle 7.4.0 — CVE-2022-31042/31043/31090/31091 |
| `polyglot` | npm + composer + Dockerfile | both of the above |

Lockfiles are hand-written (no installed `node_modules/` or `vendor/`) —
syft and grype read lockfiles directly. `compliance/` output generated inside
fixtures during tests is gitignored.
```

- [ ] **Step 7: Commit**

```bash
git add tests/
git commit -m "test: add lockfile-level fixtures with known-vulnerable pins"
```

---

### Task 4: `gen_sbom.sh`

**Files:**
- Create: `skills/cra-evidence/scripts/gen_sbom.sh` (executable)
- Modify: `tests/notes.md` (append evidence)

**Interfaces:**
- Produces: `gen_sbom.sh [repo-dir] [ref-label]` → writes `<repo-dir>/compliance/sbom/<ref-label>.cdx.json` (CycloneDX JSON), prints that path as the last stdout line. Missing syft → exit 127 with install hint. Tasks 5, 6, 8 consume this contract.

- [ ] **Step 1: Ensure the test tools are available**

Run: `command -v syft grype`
If either is missing, install them (`brew install syft grype` on this machine). These are local developer tools for testing the scripts, not project dependencies. If installation is not possible, STOP and report — Tasks 4–6 cannot be verified without them.

- [ ] **Step 2: Write the failing test (script doesn't exist yet)**

Run: `bash skills/cra-evidence/scripts/gen_sbom.sh tests/fixtures/node-minimal v1.0.0`
Expected: FAIL — `No such file or directory`.

- [ ] **Step 3: Write `skills/cra-evidence/scripts/gen_sbom.sh`**

```bash
#!/usr/bin/env bash
# gen_sbom.sh — generate a CycloneDX JSON SBOM for a repository using syft.
#
# Usage: gen_sbom.sh [repo-dir] [ref-label]
#   repo-dir   directory to scan (default: .)
#   ref-label  label for the output file, e.g. a tag (default: git describe,
#              falling back to "unversioned")
#
# Output: <repo-dir>/compliance/sbom/<ref-label>.cdx.json
# Prints the output path on stdout (last line) so callers can chain it.
set -euo pipefail

REPO_DIR="${1:-.}"
[ -d "$REPO_DIR" ] || { echo "ERROR: not a directory: $REPO_DIR" >&2; exit 2; }

REF="${2:-$(git -C "$REPO_DIR" describe --tags --always 2>/dev/null || echo unversioned)}"
SAFE_REF="${REF//\//-}"

if ! command -v syft >/dev/null 2>&1; then
  echo "ERROR: syft not found — required to generate the SBOM." >&2
  echo "Install: brew install syft   (or see https://github.com/anchore/syft#installation)" >&2
  exit 127
fi

OUT_DIR="$REPO_DIR/compliance/sbom"
mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/$SAFE_REF.cdx.json"

syft scan "dir:$REPO_DIR" -o "cyclonedx-json=$OUT_FILE" --quiet
echo "SBOM: $(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(len(d.get('components',[])))" "$OUT_FILE") components" >&2
echo "$OUT_FILE"
```

```bash
chmod +x skills/cra-evidence/scripts/gen_sbom.sh
```

- [ ] **Step 4: Run against fixtures — verify it passes**

Run: `bash skills/cra-evidence/scripts/gen_sbom.sh tests/fixtures/node-minimal v1.0.0`
Expected: last stdout line `tests/fixtures/node-minimal/compliance/sbom/v1.0.0.cdx.json`; file exists and `python3 -c "import json;print([c['name'] for c in json.load(open('tests/fixtures/node-minimal/compliance/sbom/v1.0.0.cdx.json'))['components']])"` includes `lodash`.

Run: `bash skills/cra-evidence/scripts/gen_sbom.sh tests/fixtures/laravel-minimal v1.0.0`
Expected: SBOM whose components include `guzzlehttp/guzzle`.

Run: `bash skills/cra-evidence/scripts/gen_sbom.sh tests/fixtures/polyglot v1.0.0`
Expected: SBOM containing BOTH `lodash` and `guzzlehttp/guzzle`.

- [ ] **Step 5: Test the missing-tool path**

Run: `env PATH=/usr/bin:/bin bash skills/cra-evidence/scripts/gen_sbom.sh tests/fixtures/node-minimal v1.0.0; echo "exit=$?"`
Expected: stderr contains `syft not found` and `brew install syft`; `exit=127`; no stack trace. (If syft happens to live in /usr/bin — unlikely — use `PATH=/nonexistent` plus explicit `bash` invocation instead.)

- [ ] **Step 6: Record evidence and commit**

Append to `tests/notes.md` a section `## 2026-07-09 — gen_sbom.sh` with: fixture → component count found, lodash/guzzle presence confirmed, missing-tool exit code and message. Then:

```bash
git add skills/cra-evidence/scripts/gen_sbom.sh tests/notes.md
git commit -m "feat(cra-evidence): add SBOM generation script (syft, CycloneDX)"
```

---

### Task 5: `diff_sbom.py`

**Files:**
- Create: `skills/cra-evidence/scripts/diff_sbom.py` (executable)
- Create: `tests/fixtures/sbom-diff/old.cdx.json`, `tests/fixtures/sbom-diff/new.cdx.json`
- Modify: `tests/notes.md`

**Interfaces:**
- Consumes: CycloneDX JSON files as produced by `gen_sbom.sh` (Task 4).
- Produces: `diff_sbom.py OLD.cdx.json NEW.cdx.json [--json]` → Markdown diff on stdout with `### Added` / `### Removed` / `### Version changed` sections (or a JSON object `{"added": [...], "removed": [...], "changed": [{"component","old","new"}]}` with `--json`). Exit 0 on success even when differences exist; exit 2 on usage error; exit 1 on unreadable/invalid input. Task 8 (SKILL.md W2) consumes the Markdown form.

- [ ] **Step 1: Create deterministic diff fixtures**

`tests/fixtures/sbom-diff/old.cdx.json`:

```json
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.5",
  "version": 1,
  "components": [
    { "type": "library", "name": "lodash", "version": "4.17.15", "purl": "pkg:npm/lodash@4.17.15" },
    { "type": "library", "name": "left-pad", "version": "1.3.0", "purl": "pkg:npm/left-pad@1.3.0" },
    { "type": "library", "group": "guzzlehttp", "name": "guzzle", "version": "7.4.0", "purl": "pkg:composer/guzzlehttp/guzzle@7.4.0" }
  ]
}
```

`tests/fixtures/sbom-diff/new.cdx.json`:

```json
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.5",
  "version": 1,
  "components": [
    { "type": "library", "name": "lodash", "version": "4.17.21", "purl": "pkg:npm/lodash@4.17.21" },
    { "type": "library", "name": "axios", "version": "1.7.0", "purl": "pkg:npm/axios@1.7.0" },
    { "type": "library", "group": "guzzlehttp", "name": "guzzle", "version": "7.4.0", "purl": "pkg:composer/guzzlehttp/guzzle@7.4.0" }
  ]
}
```

Expected diff: added `axios`; removed `left-pad`; changed `lodash 4.17.15 → 4.17.21`; `guzzlehttp/guzzle` unchanged (must NOT appear).

- [ ] **Step 2: Run the not-yet-existing script to verify failure**

Run: `python3 skills/cra-evidence/scripts/diff_sbom.py tests/fixtures/sbom-diff/old.cdx.json tests/fixtures/sbom-diff/new.cdx.json`
Expected: FAIL — `No such file or directory`.

- [ ] **Step 3: Write `skills/cra-evidence/scripts/diff_sbom.py`**

```python
#!/usr/bin/env python3
"""diff_sbom.py — component-level diff between two CycloneDX JSON SBOMs.

Usage: diff_sbom.py OLD.cdx.json NEW.cdx.json [--json]

Prints a Markdown diff (Added / Removed / Version changed) to stdout,
or a JSON object with --json. Components are keyed by "group/name"
(group omitted when absent). Exit codes: 0 ok, 1 unreadable input, 2 usage.
"""
import json
import sys


def load_components(path):
    try:
        with open(path, encoding="utf-8") as f:
            doc = json.load(f)
    except (OSError, json.JSONDecodeError, UnicodeDecodeError) as e:
        print(f"ERROR: cannot read SBOM {path}: {e}", file=sys.stderr)
        sys.exit(1)
    comps = {}
    for c in doc.get("components", []):
        name = c.get("name", "")
        group = c.get("group") or ""
        key = f"{group}/{name}" if group else name
        comps[key] = c.get("version", "")
    return comps


def main():
    as_json = "--json" in sys.argv[1:]
    args = [a for a in sys.argv[1:] if a != "--json"]
    if len(args) != 2:
        print("Usage: diff_sbom.py OLD.cdx.json NEW.cdx.json [--json]", file=sys.stderr)
        sys.exit(2)

    old, new = load_components(args[0]), load_components(args[1])
    added = sorted(k for k in new if k not in old)
    removed = sorted(k for k in old if k not in new)
    changed = sorted(k for k in new if k in old and new[k] != old[k])

    if as_json:
        print(json.dumps({
            "added": [{"component": k, "version": new[k]} for k in added],
            "removed": [{"component": k, "version": old[k]} for k in removed],
            "changed": [{"component": k, "old": old[k], "new": new[k]} for k in changed],
        }, indent=2))
        return

    print(f"## SBOM diff\n\n`{args[0]}` → `{args[1]}`\n")
    if not (added or removed or changed):
        print("No component changes between the two SBOMs.")
        return
    print(f"### Added ({len(added)})\n")
    for k in added:
        print(f"- `{k}` {new[k]}")
    print(f"\n### Removed ({len(removed)})\n")
    for k in removed:
        print(f"- `{k}` {old[k]}")
    print(f"\n### Version changed ({len(changed)})\n")
    for k in changed:
        print(f"- `{k}` {old[k]} → {new[k]}")


if __name__ == "__main__":
    main()
```

```bash
chmod +x skills/cra-evidence/scripts/diff_sbom.py
```

- [ ] **Step 4: Verify against the diff fixtures**

Run: `python3 skills/cra-evidence/scripts/diff_sbom.py tests/fixtures/sbom-diff/old.cdx.json tests/fixtures/sbom-diff/new.cdx.json`
Expected: `Added (1)` lists `axios`; `Removed (1)` lists `left-pad`; `Version changed (1)` lists `lodash 4.17.15 → 4.17.21`; `guzzlehttp/guzzle` absent from output.

Run: `python3 skills/cra-evidence/scripts/diff_sbom.py tests/fixtures/sbom-diff/old.cdx.json tests/fixtures/sbom-diff/new.cdx.json --json | python3 -m json.tool > /dev/null && echo VALID_JSON`
Expected: `VALID_JSON`

Run: `python3 skills/cra-evidence/scripts/diff_sbom.py tests/fixtures/sbom-diff/old.cdx.json tests/fixtures/sbom-diff/old.cdx.json`
Expected: `No component changes between the two SBOMs.`

Run: `python3 skills/cra-evidence/scripts/diff_sbom.py missing.json also-missing.json; echo "exit=$?"`
Expected: `ERROR: cannot read SBOM missing.json: ...` on stderr, `exit=1`, no traceback.

Also verify on real syft output (from Task 4): `python3 skills/cra-evidence/scripts/diff_sbom.py tests/fixtures/node-minimal/compliance/sbom/v1.0.0.cdx.json tests/fixtures/polyglot/compliance/sbom/v1.0.0.cdx.json`
Expected: `guzzlehttp/guzzle` (and possibly php platform components) under Added; no crash.

- [ ] **Step 5: Record evidence and commit**

Append results to `tests/notes.md` (`## 2026-07-09 — diff_sbom.py`). Then:

```bash
git add skills/cra-evidence/scripts/diff_sbom.py tests/fixtures/sbom-diff tests/notes.md
git commit -m "feat(cra-evidence): add CycloneDX component diff script"
```

---

### Task 6: `scan_vulns.sh`

**Files:**
- Create: `skills/cra-evidence/scripts/scan_vulns.sh` (executable)
- Modify: `tests/notes.md`

**Interfaces:**
- Consumes: SBOM path from `gen_sbom.sh` (Task 4).
- Produces: `scan_vulns.sh SBOM_FILE [out.json]` → JSON scan report written next to the SBOM by default (`<sbom-basename>.vulns.json`), scanner name on stderr, output path as last stdout line. grype primary; osv-scanner fallback; neither → exit 127 with install hints. Task 8 (W2 triage drafting) consumes the JSON report.

- [ ] **Step 1: Verify failure before implementation**

Run: `bash skills/cra-evidence/scripts/scan_vulns.sh tests/fixtures/node-minimal/compliance/sbom/v1.0.0.cdx.json`
Expected: FAIL — `No such file or directory`.

- [ ] **Step 2: Write `skills/cra-evidence/scripts/scan_vulns.sh`**

```bash
#!/usr/bin/env bash
# scan_vulns.sh — scan a CycloneDX SBOM for known vulnerabilities.
#
# Usage: scan_vulns.sh SBOM_FILE [output.json]
#   Uses grype when available (primary), osv-scanner as fallback.
#   Default output: alongside the SBOM, extension .vulns.json.
#
# Prints the output path on stdout (last line). The scanner used is
# reported on stderr. Exit: 0 on completed scan (even with findings),
# 2 on usage error, 127 when no scanner is installed.
set -euo pipefail

SBOM="${1:?Usage: scan_vulns.sh SBOM_FILE [output.json]}"
[ -f "$SBOM" ] || { echo "ERROR: SBOM file not found: $SBOM" >&2; exit 2; }
OUT="${2:-${SBOM%.cdx.json}.vulns.json}"

if command -v grype >/dev/null 2>&1; then
  grype "sbom:$SBOM" -o json --quiet > "$OUT"
  echo "scanner: grype $(grype version 2>/dev/null | awk '/^Version:/{print $2}')" >&2
elif command -v osv-scanner >/dev/null 2>&1; then
  # osv-scanner exits 1 when vulnerabilities are found — that is a completed
  # scan, not an error. Only propagate exits > 1.
  set +e
  osv-scanner --sbom="$SBOM" --format json > "$OUT"
  RC=$?
  set -e
  [ "$RC" -le 1 ] || { echo "ERROR: osv-scanner failed (exit $RC)" >&2; exit "$RC"; }
  echo "scanner: osv-scanner (fallback — grype not installed)" >&2
else
  echo "ERROR: no vulnerability scanner found (looked for: grype, osv-scanner)." >&2
  echo "Install the primary scanner: brew install grype   (https://github.com/anchore/grype#installation)" >&2
  echo "Or the fallback:            brew install osv-scanner (https://google.github.io/osv-scanner/)" >&2
  exit 127
fi

echo "$OUT"
```

```bash
chmod +x skills/cra-evidence/scripts/scan_vulns.sh
```

- [ ] **Step 3: Verify end-to-end on the vulnerable fixtures**

(Regenerate the SBOM first if `tests/fixtures/node-minimal/compliance/` was cleaned.)

Run: `bash skills/cra-evidence/scripts/scan_vulns.sh tests/fixtures/node-minimal/compliance/sbom/v1.0.0.cdx.json`
Expected: last line `tests/fixtures/node-minimal/compliance/sbom/v1.0.0.vulns.json`; `scanner: grype ...` on stderr.

Run: `python3 -c "import json;d=json.load(open('tests/fixtures/node-minimal/compliance/sbom/v1.0.0.vulns.json'));ids=sorted({m['vulnerability']['id'] for m in d['matches']});print(len(ids), ids[:10])"`
Expected: at least 3 findings; IDs include entries corresponding to CVE-2020-8203, CVE-2021-23337, CVE-2020-28500 (grype may report GHSA aliases — check the `relatedVulnerabilities` too; presence of ANY lodash finding is the pass bar, exact IDs are recorded as evidence).

Same for laravel-minimal: expected at least one `guzzlehttp/guzzle` finding (CVE-2022-31042/31043/31090/31091 family).

- [ ] **Step 4: Test missing-scanner path**

Run: `env PATH=/usr/bin:/bin bash skills/cra-evidence/scripts/scan_vulns.sh tests/fixtures/node-minimal/compliance/sbom/v1.0.0.cdx.json; echo "exit=$?"`
Expected: both install hints on stderr, `exit=127`.

- [ ] **Step 5: Record evidence (this closes brief acceptance criterion "known-vulnerable fixture end-to-end") and commit**

Append findings (scanner version, counts, IDs found per fixture) to `tests/notes.md`. Then:

```bash
git add skills/cra-evidence/scripts/scan_vulns.sh tests/notes.md
git commit -m "feat(cra-evidence): add vulnerability scan script (grype, osv fallback)"
```

---

### Task 7: `a11y_scan.sh`

**Files:**
- Create: `skills/cra-evidence/scripts/a11y_scan.sh` (executable)
- Modify: `tests/notes.md`

**Interfaces:**
- Produces: `a11y_scan.sh BASE_URL OUT_DIR ROUTE [ROUTE...]` → one `axe-<route-slug>.json` per route in OUT_DIR via `npx @axe-core/cli`; prints OUT_DIR as last stdout line. Missing npx → exit 127 + hint. A failed individual route logs a WARN and continues (partial results better than none). Task 8 (W4) consumes the JSON reports.

- [ ] **Step 1: Verify failure before implementation**

Run: `bash skills/cra-evidence/scripts/a11y_scan.sh http://localhost /tmp/a11y /`
Expected: FAIL — `No such file or directory`.

- [ ] **Step 2: Write `skills/cra-evidence/scripts/a11y_scan.sh`**

```bash
#!/usr/bin/env bash
# a11y_scan.sh — run axe-core (WCAG automated checks) against a list of routes.
#
# Usage: a11y_scan.sh BASE_URL OUT_DIR ROUTE [ROUTE...]
#   e.g.: a11y_scan.sh https://staging.example.com compliance/a11y / /login /contact
#
# Writes one axe-<route-slug>.json per route into OUT_DIR and prints OUT_DIR
# on stdout (last line). Requires Node (npx) and a Chrome/Chromium available
# to @axe-core/cli's webdriver. A route that fails to scan logs a WARN and
# does not abort the remaining routes.
#
# NOTE: automated checks cover only part of WCAG 2.1 AA — see
# references/eaa_wcag_checklist.md for the manual-verification items.
set -euo pipefail

BASE_URL="${1:?Usage: a11y_scan.sh BASE_URL OUT_DIR ROUTE [ROUTE...]}"
OUT_DIR="${2:?Usage: a11y_scan.sh BASE_URL OUT_DIR ROUTE [ROUTE...]}"
shift 2
[ "$#" -ge 1 ] || { echo "ERROR: at least one route required (e.g. /)" >&2; exit 2; }

if ! command -v npx >/dev/null 2>&1; then
  echo "ERROR: npx (Node.js) not found — required to run @axe-core/cli." >&2
  echo "Install Node.js: brew install node   (https://nodejs.org)" >&2
  exit 127
fi

mkdir -p "$OUT_DIR"
FAILED=0
for ROUTE in "$@"; do
  SLUG=$(printf '%s' "$ROUTE" | sed -E 's|[^a-zA-Z0-9]+|-|g; s/^-+//; s/-+$//')
  SLUG="${SLUG:-root}"
  if ! npx --yes @axe-core/cli "$BASE_URL$ROUTE" --save "$OUT_DIR/axe-$SLUG.json" >&2; then
    echo "WARN: axe scan failed for $ROUTE (browser/webdriver missing or page unreachable) — continuing" >&2
    FAILED=$((FAILED + 1))
  fi
done
[ "$FAILED" -eq "$#" ] && { echo "ERROR: all $# route scans failed." >&2; exit 1; }
echo "$OUT_DIR"
```

```bash
chmod +x skills/cra-evidence/scripts/a11y_scan.sh
```

- [ ] **Step 3: Verify argument validation and missing-tool paths**

Run: `bash skills/cra-evidence/scripts/a11y_scan.sh http://localhost /tmp/a11y-test; echo "exit=$?"`
Expected: `ERROR: at least one route required` on stderr, `exit=2`.

Run: `env PATH=/usr/bin:/bin bash skills/cra-evidence/scripts/a11y_scan.sh http://localhost /tmp/a11y-test /; echo "exit=$?"`
Expected: `npx (Node.js) not found` + install hint, `exit=127`.

- [ ] **Step 4: Live verification against a local static page (best effort)**

```bash
SCRATCH="$(mktemp -d)"
printf '<!doctype html><html><head><title>fixture</title></head><body><img src="x.png"><input type="text"></body></html>' > "$SCRATCH/index.html"
(cd "$SCRATCH" && python3 -m http.server 8931 &>/dev/null &) && sleep 1
bash skills/cra-evidence/scripts/a11y_scan.sh http://localhost:8931 "$SCRATCH/out" /
kill %1 2>/dev/null || true
```

Expected: `axe-root.json` in `$SCRATCH/out` reporting violations (missing alt, missing label, missing lang). If Chrome/chromedriver is unavailable on this machine, the WARN + `all 1 route scans failed` path is the expected outcome — record WHICH outcome occurred in the notes; the missing-browser degradation message is itself a pass for the graceful-degradation criterion.

- [ ] **Step 5: Record evidence and commit**

```bash
git add skills/cra-evidence/scripts/a11y_scan.sh tests/notes.md
git commit -m "feat(cra-evidence): add axe-core accessibility scan script"
```

---

### Task 8: cra-evidence assets (dossier, vuln record, CLAUDE.md snippet)

**Files:**
- Create: `skills/cra-evidence/assets/dossier_template.md`
- Create: `skills/cra-evidence/assets/vuln_record_template.md`
- Create: `skills/cra-evidence/assets/claude_md_snippet.md`

**Interfaces:**
- Produces: templates instantiated by W1/W2 (Task 11 references them by relative path `assets/<name>.md`). Placeholders use `[square brackets]`; statuses default `Draft`/`Proposed`.

- [ ] **Step 1: Write `skills/cra-evidence/assets/claude_md_snippet.md`** (brief §6, ≤15 lines of policy block)

```markdown
<!-- Paste the block below into the repo's CLAUDE.md. Policy only: it states
     WHEN and WHAT SCOPE; the cra-evidence skill owns HOW. -->

## Compliance policy (this repo)
- CRA scope: [in scope / out of scope] — class: [default / important I / important II]
- Evidence dossier: regenerate on every tagged release (cra-evidence W2)
- EAA scope: [yes: routes listed below / no]
  - a11y audit routes: [/, /login, ...]
- Compliance-relevant decisions always produce an ADR (docs/adr/)
- Exceptions: [e.g. legacy module /import excluded from scan until TICKET-ID]
```

- [ ] **Step 2: Write `skills/cra-evidence/assets/dossier_template.md`**

The dossier must be readable by a non-developer (external counsel). Content:

```markdown
# Compliance Evidence Dossier — [Product name]

**Repository:** [org/repo]
**Status:** Draft — pending human review
**Last updated:** [YYYY-MM-DD] by Claude (drafter) / [name] (reviewer)

> This dossier is assembled by the `cra-evidence` skill. Claude drafts;
> humans review and approve. Nothing in this file is a conformity claim
> until a named human reviewer has approved it.

## 1. Product identification

- **Product:** [name and one-line description in plain language]
- **CRA scope:** [in scope / out of scope] — **class:** [default / important I / important II]
- **EAA scope:** [yes — routes listed in CLAUDE.md / no]
- **Scope rationale / decided by:** [who confirmed the scope, date]

## 2. Release evidence log

One row per tagged release. Artifacts live under `compliance/`.

| Release | Date | SBOM | Supply-chain diff | Vulnerabilities (open / triaged) | Reviewer |
|---------|------|------|-------------------|----------------------------------|----------|
| [v0.0.0] | [date] | [sbom/v0.0.0.cdx.json] | [summary or link] | [n / n] | [pending] |

## 3. Current vulnerability triage register

Detailed records: one file per finding under `compliance/vulns/`.

| ID | Component | Severity | Draft decision | Status | ADR |
|----|-----------|----------|----------------|--------|-----|
| [CVE-…] | [pkg vX] | [Critical/High/Medium/Low] | [fix / mitigate / accept] | Proposed | [—] |

## 4. CRA Annex I gap report

Latest run: [date]. Every checklist item carries exactly one state:
**conformant** (with evidence pointer), **gap** (with suggested remediation),
or **not applicable** (with rationale). Items the repository alone cannot
prove are tagged *requires organizational evidence*.

[gap report table inserted here by W3]

## 5. Accessibility (EAA) — frontend products only

Automated axe-core results per route, plus the manual-check list. Automated
scanning covers only part of WCAG 2.1 AA; items listed under "manual
verification required" are NOT covered until a human completes them.

[a11y results inserted here by W4]

## 6. Review log

| Date | Section | Reviewer | Outcome |
|------|---------|----------|---------|
| [date] | [e.g. release v1.2 evidence] | [name] | [approved / changes requested] |
```

- [ ] **Step 3: Write `skills/cra-evidence/assets/vuln_record_template.md`**

```markdown
# [CVE-YYYY-NNNNN / GHSA-xxxx] — [component]@[version]

**Status:** Proposed — pending human review
**Date drafted:** [YYYY-MM-DD]
**Drafter:** Claude (cra-evidence) | **Decider:** [name — REQUIRED before status changes]

## Finding

- **Component:** [name]@[version] ([direct / transitive] — [runtime / dev] dependency)
- **Source:** [grype / osv-scanner] scan of [sbom file], [date]
- **Severity:** [Critical / High / Medium / Low] (CVSS [score] — [vector if available])
- **Summary:** [one-paragraph plain-language description of the vulnerability]

## Exploitability in context

[Per references/triage_guidance.md — answer each:]

- **Is the vulnerable code path reachable in this product?** [yes / no / unknown — evidence]
- **Exposure:** [internet-facing / internal / build-time only]
- **Existing mitigations:** [authn in front, WAF, input validation, not user-reachable, …]

## Draft decision (Proposed)

- **Action:** [fix — upgrade to vX.Y.Z / mitigate — how / accept — why]
- **If accept or mitigate:** re-review by [date]; ADR: [docs/adr/NNNN-…] (required for accept — see W5)

## ENISA notification assessment (CRA Art. 14)

Reporting is required only for **actively exploited** vulnerabilities and
severe incidents; timelines run from awareness (early warning 24h, notification 72h).

- **Evidence of active exploitation:** [none known / describe]
- **Notification required:** [no / yes — DRAFT fields below]
- Draft fields (only if yes): product: […]; vulnerability: [CVE]; exploitation observed: […]; corrective measures available: […]

> Submission to ENISA/CSIRT is an organizational act performed by a human —
> never by this skill.
```

- [ ] **Step 4: Grep-check the core contract, then commit**

Run: `grep -rniE '\*\*status:\*\* *(accepted|compliant|final)' skills/cra-evidence/assets/ ; echo "exit=$?"`
Expected: no matches, `exit=1` (grep found nothing). All statuses are Draft/Proposed.

```bash
git add skills/cra-evidence/assets
git commit -m "feat(cra-evidence): add dossier, vuln record and CLAUDE.md policy templates"
```

---

### Task 9: Reference — CRA Annex I checklist

**Files:**
- Create: `skills/cra-evidence/references/cra_annex1_checklist.md`

**Interfaces:**
- Produces: the checklist W3 walks. Item ID scheme (`I.1`, `I.2a`–`I.2m`, `II.1`–`II.8`) is consumed by Task 11's W3 section and by gap report tables in dossiers. Tags: `[repo]` = verifiable from the repository; `[org]` = requires organizational evidence.

- [ ] **Step 1: Write `skills/cra-evidence/references/cra_annex1_checklist.md`**

The full content below is drafted from Regulation (EU) 2024/2847 Annex I. Keep the DRAFT banner verbatim.

```markdown
# CRA Annex I — Essential Requirements Checklist

> **DRAFT — pending review by Andrea Margiovanni + external counsel.
> Not authoritative until that review is recorded here.**
> Source: Regulation (EU) 2024/2847, Annex I (Parts I and II), rephrased as
> verifiable checks. `[repo]` = provable from the repository; `[org]` =
> requires organizational evidence the repo alone cannot provide.

Gap-report rule (W3): every item below receives exactly one state —
**conformant** (+ evidence pointer), **gap** (+ suggested remediation), or
**not applicable** (+ rationale). Never a bare "compliant"; never skipped.

## Part I — Security properties of the product

- **I.1** `[org]` The product is designed, developed and produced to ensure an
  appropriate level of cybersecurity based on a documented risk assessment.
  Check: does a cybersecurity risk assessment document exist for this product?
- **I.2a** `[repo]` Made available without known exploitable vulnerabilities.
  Check: latest scan (W2) shows no open Critical/High finding without an
  approved triage decision.
- **I.2b** `[repo]` Secure-by-default configuration, with the possibility to
  reset to the original state. Check: shipped defaults (config files, .env.example,
  installer) reviewed — no default credentials, debug off, least-privilege defaults.
- **I.2c** `[repo]` Vulnerabilities can be addressed through security updates;
  where applicable automatic updates by default with user opt-out and notification.
  Check: an update/release channel exists and is documented for users.
- **I.2d** `[repo]` Protection from unauthorised access: authentication,
  identity and access management; reporting of possible unauthorised access.
  Check: every endpoint handling non-public data enforces authn/authz
  (Laravel: Policies); auth failures are logged.
- **I.2e** `[repo]` Confidentiality of stored, transmitted or processed data —
  state-of-the-art encryption at rest and in transit. Check: TLS enforced;
  sensitive fields encrypted/hashed; no secrets committed.
- **I.2f** `[repo]` Integrity of data, commands, programs and configuration
  against unauthorised manipulation; corruption reporting. Check: signed
  releases/artifacts where applicable; input validation; migrations reversible.
- **I.2g** `[repo]` Data minimisation: process only data adequate, relevant and
  limited to what is necessary. Check: schema/models reviewed against purpose;
  no speculative personal-data collection.
- **I.2h** `[repo]` Availability of essential and basic functions, also after an
  incident, including DoS resilience and mitigation. Check: rate limiting,
  queue backpressure, documented recovery procedure.
- **I.2i** `[repo]` Minimise negative impact on the availability of services
  provided by other devices or networks. Check: outbound calls have timeouts,
  retries with backoff, circuit breaking where relevant.
- **I.2j** `[repo]` Limit attack surfaces, including external interfaces.
  Check: unused routes/services/ports removed; admin surfaces restricted;
  dependencies pruned.
- **I.2k** `[repo]` Reduce the impact of incidents using appropriate exploitation
  mitigation mechanisms. Check: framework protections enabled (CSRF, output
  encoding, prepared statements); container/user privileges minimal.
- **I.2l** `[repo]` Provide security-related information by recording and
  monitoring relevant internal activity (access to / modification of data,
  services, functions), with user opt-out where applicable. Check: audit
  logging for security-relevant events; log retention documented; no sensitive
  data in logs.
- **I.2m** `[repo]` Users can securely and easily remove all data and settings
  permanently, and securely transfer data to another product where applicable.
  Check: deletion/export capability exists for user data.

## Part II — Vulnerability handling requirements

- **II.1** `[repo]` Vulnerabilities and components are identified and
  documented, including an SBOM in a commonly used, machine-readable format
  covering at least top-level dependencies. Check: `compliance/sbom/*.cdx.json`
  exists for the current release.
- **II.2** `[org]` Vulnerabilities are addressed and remediated without delay,
  with security updates provided; where technically feasible, security updates
  are delivered separately from functionality updates. Check: triage register
  shows decisions and dates; release practice documented.
- **II.3** `[org]` Effective and regular tests and reviews of product security.
  Check: recurring scan cadence (per-release W2 at minimum) recorded in the
  dossier's release log.
- **II.4** `[org]` Once an update is available, information about fixed
  vulnerabilities is shared and publicly disclosed (description, affected
  versions, impact, severity, remediation), unless justified delay.
  Check: security advisory channel exists (e.g. GitHub Security Advisories).
- **II.5** `[org]` A coordinated vulnerability disclosure policy is in place
  and enforced. Check: SECURITY.md or equivalent published policy.
- **II.6** `[repo]` Measures to facilitate sharing of information about
  potential vulnerabilities, including a contact address for reporting.
  Check: SECURITY.md contains a reporting contact.
- **II.7** `[repo]` Mechanisms to securely distribute updates so
  vulnerabilities are fixed or mitigated in a timely manner. Check: release
  pipeline integrity (protected branches, CI on release, signed artifacts
  where applicable).
- **II.8** `[org]` Security patches are disseminated without delay and free of
  charge (unless otherwise agreed), with advisory messages including actions
  to be taken. Check: patch communication practice documented.

## Review record

| Date | Reviewer | Outcome |
|------|----------|---------|
| — | pending (Andrea + external counsel) | — |
```

- [ ] **Step 2: Sanity checks and commit**

Run: `grep -c '^- \*\*' skills/cra-evidence/references/cra_annex1_checklist.md`
Expected: `22` (I.1, I.2a–m = 14 total, II.1–II.8 = 8).

```bash
git add skills/cra-evidence/references/cra_annex1_checklist.md
git commit -m "feat(cra-evidence): draft CRA Annex I checklist (pending counsel review)"
```

---

### Task 10: References — triage guidance + EAA/WCAG checklist

**Files:**
- Create: `skills/cra-evidence/references/triage_guidance.md`
- Create: `skills/cra-evidence/references/eaa_wcag_checklist.md`

**Interfaces:**
- Produces: `triage_guidance.md` (consumed by W2 triage drafting — outcome names `fix` / `mitigate` / `accept` must match `vuln_record_template.md` from Task 8); `eaa_wcag_checklist.md` (consumed by W4 — split "automated (axe-core)" vs "manual verification required").

- [ ] **Step 1: Write `skills/cra-evidence/references/triage_guidance.md`**

```markdown
# Vulnerability Triage Guidance

How to draft the "Exploitability in context" and "Draft decision" sections of
a vuln record (assets/vuln_record_template.md). Drafts are ALWAYS `Proposed`;
a named human decides.

## Step 1 — Locate the component

- Direct or transitive? (lockfile tells you)
- Runtime or dev-only? A dev-only dependency (build tool, test lib) is usually
  not shipped — say so, but check it doesn't run in CI with production secrets.

## Step 2 — Reachability

- Is the vulnerable function/feature actually used? Search the codebase for
  the API named in the advisory.
- Is attacker-controlled input able to reach it? Trace from entry points
  (HTTP routes, queues, CLI) — cite files/lines in the record.
- Unknown reachability ≠ not exploitable. Default to "unknown — treat as
  reachable" when the search is inconclusive.

## Step 3 — Environmental mitigations

Only count mitigations that are verifiable: authentication in front of the
route, the service not being internet-facing, WAF rules that exist in config,
input validation on the specific path. "We probably validate that" is not a
mitigation.

## Step 4 — Severity → default action

| Severity (CVSS) | Default action in draft |
|-----------------|-------------------------|
| Critical (9.0–10.0) | fix immediately (before merge/release); accept requires ADR + explicit counsel-visible rationale |
| High (7.0–8.9) | fix in the current release cycle |
| Medium (4.0–6.9) | fix in a scheduled maintenance window; mitigate meanwhile if reachable |
| Low (0.1–3.9) | batch with the next dependency-update round |

Context moves severity in BOTH directions: an unreachable Critical may draft
as `accept` (with ADR); a reachable Medium on an internet-facing route may
draft as fix-now. Always explain the move.

## Outcomes (exactly one per record)

- **fix** — upgrade/patch. Name the target version.
- **mitigate** — a verifiable control reduces exploitability while a fix is
  scheduled. Name the control and the re-review date.
- **accept** — risk accepted (e.g. not exploitable in context). REQUIRES an
  ADR via the adr-management conventions (W5) and a re-review date. Never
  open-ended.

## Escalation

Evidence of active exploitation (public PoC being exploited, indicators in
logs) → stop triage, flag to the human immediately, and complete the ENISA
notification assessment section of the record (CRA Art. 14 timelines: early
warning 24h, notification 72h from awareness — organizational act, human-only).
```

- [ ] **Step 2: Write `skills/cra-evidence/references/eaa_wcag_checklist.md`**

```markdown
# EAA / WCAG 2.1 AA Checklist (web products)

Basis for the W4 accessibility module. The EAA (Directive (EU) 2019/882, in
force since 2025-06-28) points to EN 301 549, which for web content maps to
WCAG 2.1 AA. Automated scanning (axe-core) covers ONLY PART of these
criteria — the dossier must always state this explicitly and list the manual
items as open until a human completes them.

## Automated — covered by axe-core (a11y_scan.sh)

| Criterion | What axe checks |
|-----------|-----------------|
| 1.1.1 Non-text content | images/inputs missing alternative text |
| 1.3.1 Info and relationships | form labels, table headers, ARIA roles/attributes validity |
| 1.4.3 Contrast (minimum) | text contrast ratios |
| 2.4.2 Page titled | missing/empty `<title>` |
| 3.1.1 Language of page | missing/invalid `lang` attribute |
| 3.1.2 Language of parts | invalid `lang` on elements |
| 4.1.2 Name, role, value | ARIA name/role/value on UI components |

Passing axe = no violations *detected*; it is NOT WCAG conformance.

## Manual verification required (never claimed automatically)

| Criterion | What a human must check |
|-----------|--------------------------|
| 1.2.x Time-based media | captions, audio description on video/audio |
| 1.3.2 Meaningful sequence | reading order with CSS off / screen reader |
| 1.4.5 Images of text | text rendered as images without need |
| 1.4.10 Reflow | usable at 320px width / 400% zoom |
| 1.4.11 Non-text contrast | UI component and graphic contrast |
| 2.1.1 / 2.1.2 Keyboard | full operation by keyboard, no traps |
| 2.4.3 Focus order | logical tab order |
| 2.4.6 Headings and labels | descriptive, not just present |
| 2.4.7 Focus visible | visible focus indicator throughout |
| 2.5.x Input modalities | pointer gestures, target size behaviour |
| 3.2.1 / 3.2.2 On focus / on input | no unexpected context changes |
| 3.3.1–3.3.4 Input assistance | error identification, suggestions, prevention |

## Output rule for W4

For each scanned route the dossier gets: axe violation count + top findings
(criterion, element, suggested fix) AND the manual table above with per-item
status `not yet verified` until a named human marks otherwise.
```

- [ ] **Step 3: Commit**

```bash
git add skills/cra-evidence/references/triage_guidance.md skills/cra-evidence/references/eaa_wcag_checklist.md
git commit -m "feat(cra-evidence): add triage guidance and EAA/WCAG reference"
```

---

### Task 11: cra-evidence SKILL.md

**Files:**
- Create: `skills/cra-evidence/SKILL.md`

**Interfaces:**
- Consumes: every script/asset/reference contract from Tasks 4–10 (exact relative paths: `scripts/gen_sbom.sh`, `scripts/diff_sbom.py`, `scripts/scan_vulns.sh`, `scripts/a11y_scan.sh`, `assets/dossier_template.md`, `assets/vuln_record_template.md`, `assets/claude_md_snippet.md`, `references/cra_annex1_checklist.md`, `references/triage_guidance.md`, `references/eaa_wcag_checklist.md`) and adr-management conventions from Task 2.
- Produces: the complete skill. Must be < 500 lines.

- [ ] **Step 1: Write `skills/cra-evidence/SKILL.md`**

````markdown
---
name: cra-evidence
description: >-
  Generate and maintain the EU Cyber Resilience Act (CRA) compliance evidence
  package for a repository: CycloneDX SBOMs, SBOM diffs between releases,
  vulnerability scans with triage drafts, Annex I gap reports, and EAA/WCAG
  accessibility scans, all assembled into a review-ready dossier. Use whenever
  a release or tag is being prepared ("prepare the release", "cut v2.3",
  "release checklist"), when compliance readiness comes up ("are we CRA
  ready?", "compliance status", "gap report", "technical file"), when
  dependencies or vulnerabilities are the topic ("check our dependencies",
  "any known CVEs?", "scan for vulnerabilities", "generate an SBOM", "what
  changed in our supply chain"), when accessibility auditing is requested
  (EAA, WCAG, a11y, axe), or when a repo's compliance/ dossier needs
  initializing or updating.
---

# CRA Evidence

Produces and maintains the compliance evidence package (CRA, SBOM, EAA) for
the current repository. Compliance fails through friction, not ignorance —
so this skill does the assembly work proactively and hands humans a
review-ready draft.

## Core contract

1. **Claude drafts, humans approve.** Every artifact this skill creates
   carries status `Draft` or `Proposed`. NEVER mark anything `Accepted`,
   `Compliant`, `Conformant-final`, or equivalent on your own initiative —
   only after explicit human confirmation, recorded in the dossier review log.
2. **Never assume scope.** CRA class and EAA applicability are legal
   determinations: ask the human (W1); read them from the repo's CLAUDE.md
   compliance policy block thereafter.
3. **No legal advice.** Output is evidence and gap analysis. When a question
   requires legal interpretation, say so and defer to counsel.
4. **Degrade loudly.** If a tool is missing, relay the script's install hint
   and stop that step — never silently skip evidence.

## Evidence layout (in the target repo)

```
compliance/
├── COMPLIANCE.md          # the dossier (from assets/dossier_template.md)
├── sbom/<ref>.cdx.json    # one SBOM per release ref (+ <ref>.vulns.json scans)
├── vulns/<ID>.md          # one triage record per finding
└── a11y/axe-<route>.json  # accessibility scan output (frontend repos)
```

## Choosing the workflow

| Situation | Workflow |
|-----------|----------|
| No `compliance/` directory yet, or "set up compliance" | W1 Initialize |
| Release/tag being prepared; "check dependencies"; "generate SBOM" | W2 Release evidence |
| "Are we CRA ready?", "gap report", audit prep | W3 Gap report |
| Accessibility/EAA/WCAG request, frontend repo | W4 EAA module |
| A triage decision accepts risk or constrains architecture | W5 ADR handoff |

Workflows compose: a release usually means W2, then W3 if the dossier is
stale, then W5 for any `accept` decisions.

## W1 — Initialize

1. Detect the stack: look for `composer.lock`, `package-lock.json`, `go.mod`,
   `requirements*.txt` / `poetry.lock`, `Dockerfile`(s). Record what was found.
2. Create `compliance/` and `compliance/COMPLIANCE.md` from
   `assets/dossier_template.md`, filling product name, repo, detected stack.
3. Propose the policy block from `assets/claude_md_snippet.md` for the repo's
   CLAUDE.md — filled with your best guesses CLEARLY MARKED as guesses.
4. **Ask the human** (do not proceed on assumptions): Is this product in CRA
   scope, and which class (default / important I / important II)? Does the
   EAA apply (public-facing UI)? Which routes should a11y scans cover?
5. Leave scope fields as `[pending human confirmation]` until answered.

## W2 — Release evidence

Run when a release/tag is being prepared, or on request.

1. **SBOM:** `bash scripts/gen_sbom.sh <repo-dir> <ref>` — the last stdout
   line is the SBOM path.
2. **Diff:** find the previous release's SBOM in `compliance/sbom/` (highest
   version-sorted ref before this one). If none, note "first tracked release".
   Otherwise: `python3 scripts/diff_sbom.py <old> <new>` and include the
   Markdown output in the dossier ("what entered/left the supply chain").
3. **Scan:** `bash scripts/scan_vulns.sh <sbom>` — last stdout line is the
   report path.
4. **Triage drafts:** for each finding in the report, create
   `compliance/vulns/<ID>.md` from `assets/vuln_record_template.md`, reasoning
   per `references/triage_guidance.md` (reachability, exposure, mitigations,
   severity→action). One file per finding; skip findings that already have a
   record unless the severity or fix availability changed — then update and
   flag the change. Status: always `Proposed`.
5. **Dossier update:** add the release row to section 2, refresh the register
   in section 3.
6. **Present for review:** a compact summary — components added/removed/
   changed, findings by severity, your draft decisions, and what needs a
   human answer. Never present this as "done"; present it as "ready for review".
7. Any `accept` (and any `mitigate` with architectural weight) → W5.

## W3 — Gap report

1. Read `references/cra_annex1_checklist.md` in full.
2. For EVERY item (no skips): inspect the repo for the described evidence and
   assign exactly one state:
   - **conformant** — with a pointer to the evidence (file, config, workflow);
   - **gap** — with a concrete suggested remediation;
   - **not applicable** — with the stated rationale.
   `[org]`-tagged items that the repo cannot prove: mark **gap** with
   remediation "requires organizational evidence: <what>" unless evidence was
   provided.
3. Never output a bare "compliant"; every state carries its pointer/reason.
4. Write the resulting table into dossier section 4 with the run date; present
   the gaps summary to the human. The checklist is a DRAFT pending counsel
   review — say so in the output.

## W4 — EAA module (frontend repos only)

1. Read the a11y routes from the repo's CLAUDE.md compliance policy block. No
   routes declared → ask, don't guess. Confirm the base URL to scan
   (local dev server or staging — NEVER production without explicit consent).
2. `bash scripts/a11y_scan.sh <base-url> compliance/a11y <routes...>`
3. Summarize per route: violation count, top findings (criterion, element,
   suggested fix) per `references/eaa_wcag_checklist.md`.
4. In the dossier (section 5), ALWAYS include the manual-verification table
   from the reference with status `not yet verified` per item — automated
   coverage is partial and the output must say so explicitly.

## W5 — ADR handoff

Triage decisions with architectural or risk-acceptance weight — "accept
CVE-X as non-exploitable", "pin dependency Y", "isolate module Z instead of
upgrading" — must leave a decision record. Follow the **adr-management**
skill's conventions (it may be installed alongside this skill):

- Same directory detection (`.adr-dir`, `docs/adr/`, `docs/decisions/`, …)
  and numbering; use its `new_adr.sh` when available.
- Draft the ADR with status `Proposed`, context = the vuln record's
  exploitability analysis, alternatives = the triage options not chosen.
- Cross-link: vuln record ↔ ADR path.

Do not duplicate ADR logic here — the adr-management skill owns it.

## Scripts quick reference

| Script | Contract |
|--------|----------|
| `scripts/gen_sbom.sh [dir] [ref]` | SBOM → `compliance/sbom/<ref>.cdx.json`; prints path |
| `scripts/diff_sbom.py OLD NEW [--json]` | Markdown/JSON component diff on stdout |
| `scripts/scan_vulns.sh SBOM [out]` | grype (osv-scanner fallback) → JSON report; prints path |
| `scripts/a11y_scan.sh URL OUTDIR ROUTES…` | axe-core JSON per route; prints out dir |

All scripts exit 127 with an install hint when their tool is missing —
relay that hint verbatim to the user.

## Language and tone of generated evidence

English. Dossier prose must be readable by a non-developer (external
counsel): plain-language summaries first, technical pointers second. State
uncertainty explicitly; an honest `unknown` beats a confident guess.
````

- [ ] **Step 2: Verify size and path references**

Run: `wc -l skills/cra-evidence/SKILL.md`
Expected: < 500.

Run: `cd skills/cra-evidence && for f in scripts/gen_sbom.sh scripts/diff_sbom.py scripts/scan_vulns.sh scripts/a11y_scan.sh assets/dossier_template.md assets/vuln_record_template.md assets/claude_md_snippet.md references/cra_annex1_checklist.md references/triage_guidance.md references/eaa_wcag_checklist.md; do [ -f "$f" ] || echo "MISSING: $f"; done; cd -`
Expected: no `MISSING:` lines.

- [ ] **Step 3: Portability check (install-copy simulation)**

```bash
SCRATCH="$(mktemp -d)"
mkdir -p "$SCRATCH/repo/.claude/skills"
cp -R skills/cra-evidence "$SCRATCH/repo/.claude/skills/cra-evidence"
cp tests/fixtures/node-minimal/package*.json "$SCRATCH/repo/"
cd "$SCRATCH/repo" && bash .claude/skills/cra-evidence/scripts/gen_sbom.sh . v0.0.1
```

Expected: prints `./compliance/sbom/v0.0.1.cdx.json`; proves relative paths survive `.claude/skills/` installation (brief Deliverable 3.1). Clean up the scratch dir; return to the repo.

- [ ] **Step 4: Commit**

```bash
git add skills/cra-evidence/SKILL.md
git commit -m "feat(cra-evidence): add SKILL.md defining workflows W1-W5"
```

---

### Task 12: Program docs (distribution, CI gate proposal, rollout note)

**Files:**
- Create: `docs/distribution.md`
- Create: `docs/ci-gate-proposal.md`
- Create: `docs/rollout-note.md`

**Interfaces:**
- Consumes: skill paths from Tasks 2 and 11; scanner decision (grype) from Task 6.
- Produces: team-facing docs referenced from README (Task 1).

- [ ] **Step 1: Write `docs/distribution.md`**

Required content, all sections:

1. **Scope ladder** (verbatim concept from brief §7.3): personal `~/.claude/skills/` = pilot; `.claude/skills/` in repo = project standard; plugin = company standard (future).
2. **Install per repo (standard)** — exact commands:
   ```bash
   git clone https://github.com/Oltrematica/oltrematica-compliance-skills.git /tmp/ocs
   cp -R /tmp/ocs/skills/cra-evidence  /path/to/repo/.claude/skills/cra-evidence
   cp -R /tmp/ocs/skills/adr-management /path/to/repo/.claude/skills/adr-management
   ```
   plus the verify step (`/skills` in a new session) and the note that skill-internal paths are relative, so plain copies work (verified in Task 11 Step 3).
3. **Submodule option** with the caveat that Claude Code discovers `.claude/skills/<name>/SKILL.md` — a submodule of this whole repo must therefore live elsewhere (e.g. `tools/oltrematica-skills`) with per-skill copies or symlinks into `.claude/skills/`; recommend plain copy for simplicity, updated via `git pull` + re-copy.
4. **Updating** — re-copy on new tags of this repo; changelog = git log of `skills/`.
5. **Future: plugin conversion (deliberate deviation from brief §7.2)** — the plain-repo layout was chosen on 2026-07-09 (see spec); sketch what conversion needs later: `.claude-plugin/marketplace.json` at root + per-plugin `plugin.json` + `skills/` move, team installs via `/plugin marketplace add Oltrematica/oltrematica-compliance-skills`. Keep to one paragraph — a sketch, not a design.
6. **External tool prerequisites per skill**: adr-management — none beyond bash/sed/find; cra-evidence — syft (required for SBOM), grype (primary scanner; osv-scanner accepted fallback), Node/npx + Chrome (a11y module only). One `brew install syft grype` line for macOS.

- [ ] **Step 2: Write `docs/ci-gate-proposal.md`**

A design proposal ONLY (Phase 3 deliverable; the brief's non-goal "no CI enforcement in Phase 1" still holds — nothing is wired into any repo). Required content:

1. Purpose: on every tagged release, CI produces the SBOM + scan automatically; the gate fails the release on unremediated Critical findings.
2. The proposed workflow YAML, ready to adapt:
   ```yaml
   # .github/workflows/release-evidence.yml  (PROPOSAL — not enforced anywhere yet)
   name: release-evidence
   on:
     push:
       tags: ['v*']
   permissions:
     contents: write
   jobs:
     sbom-and-scan:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - name: Generate SBOM (CycloneDX)
           uses: anchore/sbom-action@v0
           with:
             format: cyclonedx-json
             output-file: sbom-${{ github.ref_name }}.cdx.json
             artifact-name: sbom-${{ github.ref_name }}.cdx.json
         - name: Scan SBOM
           uses: anchore/scan-action@v6
           with:
             sbom: sbom-${{ github.ref_name }}.cdx.json
             fail-build: true
             severity-cutoff: critical
         - name: Attach SBOM to release
           uses: softprops/action-gh-release@v2
           with:
             files: sbom-${{ github.ref_name }}.cdx.json
   ```
3. Gate policy discussion: `severity-cutoff: critical` initially; the escape hatch is an approved `accept` triage record + ADR, implemented later as an allowlist file read by the workflow (design note, not built).
4. Relationship to the skill: CI produces raw evidence on every tag unattended; the skill (W2) remains the interpretation/triage layer. They share formats (CycloneDX, grype JSON).
5. Open points for Mircha/Alex review: pin action versions vs. major tags; where the allowlist lives; whether the SBOM should also be committed back to `compliance/sbom/`.

- [ ] **Step 3: Write `docs/rollout-note.md`** — one page, modeled on the adr-management pilot email tone (plain, imperative, no ceremony). Required content:

1. What shipped: the two skills, one repo, install in two `cp -R` commands.
2. What changes for a repo owner: run W1 once (answers: CRA scope/class, EAA routes); regenerate evidence on every tagged release ("prepare the release" triggers it); review `Proposed` triage records and dossier updates — Claude never finalizes anything.
3. The dates that matter: CRA vulnerability-reporting obligations **2026-09-11**; full CRA **2027-12-11**; EAA already in force.
4. What NOT to expect: no legal advice, no DPIA/AI-Act coverage (parking lot), no CI enforcement yet (proposal in `docs/ci-gate-proposal.md`).
5. Where to complain / contribute: this repo's issues; checklist review pending counsel (Annex I file carries a DRAFT banner until then).
6. Sign-off: Andrea (Head of Tech).

- [ ] **Step 4: Commit**

```bash
git add docs/distribution.md docs/ci-gate-proposal.md docs/rollout-note.md
git commit -m "docs: add distribution guide, CI gate proposal and rollout note"
```

---

### Task 13: Trigger validation + acceptance run-through

**Files:**
- Create: `tests/trigger-validation.md`
- Modify: `tests/notes.md` (final acceptance section)

**Interfaces:**
- Consumes: SKILL.md descriptions from Tasks 2 and 11; brief §5 acceptance criteria (in `docs/development-brief.md`).

- [ ] **Step 1: Write `tests/trigger-validation.md`**

For each skill, evaluate each prompt against the SKILL.md `description:` field alone (that is all the router sees): would a Claude Code session load this skill for this prompt? Record PASS/FAIL per row honestly — a FAIL means the description needs editing (edit it, note the change, re-evaluate). Structure:

```markdown
# Trigger validation

Method: each prompt judged against the skill's `description:` frontmatter
only. Expected=trigger prompts must plausibly match; expected=no-trigger
prompts must not. Date: 2026-07-09.

## cra-evidence

| # | Prompt | Expected | Result |
|---|--------|----------|--------|
| 1 | "prepare the release" | trigger | |
| 2 | "are we CRA ready?" | trigger | |
| 3 | "check our dependencies" | trigger | |
| 4 | "generate an SBOM for v2.1" | trigger | |
| 5 | "run an accessibility audit on the login page" | trigger | |
| 6 | "fix the failing invoice test" | no trigger | |
| 7 | "refactor UserController into a service class" | no trigger | |
| 8 | "why did we choose Redis for queues?" | no trigger (adr-management's) | |
| 9 | "write a migration for the orders table" | no trigger | |
| 10 | "update the README badges" | no trigger | |

## adr-management

| # | Prompt | Expected | Result |
|---|--------|----------|--------|
| 1 | "document this decision" | trigger | |
| 2 | "why did we choose Laravel over keeping Python?" | trigger | |
| 3 | "we're switching session storage to Redis" | trigger | |
| 4 | "backfill our decision history from git" | trigger | |
| 5 | "we decided to accept CVE-2020-8203 as non-exploitable" | trigger | |
| 6 | "prepare the release" | no trigger (cra-evidence's) | |
| 7 | "fix this typo in the docs" | no trigger | |
| 8 | "bump lodash patch version" | no trigger | |
| 9 | "generate an SBOM" | no trigger (cra-evidence's) | |
| 10 | "add a feature flag for the new dashboard" | no trigger | |
```

Fill every Result cell. If any row fails, adjust the relevant `description:` (cra-evidence: Task 11 file; adr-management: only if a cross-trigger conflict emerges — otherwise its description stays frozen), record the edit in this file, and re-check.

- [ ] **Step 2: Acceptance criteria run-through**

Append to `tests/notes.md` a section `## 2026-07-09 — acceptance criteria (brief §5)` walking each criterion with its evidence pointer:

1. W2 on Laravel + Node fixture → Task 4/5/6 evidence (SBOM, diff, scan, triage-drafting defined in SKILL.md W2).
2. SBOM diff added/removed/changed → Task 5 Step 4 results.
3. Gap report three-state coverage → W3 rules + 22-item checklist count (Task 9).
4. Missing-tool messages → Task 4 Step 5, Task 6 Step 4, Task 7 Step 3 results.
5. No autonomous Accepted/Compliant → Task 8 Step 4 grep + SKILL.md core contract.
6. Dossier non-developer readability → template review note (plain-language sections first).
7. Trigger validation → `tests/trigger-validation.md` results.
8. Both skills installable → Task 11 Step 3 portability check + `docs/distribution.md`.

Mark honestly: anything not fully verifiable in this environment (e.g. live axe run without Chrome) is listed as `partial — <reason>`, not silently passed.

- [ ] **Step 3: Final repo state check and commit**

Run: `git status --short`
Expected: only the two test files staged/modified; no stray generated files (fixture `compliance/` dirs are gitignored — verify with `git check-ignore tests/fixtures/node-minimal/compliance/sbom/v1.0.0.cdx.json` → path echoed back).

```bash
git add tests/trigger-validation.md tests/notes.md
git commit -m "test: add trigger validation and acceptance criteria evidence"
```

---

## Post-plan notes (not tasks)

- **OQ-2 remains open:** picking the real demo repo and running W1→W5 there (program definition of done) is Andrea's call — flag it in the final report.
- **Do not push** to the GitHub remote unless Andrea asks.
- **Archiving** `Oltrematica/adr-management-skill` on GitHub is Andrea's manual step.
