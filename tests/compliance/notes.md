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

## 2026-07-09 — gen_sbom.sh

**Tools verified**: `syft` at `/opt/homebrew/bin/syft`, `grype` at `/opt/homebrew/bin/grype`

**Fixture tests (Step 2: RED, Steps 4–5: GREEN):**

| Step | Test | Result |
|------|------|--------|
| 2 | Script missing | FAIL: `No such file or directory` ✓ |
| 4a | `node-minimal v1.0.0` | 3 components; **lodash detected** ✓ |
| 4b | `laravel-minimal v1.0.0` | 2 components; **guzzlehttp/guzzle detected** ✓ |
| 4c | `polyglot v1.0.0` | 5 components; **both lodash AND guzzlehttp/guzzle detected** ✓ |
| 5 | Missing syft (env PATH=/usr/bin:/bin) | exit 127; stderr: "syft not found" + "brew install syft" hint ✓ |

**Output files created** (gitignored):
- `tests/fixtures/node-minimal/compliance/sbom/v1.0.0.cdx.json`
- `tests/fixtures/laravel-minimal/compliance/sbom/v1.0.0.cdx.json`
- `tests/fixtures/polyglot/compliance/sbom/v1.0.0.cdx.json`

**Summary**: gen_sbom.sh contract verified: produces CycloneDX JSON SBOMs with correct component detection across all three fixture ecosystems (npm, composer, polyglot). Error handling for missing syft confirmed (exit 127 + hint). Ready for consumption by Task 5 (diff_sbom.py) and Task 6 (scan_vulns.sh).

## 2026-07-09 — diff_sbom.py

**Deterministic fixtures created** (committed):
- `tests/fixtures/sbom-diff/old.cdx.json` (3 components: lodash 4.17.15, left-pad 1.3.0, guzzlehttp/guzzle 7.4.0)
- `tests/fixtures/sbom-diff/new.cdx.json` (3 components: lodash 4.17.21, axios 1.7.0, guzzlehttp/guzzle 7.4.0)

**Step 2: RED test**

```bash
$ python3 skills/cra-evidence/scripts/diff_sbom.py tests/fixtures/sbom-diff/old.cdx.json tests/fixtures/sbom-diff/new.cdx.json
/Library/Developer/CommandLineTools/usr/bin/python3: can't open file '...diff_sbom.py': [Errno 2] No such file or directory
exit=2
```
✓ Expected: fails before implementation

**Step 4: Verification runs (5 tests)**

| # | Test | Command | Result |
|---|------|---------|--------|
| 1 | Fixture diff: added, removed, changed | `diff_sbom.py old.cdx.json new.cdx.json` | ✓ Added(1): axios 1.7.0; Removed(1): left-pad 1.3.0; Changed(1): lodash 4.17.15→4.17.21; guzzlehttp/guzzle absent |
| 2 | JSON output valid | `diff_sbom.py old.cdx.json new.cdx.json --json \| python3 -m json.tool > /dev/null && echo VALID_JSON` | ✓ VALID_JSON |
| 3 | No changes (identical) | `diff_sbom.py old.cdx.json old.cdx.json` | ✓ "No component changes between the two SBOMs." |
| 4 | Error handling (missing files) | `diff_sbom.py missing.json also-missing.json; echo "exit=$?"` | ✓ "ERROR: cannot read SBOM missing.json..." exit=1 (no traceback) |
| 5 | Real syft output (node-minimal → polyglot) | `diff_sbom.py node-minimal/.../v1.0.0.cdx.json polyglot/.../v1.0.0.cdx.json` | ✓ Added(4): guzzlehttp/guzzle 7.4.0 + 3 other components; Removed(2): node-minimal-fixture + 1 file path; Changed(0); no crash |

**Summary**: diff_sbom.py contract verified: correctly identifies added/removed/changed components keyed by group/name; JSON output is valid; handles edge cases (identical SBOMs, missing files); works with real syft-generated SBOMs. Exit code contract met: 0 on success (even with differences), 1 on unreadable input, 2 on usage error. Ready for consumption by Task 8 (SKILL.md W2).

## 2026-07-09 — scan_vulns.sh

**Tools verified**: `grype` at `/opt/homebrew/bin/grype` version 0.115.0; `osv-scanner` NOT installed (verified via `command -v osv-scanner`)

