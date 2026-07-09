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
