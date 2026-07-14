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
