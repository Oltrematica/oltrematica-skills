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
