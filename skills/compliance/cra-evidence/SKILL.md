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
