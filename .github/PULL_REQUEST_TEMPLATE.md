## What changes and why

<!-- One or two sentences. Link an issue if there is one. -->

## How to test

<!-- The exact command(s) a reviewer runs to see this work. -->

## Checklist

- [ ] All test suites are green locally, run with an explicit `bash`
      (`/bin/bash tests/harness/*.test`, `/bin/bash tests/install.sh.test`) —
      not just the ones I touched.
- [ ] If a skill's `description:` frontmatter changed, I re-ran (or ran for
      the first time) the trigger-validation quorum per
      [`CONTRIBUTING.md`](../CONTRIBUTING.md) / the `harness-eval` skill, and
      the updated evidence table is included in this PR
      (`tests/<track>/trigger-validation.md`).
- [ ] No new runtime dependencies (`pip install`, `npm install`, or any
      vendored library) were added without prior maintainer sign-off.
- [ ] Every new or changed script under `scripts/` or `hooks/scripts/` has a
      matching contract test (`*.test`) exercising it standalone.
- [ ] Docs updated if this touches a public surface (`README.md`,
      `docs/`, a skill's `SKILL.md`/`README.md`).
- [ ] Commit messages follow `type(scope): subject`, ≤72 characters.

## Breaking changes

<!-- None, or describe what breaks and for whom. -->
