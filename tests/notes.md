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
