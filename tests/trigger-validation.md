# Trigger validation

Method: each prompt judged against the skill's `description:` frontmatter
only (that is all the router sees — the SKILL.md body, including the "Do
NOT draft ADRs for..." significance test in adr-management, is invisible at
trigger time). Expected=trigger prompts must plausibly match; expected=no-
trigger prompts must not. Date: 2026-07-09.

## cra-evidence

| # | Prompt | Expected | Result |
|---|--------|----------|--------|
| 1 | "prepare the release" | trigger | PASS — phrase is quoted verbatim in the description's release-prep example list. |
| 2 | "are we CRA ready?" | trigger | PASS — quoted verbatim in the compliance-readiness example list. |
| 3 | "check our dependencies" | trigger | PASS — quoted verbatim in the dependencies/vulnerabilities example list. |
| 4 | "generate an SBOM for v2.1" | trigger | PASS — "generate an SBOM" is quoted verbatim; the version suffix doesn't change the match. |
| 5 | "run an accessibility audit on the login page" | trigger | PASS — "accessibility auditing is requested" is an explicit trigger clause; "accessibility audit" matches directly. |
| 6 | "fix the failing invoice test" | no trigger | PASS — no overlap with release/compliance/dependency/accessibility language; a routine bugfix. |
| 7 | "refactor UserController into a service class" | no trigger | PASS — pure code refactor, no compliance/evidence angle. |
| 8 | "why did we choose Redis for queues?" | no trigger (adr-management's) | PASS — the description's dependency clause is anchored to audit/scan/generate phrasing ("check our dependencies", "scan for vulnerabilities", "generate an SBOM", "what changed in our supply chain"). A "why did we choose X" rationale question doesn't match that pattern even though Redis is technically a dependency; it matches adr-management's explicit "why did we choose X" clause instead. See note below — this was the specific risk flagged by prior review; verified deliberately rather than assumed. |
| 9 | "write a migration for the orders table" | no trigger | PASS — no compliance/evidence/dependency/accessibility language. |
| 10 | "update the README badges" | no trigger | PASS — cosmetic doc change, no overlap. |

## adr-management

| # | Prompt | Expected | Result |
|---|--------|----------|--------|
| 1 | "document this decision" | trigger | PASS — quoted verbatim in the description. |
| 2 | "why did we choose Laravel over keeping Python?" | trigger | PASS — matches the "why did we choose X" clause verbatim. |
| 3 | "we're switching session storage to Redis" | trigger | PASS — an active architectural decision statement (storage/infrastructure choice); falls under "infrastructure or hosting changes" / "choosing or replacing a library/framework". |
| 4 | "backfill our decision history from git" | trigger | PASS — near-verbatim match to "asks to backfill decision history for an existing codebase". |
| 5 | "we decided to accept CVE-2020-8203 as non-exploitable" | trigger | PASS — matches "security or compliance tradeoffs" explicitly. |
| 6 | "prepare the release" | no trigger (cra-evidence's) | PASS — no release-process language anywhere in the adr-management description. |
| 7 | "fix this typo in the docs" | no trigger | PASS — trivial, no architectural signal. |
| 8 | "bump lodash patch version" | no trigger | PASS — a patch bump is neither "choosing or replacing a library/framework" nor any other listed category; the description's own examples are about substantive architecture choices, not routine version bumps. (The explicit "do NOT draft for... dependency patch bumps" carve-out lives in the SKILL.md body, not the description — but the description alone, read honestly, doesn't reach this prompt either.) This is the other cross-trigger risk flagged by prior review; verified deliberately. |
| 9 | "generate an SBOM" | no trigger (cra-evidence's) | PASS — no SBOM/evidence/compliance-artifact language in the adr-management description. |
| 10 | "add a feature flag for the new dashboard" | no trigger | PASS — feature flags aren't in the description's list of architecturally significant categories (library/framework, DB/schema, API design, authn/authz, infra/hosting, CI/CD, migrations, breaking changes, deprecations, security/compliance). |

## Outcome

All 20 rows PASS on first evaluation. **No description edit was needed.**

Prior review flagged the cra-evidence description's "dependencies or
vulnerabilities are the topic" clause as broad enough to risk swallowing
adr-management's territory (rows cra-evidence #8 and adr-management #8/#9
were the specific cross-trigger candidates). On honest re-reading: the
clause is broad in its opening words but is immediately anchored by five
concrete example phrases, all of which are about *auditing/generating
evidence* ("check", "scan", "generate", "what changed"), not about
*deciding or explaining a choice*. "Why did we choose Redis for queues?"
and "bump lodash patch version" don't match that anchor pattern in either
skill's description. Because no row actually failed, cra-evidence's
description was left unedited (frozen text still matches Task 11's
committed version) and adr-management's stayed frozen as instructed.

This is a close call rather than a comfortable one — the phrasing works
today because the example anchors are specific, but it would be worth
re-testing this pair (cra-evidence #8, adr-management #8) if either
description is ever loosened in a future edit.
