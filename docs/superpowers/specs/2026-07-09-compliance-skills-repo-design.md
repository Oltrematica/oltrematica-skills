# Design: oltrematica-compliance-skills repo — full program consolidation

**Date:** 2026-07-09
**Owner:** Andrea Margiovanni
**Status:** Approved (design review in chat, 2026-07-09)
**Source:** Development Brief — Oltrematica Compliance Skills Program v1.0 (see `docs/development-brief.md`)

## Goal

Consolidate the existing `adr-management` skill and the full Compliance Skills Program brief (Phases 1–3) into this dedicated repo: build the `cra-evidence` skill (workflows W1–W5), the CLAUDE.md policy snippet, fixtures and trigger validation, distribution docs, and the CI gate design proposal.

## Decisions made

| Decision | Resolution |
|----------|-----------|
| Scope | Full brief, Phases 1–3 |
| adr-management migration | Plain copy into `skills/adr-management/`; standalone GitHub repo left untouched (Andrea archives it manually later) |
| OQ-1 Annex I checklist source | Drafted from CRA Annex I Part I + II regulation text; marked DRAFT pending Andrea + external counsel review |
| OQ-3 Scanner | grype primary (free, Apache 2.0); osv-scanner as fallback when grype is missing |
| Repo layout | Plain skills repo (`skills/`, `docs/`, `tests/`, `README.md`) — NOT a plugin marketplace. Deviation from brief Deliverable 3.2, approved: plugin conversion documented as a future step in `docs/distribution.md` |
| OQ-2 Demo repo | Open — fixtures cover build-time verification; real-repo demo target is Andrea's pick before July 15 |
| OQ-4 PDF export | Deferred per brief |

## Repo layout

```
oltrematica-compliance-skills/
├── README.md                     # what this repo is, install instructions, skill catalog
├── LICENSE                       # proprietary, Oltrematica (copied from adr repo)
├── skills/
│   ├── adr-management/           # copied as-is from standalone repo
│   │   ├── SKILL.md
│   │   ├── README.md             # install paths updated to this repo; LICENSE pointer → repo root
│   │   ├── scripts/new_adr.sh
│   │   └── assets/template.md
│   └── cra-evidence/
│       ├── SKILL.md              # < 500 lines, workflows W1–W5
│       ├── scripts/
│       │   ├── gen_sbom.sh       # syft → CycloneDX JSON at stable path
│       │   ├── diff_sbom.py      # component-level diff between two CycloneDX files (Python stdlib)
│       │   ├── scan_vulns.sh     # grype primary, osv-scanner fallback
│       │   └── a11y_scan.sh      # axe-core (npx @axe-core/cli) against configured routes
│       ├── assets/
│       │   ├── dossier_template.md      # COMPLIANCE.md skeleton
│       │   ├── vuln_record_template.md  # single-CVE triage record incl. ENISA-notification draft fields
│       │   └── claude_md_snippet.md     # ≤15-line per-repo compliance policy block (brief §6)
│       └── references/
│           ├── cra_annex1_checklist.md  # DRAFT banner; repo-level verifiable checks; "requires organizational evidence" tags
│           ├── triage_guidance.md       # exploitability heuristics, severity mapping, fix/mitigate/accept outcomes
│           └── eaa_wcag_checklist.md    # WCAG 2.1 AA subset: automatable vs manual
├── docs/
│   ├── development-brief.md      # the program brief v1.0, verbatim record
│   ├── distribution.md           # per-repo install (copy or submodule of skills/<name> → .claude/skills/), scope ladder (personal → repo → plugin), future plugin conversion sketch
│   ├── ci-gate-proposal.md       # Phase 3 design ONLY: GitHub Actions YAML (SBOM on tag, grype scan, fail on critical CVE); no CI wired anywhere
│   └── rollout-note.md           # one-page team note modeled on the adr-management pilot email
└── tests/
    ├── fixtures/
    │   ├── laravel-minimal/      # composer.json + composer.lock
    │   ├── node-minimal/         # package.json + package-lock.json with known-vulnerable pinned dep (e.g. old lodash)
    │   └── polyglot/             # both ecosystems + Dockerfile
    ├── trigger-validation.md     # 5 positive / 5 negative prompts per skill + results
    └── notes.md                  # standalone script test evidence per fixture
```