**Step 1: RED test (script missing)**

```bash
$ bash skills/cra-evidence/scripts/scan_vulns.sh tests/fixtures/node-minimal/compliance/sbom/v1.0.0.cdx.json
bash: skills/cra-evidence/scripts/scan_vulns.sh: No such file or directory
exit=127
```
✓ Expected: fails before implementation

**Step 3: Fixture verification (GREEN)**

| Fixture | Command | Findings | Notable CVEs / GHSA IDs |
|---------|---------|----------|------------------------|
| `node-minimal` | `scan_vulns.sh v1.0.0.cdx.json` | **6 findings (lodash)** | GHSA-35jh-r3h4-6jhm, GHSA-p6mc-m468-83gw, GHSA-29mw-wpgm-hmr9, GHSA-r5fr-rjxr-66jc, GHSA-xxjr-mmjv-4gpg, (1 more) — all in lodash package ✓ |
| `laravel-minimal` | `scan_vulns.sh v1.0.0.cdx.json` | **7 findings (guzzlehttp/guzzle)** | GHSA-f2wf-25xc-69c9, GHSA-w248-ffj2-4v5q, GHSA-25mq-v84q-4j7r, GHSA-q559-8m2m-g699, GHSA-cwmx-hcrq-mhc3, GHSA-cwxw-98qj-8qjx, GHSA-wpwq-4j6v-78m3 — all in guzzlehttp/guzzle package ✓ |

Output files created (gitignored):
- `tests/fixtures/node-minimal/compliance/sbom/v1.0.0.vulns.json`
- `tests/fixtures/laravel-minimal/compliance/sbom/v1.0.0.vulns.json`

**Step 4: Missing-scanner test (exit 127 path)**

```bash
$ env PATH=/usr/bin:/bin bash skills/cra-evidence/scripts/scan_vulns.sh tests/fixtures/node-minimal/compliance/sbom/v1.0.0.cdx.json
ERROR: no vulnerability scanner found (looked for: grype, osv-scanner).
Install the primary scanner: brew install grype   (https://github.com/anchore/grype#installation)
Or the fallback:            brew install osv-scanner (https://google.github.io/osv-scanner/)
exit=127
```
✓ Expected: both install hints on stderr, exit 127

**Coverage notes:**
- **grype path**: fully tested and verified (primary scanner working)
- **osv-scanner fallback path**: not tested on this machine (osv-scanner not installed); code path verified by reading—correctly handles exit code 1 (found vulnerabilities) vs >1 (actual error)
- **missing-scanner path**: fully tested and verified (exit 127 + helpful hints)

**Summary**: scan_vulns.sh contract verified: grype (0.115.0) successfully scans node-minimal (6 lodash findings) and laravel-minimal (7 guzzlehttp/guzzle findings); output files written alongside SBOMs with .vulns.json extension; scanner name reported on stderr; output path on stdout. Missing-scanner error handling confirmed (exit 127 + installation hints). osv-scanner fallback branch untested on this machine (tool not installed) but verified by code reading. Ready for consumption by Task 8 (W2 triage drafting).

## 2026-07-09 — a11y_scan.sh

**Tools verified**: Node v24.12.0 / npx 11.6.2 (via nvm); Google Chrome 149.0.7827.201 at `/Applications/Google Chrome.app`; `@axe-core/cli` resolved on-demand via `npx --yes` (axe-core 4.12.1).

**Step 1: RED test (script missing)**

```bash
$ bash skills/cra-evidence/scripts/a11y_scan.sh http://localhost /tmp/a11y /
bash: skills/cra-evidence/scripts/a11y_scan.sh: No such file or directory
exit=127
```
✓ Expected: fails before implementation

**Step 3: Argument validation and missing-tool tests**

| # | Test | Command | Result |
|---|------|---------|--------|
| 1 | Missing route argument | `a11y_scan.sh http://localhost /tmp/a11y-test` | ✓ stderr: "ERROR: at least one route required (e.g. /)"; exit=2 |
| 2 | Missing npx (PATH stripped) | `env PATH=/usr/bin:/bin bash a11y_scan.sh http://localhost /tmp/a11y-test /` | ✓ stderr: "ERROR: npx (Node.js) not found..." + "Install Node.js: brew install node" hint; exit=127 |

