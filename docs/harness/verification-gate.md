# The verification gate: what it does and does not guarantee

This is the plain-language contract for the Stop-hook verification gate
(`hooks/scripts/verify_before_done.sh` + `hooks/scripts/record_activity.sh`,
installed by the plugin — see [Distribution](../distribution.md)). Read this
before you rely on it. Honest limitations are worth more than a page that
only shows the gate working.

## What it does

The gate blocks an agent from ending its turn with a completion claim
("Done.", "All tests pass.", "That's fixed.", ...) when **a source file was
modified after the last passing test run** in that session. It does nothing
else. No secrets scanning, no dependency blocking, no main-branch
protection, no auto-formatting, no cost coaching — those were deliberately
cut from this change (see the design spec's non-goals) so this hook stays
one rule, easy to reason about, and easy to trust.

When it blocks, the agent sees exactly one instruction: run the test
command and report the real output. That is the entire escape hatch. There
is no override flag and no way to satisfy the gate other than actually
running the tests.

## Why "passed", not merely "ran"

`record_activity.sh` records a test run as **passed**, not just attempted,
without ever inspecting an exit code or grepping output for "FAILURES!" —
there is no exit-code field available to it in the first place. It relies on
a **documented Claude Code contract**: `PostToolUse` fires only after a tool
call succeeds; a failing Bash command gets a separate `PostToolUseFailure`
event instead. So if this hook fires at all for a command matching the
repo's test runner, that command already exited zero. This was verified
empirically too (six isolated runs, both orderings, realistic
failing-test-runner output, zero exceptions — `tests/harness/notes.md`), on
top of being the platform's stated behavior. This is sound, and deliberate —
if a future Claude Code version changes when `PostToolUse` fires, this
inference has to move with it, but that is a documented compatibility
concern, not a silently-relied-upon quirk. Don't "fix" this by adding an
exit-code check; there isn't one to add.

## What it does NOT catch

Be specific with yourself about these before you trust the gate more than
it has earned:

- **Bash-mediated source edits, when the command shape doesn't say so.**
  `record_activity.sh` recognizes edits made through common Bash patterns —
  `sed -i`, `perl -i`, `cat > file`, a heredoc, `tee`, `cp`, `mv`, `touch`,
  `patch`, `dd`, `install`, `truncate`, a `python3 -c` one-liner that writes
  — by pattern-matching the command TEXT, not by parsing a real shell. It is
  not a shell interpreter: it does not track quoting fully in every case, it
  does not evaluate `&&`/`||` short-circuiting, and an exotic or obfuscated
  way of writing to disk (a custom wrapper script, a language runtime other
  than the ones listed, a redirect buried inside a heredoc body that merely
  *looks* like one) can still slip through undetected. Where the detector
  can tell a command's *shape* mutates a file but can't pin down *which*
  file, it records a mutation anyway — false alarms are the safe direction
  here, a missed edit is not.
- **Second-granularity timestamps.** State is recorded to the nearest
  second. Two events in the same second read as simultaneous, and a tie is
  **allowed** (`last_test_pass >= last_source_edit`, not strictly greater).
  A test run and an edit that land in the same wall-clock second will not
  trigger a block.
- **Phrasings the claim detector's regex doesn't recognize.**
  `hooks/scripts/lib/claims.py` is a regex, not a language model. It has
  already missed a real completion claim once, in a 30-sample blind quorum
  of independent judges used to grade it (`tests/harness/trigger-validation.md`,
  Task 7) — a message reporting "the migration issue is fixed... everything
  is green" wasn't sentence-initial and slipped past the original pattern.
  That specific gap was found and fixed, but a regex detector can always be
  written around by different phrasing than the corpus tested — there is no
  claim this is exhaustive. A miss here means the gate stays silent, not
  that it blocks something it shouldn't.
- **`false && composer test`.** The command-position matcher that decides
  whether a Bash call "ran the tests" checks whether a segment of the
  command line *starts with* a test-runner invocation — it does not
  evaluate the shell, so it cannot tell that a preceding `&&` short-circuited
  the test command away at runtime. This is a documented, accepted gap in
  `skills/harness/harness-audit/scripts/lib/verify_gate.sh` — deliberate
  sabotage of the gate is out of scope for a hook whose job is to catch an
  honest oversight, not an adversarial agent.

## It fails open, by design

Anything the gate does not understand — malformed input, a missing state
file, a repo with no detectable test command, an unreadable path — is
treated as "allow", never "block". The Stop hook's own contract with the
platform is stricter than that: it may only ever exit `0` (allow) or `2`
(block); it never uses exit `1`, because Claude Code treats that as a
silent, non-blocking failure that *looks* like it ran correctly but
enforced nothing. A hook that blocks because it is broken is a hook that
gets uninstalled, and then it enforces nothing, forever, with nobody
noticing. Failing open on uncertainty is what keeps it trustworthy enough to
leave turned on.

## How to satisfy it

Run the tests. That's it. If they pass, say so and finish. If they fail,
fix the code and run them again. There is no other way to clear the gate,
and that is intentional.
