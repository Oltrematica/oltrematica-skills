# Security Policy

## Threat model — read this before you install anything from this repo

This repository ships **Claude Code skills and hooks**: bash and Python
scripts, plus a `hooks/hooks.json` that wires two of those scripts into
`PostToolUse` and `Stop` events. When installed, these scripts execute
**on your machine, with your user's full permissions**, and some of them
(the hooks) run automatically, without an explicit invocation, as part of
every Claude Code session in a repo where they're active.

Be plain-eyed about what that means:

- **A skill or hook is arbitrary code execution by design.** There is no
  sandbox between a shell script in this repo and your filesystem,
  credentials, network access, or anything else your user account can touch.
  That is not a bug to be patched — it is what a skill *is*. A malicious or
  compromised skill is indistinguishable, mechanically, from a malicious
  `npm postinstall` script or a malicious shell alias: it runs as you.
- **These scripts read model-influenced JSON.** The hooks parse
  tool-call transcripts and session state that an LLM produced as part of an
  agentic session. That input is not adversarially hardened the way you'd
  harden a public HTTP API — it is trusted in the same sense a build script
  trusts its own build output. We treat it defensively (see below), but you
  should not assume it has been treated the way you'd treat untrusted input
  from the public internet.
- **Installing a skill is installing code, not configuring a setting.**
  `scripts/install.sh` copies files into `.claude/skills/` or your plugin
  directory. Read what you are about to install — the SKILL.md, the
  `scripts/` directory, and especially `hooks/hooks.json` and anything it
  points at — the same way you would review a dependency before running
  `npm install` or `pip install` from an unfamiliar source. We do not expect
  you to trust this repo by default, and neither should you trust any other
  skills repo, ours included, without reading it first.

Given that, what we do to reduce risk on our side:

- No network calls from any script in this repo. Everything operates on
  local files, local git state, and locally-installed CLI tools
  (`syft`, `grype`, `osv-scanner`, `npx @axe-core/cli`) that you must
  separately choose to install.
- No new runtime dependencies without deliberate review — see
  [`CONTRIBUTING.md`](CONTRIBUTING.md). Every script is `bash` or
  `python3` stdlib only.
- Every script has a contract test (`tests/**/*.test`) run in CI on both
  `ubuntu-latest` and `macos-latest` on every push and PR.
- Hooks degrade loudly and fail open rather than silently succeeding on
  malformed input — see
  [`docs/harness/verification-gate.md`](docs/harness/verification-gate.md)
  for the documented limits of what the verification gate can and cannot
  guarantee.

None of that changes the fundamental fact above: this is code that runs with
your permissions. Treat it accordingly.

## Supported versions

This repo does not version-tag releases at present; the `main` branch is the
supported line. Security fixes land there and are not backported to
historical commits.

## Reporting a vulnerability

If you find a security issue — a script that can be made to write outside
its intended scope, a hook that can be tricked into executing attacker-
controlled content, path traversal in the installer, or anything else that
lets this repo's code do more than a reader of `SKILL.md`/`hooks.json` would
reasonably expect — please report it privately rather than opening a public
issue.

**Email: opensource@oltrematica.dev**

Please include:

- The script or hook affected, and the version/commit you tested against.
- Steps to reproduce, or a minimal proof-of-concept input.
- What you'd expect to happen versus what actually happens.
- Your assessment of impact (what an attacker gains, and what they need
  to already control to trigger it).

We will acknowledge your report and aim to provide an initial assessment
within 5 business days. We will credit you in the fix's commit message or
release notes unless you ask us not to.

## Out of scope

- Vulnerabilities in third-party tools this repo shells out to (`syft`,
  `grype`, `osv-scanner`, `@axe-core/cli`, Claude Code itself) — report
  those upstream.
- Findings that require an attacker to already have arbitrary code
  execution on the machine running Claude Code (at that point, the threat
  model above already applies — there is nothing this repo's own hardening
  can add).
- Social-engineering reports about skill descriptions being "misleading" in
  the abstract — if you find a description that causes a skill to fire on
  content it should not, that's a bug report for
  [`CONTRIBUTING.md`](CONTRIBUTING.md)'s trigger-testing process, not a
  security report.