**Step 4: Live verification against local static fixture (best effort)**

Fixture: `<img src="x.png">` (missing alt) + `<input type="text">` (missing label) + no `lang` attribute on `<html>`, served via `python3 -m http.server 8931` from a `mktemp -d` scratch dir.

```bash
$ bash skills/cra-evidence/scripts/a11y_scan.sh http://localhost:8931 "$SCRATCH/out" /
Running axe-core 4.12.1 in chrome-headless
Error: session not created: This version of ChromeDriver only supports Chrome version 150
Current browser version is 149.0.7827.201 with binary path /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
WARN: axe scan failed for / (browser/webdriver missing or page unreachable) — continuing
ERROR: all 1 route scans failed.
exit=1
```

**Outcome: graceful degradation path** (not the successful-scan path). `@axe-core/cli`'s bundled ChromeDriver expects Chrome 150; the installed Chrome is 149.0.7827.201, so the webdriver session could not start. Per the brief, this is an explicitly allowed outcome: the WARN + "all 1 route scans failed" message and exit=1 confirm the graceful-degradation contract works correctly. `$SCRATCH/out` was created (via `mkdir -p`) but contains no `axe-root.json`, consistent with a fully-failed scan. Local http.server (PID tracked explicitly, not via `%1` job control) was killed and confirmed stopped after the test; `$SCRATCH` was a `mktemp -d` temp dir, not committed.

**Coverage notes:**
- **Argument validation (no routes)**: fully tested and verified (exit 2 + message)
- **Missing-npx path**: fully tested and verified (exit 127 + install hint)
- **Multi-route WARN-and-continue loop**: not exercised with a real successful scan on this machine (Chrome/ChromeDriver version mismatch); the single-route all-failed branch was exercised and confirmed; the per-route WARN-and-continue logic and the "$FAILED -eq $#" all-failed check were verified by reading the script
- **Successful-scan path (violations detected in JSON)**: not exercised on this machine — see graceful-degradation note above

**Summary**: a11y_scan.sh contract verified: argument validation (exit 2, no routes) and missing-npx handling (exit 127 + hint) both confirmed with exact expected output. Live scan against a local fixture hit a ChromeDriver/Chrome version mismatch (150 vs 149) rather than a successful axe run; the script's graceful-degradation path (WARN per failed route, exit 1 with "all N route scans failed" when every route fails) worked exactly as designed. Ready for consumption by Task 8 (W4), with the caveat that a successful violation-detecting scan should be re-verified on a machine with matching Chrome/ChromeDriver versions before being relied upon as end-to-end proof.

## 2026-07-09 — acceptance criteria (brief §5)

Walking each of the 7 acceptance-criteria checkboxes in `docs/development-brief.md` §5, plus the program-level trigger-validation checkbox, against the actual evidence produced during Tasks 1–13. Marked honestly: `partial — <reason>` where full end-to-end proof wasn't obtained in this environment, not silently passed.

1. **W2 on Laravel + Node fixture (SBOM, diff, scan, triage drafts, dossier update, in one invocation).**
   **partial** — each script in the W2 chain was independently verified against both fixtures: `gen_sbom.sh` on `node-minimal` and `laravel-minimal` (Task 4, see `gen_sbom.sh` section above, 4a/4b), `diff_sbom.py` on deterministic old/new fixtures (Task 5 Step 4 test 1: added axios, removed left-pad, changed lodash), `scan_vulns.sh` on both fixtures (Task 6 Step 3: 6 lodash findings / 7 guzzle findings). Triage-draft generation and dossier update are defined in SKILL.md W2 steps 4–5 but were **not exercised as a single live skill invocation** in this session — that requires an actual Claude Code session against a real repo, which is exactly the still-open OQ-2 (demo repo not yet picked). Script-level building blocks are proven; full-workflow orchestration is not.

2. **SBOM diff correctly identifies added/removed/version-changed components.**
   **PASS** — Task 5 Step 4 test 1: `diff_sbom.py old.cdx.json new.cdx.json` on hand-built fixtures correctly reported Added(1): axios 1.7.0; Removed(1): left-pad 1.3.0; Changed(1): lodash 4.17.15→4.17.21; unchanged guzzlehttp/guzzle correctly absent from the diff. Also confirmed against real syft output (test 5, node-minimal → polyglot).