## cra-evidence skill design

### Evidence location (in target repos)

All generated evidence lives in the target repo under `compliance/`:

- `compliance/COMPLIANCE.md` — the dossier (from `dossier_template.md`)
- `compliance/sbom/<ref>.cdx.json` — one SBOM per release ref
- `compliance/vulns/<CVE-ID>.md` — one triage record per finding
- `compliance/a11y/` — accessibility scan reports

Everything is plain files, reviewable in a PR.

### Workflows

- **W1 Initialize:** detect stack (composer.lock, package-lock.json, go.mod, requirements*/poetry, Dockerfile); scaffold `compliance/` with dossier skeleton; propose the CLAUDE.md policy block; ask the human for CRA scope/class and EAA applicability — never assume scope.
- **W2 Release evidence:** `gen_sbom.sh` → `diff_sbom.py` vs previous release SBOM (added / removed / version-changed components) → `scan_vulns.sh` → Claude drafts one triage record per finding using `triage_guidance.md` (always status `Proposed`) → update dossier → present summary for review.
- **W3 Gap report:** walk `cra_annex1_checklist.md`; every item gets exactly one of: *conformant* (+ evidence pointer), *gap* (+ suggested remediation), *not applicable* (+ rationale). No bare "compliant", no silently skipped items.
- **W4 EAA module (frontend repos only):** `a11y_scan.sh` against routes listed in the repo's policy block; merge into dossier; explicit "automated coverage is partial — manual checks required" section listing manual items from `eaa_wcag_checklist.md`.
- **W5 ADR handoff:** triage decisions with architectural or risk-acceptance weight (accept CVE as non-exploitable, pin dependency) produce a `Proposed` ADR following adr-management conventions — same directory detection, same numbering, via `new_adr.sh` when available. SKILL.md references the convention; no duplicated ADR logic.

### Scripts contract (binding)

- bash (POSIX-leaning) or Python 3 stdlib only; no new dependencies.
- Every script begins with a tool-presence check; a missing tool exits non-zero with an actionable install hint (e.g. `brew install syft` / project URL), never a stack trace.
- Each script prints the output file path(s) on stdout so SKILL.md can chain them.
- External tools version-checked or pinned where feasible (per brief §4.6).

### Core contract (inherited from adr-management)

Claude drafts; humans approve. No artifact is ever labeled `Accepted` / `Compliant` / final by Claude autonomously. All templates default to `Proposed`.

## Testing plan (brief §9)

1. Each script tested standalone against the three fixtures before being referenced in SKILL.md; evidence recorded in `tests/notes.md`.
2. `node-minimal` fixture pins a known-vulnerable dependency to verify scan → triage draft end-to-end. Fixtures are lockfile-level (no installed `vendor/` or `node_modules/`) since syft/grype read lockfiles.
3. Missing-tool paths tested by simulating absent binaries (PATH manipulation).
4. Trigger validation per skill: 5 positive prompts ("prepare the release", "are we CRA ready?", "check our dependencies"…) and 5 negative prompts, results in `tests/trigger-validation.md`.
5. Acceptance criteria from brief §5 checked one by one before declaring done.

## Acceptance criteria (from brief, program level)

- [ ] W2 on a Laravel fixture and a Node fixture produces: CycloneDX SBOM, human-readable diff, vulnerability list with triage drafts, updated dossier — one invocation.
- [ ] SBOM diff correctly identifies added / removed / version-changed components.
- [ ] Gap report covers 100% of checklist items with one of the three states.
- [ ] Missing external tool produces an actionable message with install hint.
- [ ] No artifact ever labeled Accepted/Compliant without a human step; templates default `Proposed`.
- [ ] Dossier readable by a non-developer (external-counsel test).
- [ ] Skill triggers validated: 5 positive / 5 negative prompts per skill.
- [ ] Both skills installable from this repo per `docs/distribution.md`.

## Out of scope

No DPIA/GDPR skill, no AI Act skill, no legal advice generation, no SaaS productization, no CI enforcement (proposal doc only), no PDF/Word export, no plugin marketplace manifest (future step). Anything discovered during build that is not listed here goes to the parking lot, not into scope.
