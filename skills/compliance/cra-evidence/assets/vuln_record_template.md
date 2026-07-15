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