3. **Gap report: 100% checklist coverage, three-state, no silent skips.**
   **partial** — the rule is enforced structurally: SKILL.md W3 step 2 requires exactly one state (conformant/gap/not applicable) per item with no skips, and step 3 forbids a bare "compliant". `cra_annex1_checklist.md` was verified to contain exactly 22 items (`grep -c '^- \*\*' ... → 22`, Task 9). What was **not** executed: an actual W3 run against a real repo producing all 22 states. Rule + inventory are verified; a live run is not (same OQ-2 gap as #1).

4. **Missing external tool → actionable message + install hint, not a stack trace.**
   **PASS** — all three tool-dependent scripts verified directly: `gen_sbom.sh` missing-syft path (Task 4 Step 5, exit 127 + "syft not found" + brew hint), `scan_vulns.sh` missing-scanner path (Task 6 Step 4, exit 127 + both grype and osv-scanner install hints), `a11y_scan.sh` missing-npx path (Task 7 Step 3, exit 127 + "Install Node.js: brew install node"). No stack traces in any case.

5. **No artifact ever autonomously labeled Accepted/Compliant; templates default to Proposed.**
   **PASS** — `grep -rniE '\*\*status:\*\* *(accepted|compliant|final)' skills/cra-evidence/SKILL.md skills/cra-evidence/references/ skills/cra-evidence/assets/` returns exit 1 (no matches; re-run in this task, widening Task 8 Step 4's original assets-only grep to the whole skill). SKILL.md's Core contract rule 1 states the constraint explicitly ("NEVER mark anything Accepted, Compliant, Conformant-final... only after explicit human confirmation"). Templates default to `Draft`/`Proposed` (Task 8).

6. **Dossier readable by a non-developer (external counsel).**
   **partial** — `assets/dossier_template.md` structurally matches the brief's requirement: section 1 ("Product identification") leads with a plain-language one-line product description before any technical content, and SKILL.md's closing "Language and tone" section mandates plain-language summaries first, technical pointers second, for all generated dossier prose. This is a design/structure review, not a usability test — no actual non-developer/external-counsel reader has evaluated a generated dossier, because none has been generated against a real repo yet (OQ-2).

7. **Trigger validation: skill triggers from natural phrasing, ≥5 trigger / ≥5 non-trigger prompts.**
   **PASS** — `tests/trigger-validation.md`: 10 prompts per skill (5 trigger / 5 non-trigger minimum, exceeded), 20/20 rows pass against the actual `description:` frontmatter text. The specific cross-trigger risk flagged by prior review (cra-evidence's "dependencies or vulnerabilities are the topic" phrasing vs. adr-management's territory) was checked deliberately and does not cause a false trigger in either direction; no description edit was required.

8. **Both skills installable (per-repo distribution).**
   **partial** — `cra-evidence` portability was empirically verified: `gen_sbom.sh` executed successfully from a scratch `.claude/skills/cra-evidence/` copy with relative paths intact (Task 11 Step 3). `adr-management`'s `new_adr.sh` uses the identical self-relative path-resolution pattern (`SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)`, verified by reading the script) and has additionally already run as a standalone personal-scope pilot per `docs/development-brief.md` ("adr-management skill — already in pilot"), but it was **not** re-executed via a scratch-copy test in this repo's task sequence. `docs/distribution.md` documents install steps and the "why a plain copy works" rationale for both. Confidence is high but the adr-management half rests on code reading + prior pilot history rather than a fresh execution in this environment.

**Not covered by brief §5 but relevant to overall program readiness (flagged, not a checkbox failure):** OQ-2 (picking the real demo repo and running the full W1→W5 loop once) remains open per `docs/development-brief.md` §10 — this is explicitly Andrea's call, not something this task can resolve. The osv-scanner fallback branch in `scan_vulns.sh` (Task 6) was verified by code reading only, since osv-scanner isn't installed on this machine. The axe-core successful-scan path (violations detected in JSON output) was not exercised live due to a ChromeDriver 150 / Chrome 149 mismatch; the graceful-degradation path was exercised and confirmed instead (Task 7, a11y_scan.sh section above).
