#!/usr/bin/env python3
"""source_mutation.py — did this Bash command mutate a source file on disk?

record_activity.sh (PostToolUse, matcher `Bash`) previously recorded
`last_source_edit` only for the `Write|Edit|NotebookEdit` tools. A source
edit made THROUGH Bash — `sed -i`, `cat > file`, a heredoc, `tee`, `cp`,
`mv`, `patch`, `dd`, `install`, `truncate`, or a `python3 -c` one-liner that
writes — was invisible to the gate: `last_source_edit` stayed 0, and the
Stop hook's own `[ "$LAST_EDIT" -eq 0 ] && exit 0` short-circuit fired
before it ever compared timestamps. This module closes that hole. See
docs/harness/verification-gate.md for the user-facing writeup, including
the residual gap this does NOT close.

Why a heuristic over the command TEXT, not a real shell parser: this is the
same simplification skills/harness/harness-audit/scripts/lib/verify_gate.sh's
is_test_command already accepts and documents for its own command-position
matching (no quote-tracking, no `&&`/`||` short-circuit evaluation — see its
"KNOWN LIMITATION" comment on `false && composer test`). A full shell parser
is out of scope for a PostToolUse hook that must stay fast and dependency-free.

FAIL TOWARD RECORDING. Two asymmetric failure modes:
  - a MISS (a real source mutation not detected) is the exact hole this
    module exists to close — a false "nothing changed".
  - a FALSE POSITIVE makes the Stop hook slightly more cautious (it may ask
    for one more unnecessary test run) — annoying, never unsafe.
Whenever a command's SHAPE says "this mutates a file" but the exact target
path cannot be pinned down (an inline `patch`, a `dd of=` we can't parse, a
`python3 -c` script whose write target isn't a string literal), this module
reports a mutation anyway rather than silently doing nothing. That is a
deliberate policy, not a gap in the parsing.

Python stdlib only. Never raises: any unexpected input degrades to "no
mutation detected" (exit 1) — a recorder must never crash the hook it is
piggybacking on, and a missed recording is the direction that fails open.

Usage: source_mutation.py <command> <is_test_command: "1"|"0">
Exit 0 -> a source file was (probably) mutated by this command.
Exit 1 -> no source mutation detected.
"""
import re
import shlex
import sys

# cp/mv/touch/patch/dd/install/truncate always write when they run at all —
# no flag gates it the way sed/perl's `-i` does.
MUTATING_VERBS_UNCONDITIONAL = {"cp", "mv", "touch", "patch", "dd", "install", "truncate"}

# sed/perl only mutate the file IN PLACE with -i; without it they print to
# stdout and touch nothing on disk.
MUTATING_VERBS_DASH_I = {"sed", "perl"}

# Same "skip a single leading wrapper" allowance as verify_gate.sh's
# _vg_segment_runs_tests (`sudo`, `env`, `time`, `nice`, `npx`).
WRAPPERS = {"sudo", "env", "time", "nice", "npx"}

# A `#` starts a comment when it begins a word (start of segment, or
# preceded by whitespace) — same rule as verify_gate.sh's
# _vg_strip_comments, reimplemented here because that function is bash, not
# a library this script can import.
_COMMENT_RE = re.compile(r"(^|\s)#.*")


def _strip_comments(cmd: str) -> str:
    return _COMMENT_RE.sub(lambda m: m.group(1), cmd)


# Split on shell control operators — `;`, `&&`, `||`, a lone `|`, a lone
# `&`, and newlines — the same set verify_gate.sh's is_test_command splits
# on. `&`/`|` immediately adjacent to `>` are deliberately NOT split points,
# so `2>&1`, `1>&2`, `&>`, `&>>` survive intact for the redirect scan below
# instead of being shredded into meaningless fragments.
#
# UNLIKE verify_gate.sh's is_test_command (which splits with a plain `tr`
# and accepts that a literal `;`/`|`/`&` inside a quoted string over-splits
# a segment), this DOES track quote state while scanning. Reason: a Bash
# one-liner that mutates a file is disproportionately likely to carry a
# control character inside a quoted script argument (`python3 -c "...;
# ..."`, `sed -i '' 's/a;b/c/'`) — a naive split would sever the quoted
# script apart, corrupt its quoting, and make `-c`'s script argument
# unrecoverable, turning a real "does this write?" signal into a miss. A
# missed mutation is exactly the hole this module exists to close, so the
# extra quote-tracking here (not present in the simpler is_test_command,
# which only ever needs to recognise a verb at segment-start) is
# deliberate, not an inconsistency.
_ENV_ASSIGN_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=\S*\s+(.*)$")

_DOC_DIR_RE = re.compile(r"(^|/)docs/")


def _segments(cmd: str):
    """Split on `;` `&&` `||` `|` `&` and newlines, but never inside a
    single- or double-quoted string, so a control character quoted as part
    of a script argument survives intact."""
    segs = []
    buf = []
    i, n = 0, len(cmd)
    quote = None
    while i < n:
        c = cmd[i]
        if quote:
            buf.append(c)
            if c == quote:
                quote = None
            elif quote == '"' and c == "\\" and i + 1 < n:
                i += 1
                buf.append(cmd[i])
            i += 1
            continue
        if c in ("'", '"'):
            quote = c
            buf.append(c)
            i += 1
            continue
        if c == "\\" and i + 1 < n:
            buf.append(c)
            buf.append(cmd[i + 1])
            i += 2
            continue
        if cmd[i:i + 2] in ("&&", "||"):
            segs.append("".join(buf)); buf = []; i += 2
            continue
        if c in (";", "\n"):
            segs.append("".join(buf)); buf = []; i += 1
            continue
        if c in ("|", "&"):
            prev_ch = cmd[i - 1] if i > 0 else ""
            next_ch = cmd[i + 1] if i + 1 < n else ""
            if prev_ch != ">" and next_ch != ">":
                segs.append("".join(buf)); buf = []; i += 1
                continue
            buf.append(c); i += 1
            continue
        buf.append(c)
        i += 1
    segs.append("".join(buf))
    return segs


