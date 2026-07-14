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
