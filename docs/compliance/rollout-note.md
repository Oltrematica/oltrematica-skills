# Rollout note: Compliance Skills

## What shipped

Two Claude Code skills, one repo:

- `adr-management` — drafts Architecture Decision Records proactively.
- `cra-evidence` — generates and maintains the CRA evidence package (SBOM,
  vulnerability triage, Annex I gap report, EAA/WCAG module).

Install either one with a clone and two copies:

```bash
git clone https://github.com/Oltrematica/oltrematica-skills.git /tmp/os
/tmp/os/scripts/install.sh cra-evidence adr-management --to /path/to/repo
```

Full options in [`docs/distribution.md`](../distribution.md).

## What changes for you, as a repo owner

- Run **W1 (Initialize)** once per repo. Claude asks two things it will
  never guess: your CRA scope/class, and whether EAA applies (and which
  routes to check). Answer once, it's saved in your repo's CLAUDE.md.
- From then on, say "prepare the release" (or similar) when cutting a tag
  and Claude regenerates the evidence — SBOM, diff against the last release,
  vulnerability scan, triage drafts, updated dossier — in one pass.
- You will see `Proposed` triage records and dossier updates. **Claude never
  finalizes anything.** Review them like any other PR content, approve or
  push back. Same contract as the ADR pilot: Claude drafts, you decide.

## Dates that matter

- **2026-09-11** — CRA vulnerability-reporting obligations start applying.
- **2027-12-11** — full CRA obligations apply.
- EAA is already in force, since 2025-06-28.

## What NOT to expect

- No legal advice. Output is evidence and gap analysis; legal interpretation
  stays with counsel.
- No DPIA or AI Act coverage yet — parked, not forgotten.
- No CI enforcement yet. There's a design proposal
  ([`docs/ci-gate-proposal.md`](ci-gate-proposal.md)) for a future gate that
  fails a release on unremediated Critical findings, but nothing is wired
  into any repo's pipeline today.

## Where to complain / contribute

Open an issue on this repo. If you disagree with an Annex I checklist item,
say so there too — the checklist (`cra_annex1_checklist.md`) carries a
**DRAFT banner** until Andrea and external counsel review it; it is not
authoritative yet.

## Sign-off

Andrea (Head of Tech)