def _strip_leading(seg: str) -> str:
    seg = seg.strip()
    while True:
        m = _ENV_ASSIGN_RE.match(seg)
        if not m:
            break
        seg = m.group(1)
    parts = seg.split(None, 1)
    if parts and parts[0] in WRAPPERS and len(parts) > 1:
        seg = parts[1]
    return seg.strip()


def _tokens(seg: str):
    try:
        return shlex.split(seg, posix=True)
    except ValueError:
        # unbalanced quote etc. — degrade to a naive split rather than crash
        return seg.split()


def _is_excluded_path(path):
    """Same source-file rule record_activity.sh already applies to
    Write/Edit/NotebookEdit paths: not *.md, not LICENSE, not under docs/.
    `path is None` means "mutating command, target unknown" — NOT excluded,
    per the fail-toward-recording policy above."""
    if path is None:
        return False
    if path.endswith(".md"):
        return True
    if path == "LICENSE" or path.endswith("/LICENSE"):
        return True
    if path.startswith("docs/") or _DOC_DIR_RE.search(path):
        return True
    return False


_WRITE_HINTS = re.compile(
    r"open\([^)]*['\"][wax]b?['\"]"
    r"|\.write\("
    r"|\.write_text\("
    r"|\.write_bytes\("
    r"|shutil\.(copy|move)\("
    r"|os\.rename\(",
)


def _verb_candidates(seg: str, whole_is_test_command: bool):
    """Yield candidate target paths (None means 'mutating, path unknown')
    for one already-segmented piece of the command line, or nothing if this
    segment does not mutate a file at all."""
    seg = _strip_leading(seg)
    if not seg:
        return
    tokens = _tokens(seg)
    if not tokens:
        return
    verb = tokens[0]

    if verb == "tee":
        # `tee <file>` inside a command that ALSO runs the test suite
        # (e.g. `composer test 2>&1 | tee out.txt`) is capturing that test
        # run's own output, not editing source — exempted, deliberately,
        # only in that combination (see docs/harness/verification-gate.md).
        # `tee` on its own, with no accompanying test command in the same
        # invocation, still counts: it is exactly as much a file write as
        # `cat > file`.
        if whole_is_test_command:
            return
        targets = [t for t in tokens[1:] if not t.startswith("-")]
        if not targets:
            yield None
            return
        for t in targets:
            yield t
        return

    if verb in MUTATING_VERBS_DASH_I:
        if not any(t == "-i" or t.startswith("-i") for t in tokens[1:]):
            return  # sed/perl without -i never touches the file on disk
        non_flags = [t for t in tokens[1:] if not t.startswith("-")]
        yield non_flags[-1] if non_flags else None
        return

    if verb in MUTATING_VERBS_UNCONDITIONAL:
        if verb == "dd":
            for t in tokens[1:]:
                if t.startswith("of="):
                    yield t[len("of="):]
                    return
            yield None  # `dd` with no parseable of= — still mutates something
            return
        non_flags = [t for t in tokens[1:] if not t.startswith("-")]
        yield non_flags[-1] if non_flags else None
        return

    if verb in ("python", "python3"):
        if "-c" in tokens:
            i = tokens.index("-c")
            script = tokens[i + 1] if i + 1 < len(tokens) else ""
            if _WRITE_HINTS.search(script):
                # Extracting the exact filename out of arbitrary python
                # source is unreliable — record the mutation, not a guess
                # at the path (fail-toward-recording).
                yield None
        return


# Matches a redirect operator (`>` or `>>`) that is NOT part of an `N>&M`
# fd-duplication (`2>&1`, `1>&2`, ...), and captures the token right after
# it as the candidate write target. `&>`/`&>>` (redirect both streams to a
# FILE) are real file writes and are intentionally matched, not excluded —
# only the digit-ampersand-digit fd-dup shape is not a file at all.
_REDIRECT_RE = re.compile(r"(?<![\w>])(?:\d*)(?:>{1,2})(?!&)\s*(\S+)")

_EXEMPT_TARGETS = {"/dev/null", "/dev/stdout", "/dev/stderr"}


def _redirect_candidates(cmd: str):
    for m in _REDIRECT_RE.finditer(cmd):
        target = m.group(1).strip("'\"")
        if not target or target.startswith("&"):
            continue  # fd duplication, not a file
        if target in _EXEMPT_TARGETS:
            continue
        if target.startswith("/tmp/") or target.startswith("/private/tmp/") or target in ("/tmp", "/private/tmp"):
            continue
        yield target


def mutates_source(cmd: str, whole_is_test_command: bool) -> bool:
    cmd = _strip_comments(cmd)
    for seg in _segments(cmd):
        for candidate in _verb_candidates(seg, whole_is_test_command):
            if not _is_excluded_path(candidate):
                return True
    for candidate in _redirect_candidates(cmd):
        if not _is_excluded_path(candidate):
            return True
    return False


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(1)
    cmd = sys.argv[1]
    whole_is_test = len(sys.argv) > 2 and sys.argv[2] == "1"
    try:
        sys.exit(0 if mutates_source(cmd, whole_is_test) else 1)
    except Exception:
        sys.exit(1)  # fail open: never crash the recorder


if __name__ == "__main__":
    main()
