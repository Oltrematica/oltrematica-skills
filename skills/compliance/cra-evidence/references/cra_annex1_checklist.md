# CRA Annex I — Essential Requirements Checklist

> **DRAFT — pending review by a qualified engineer and external legal counsel.
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
| — | pending (engineering + external counsel) | — |
