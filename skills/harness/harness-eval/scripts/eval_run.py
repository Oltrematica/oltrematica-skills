#!/usr/bin/env python3
"""eval_run.py — validate a harness eval spec and render its results table.

This script does the deterministic half of an eval: it checks the spec is
well-formed and worth running, and renders the table Claude fills in.

It does NOT judge whether a skill fired. That judgement is the model's, made by
dispatching each prompt to a fresh subagent — see SKILL.md. A script cannot do it,
and a script that pretended to would be the worst kind of evidence: confident and
wrong.

Usage:
  eval_run.py --validate   <spec.json>   exit 0 if valid, 2 with reasons if not
  eval_run.py --emit-table <spec.json>   markdown results table on stdout

Spec format:
  {
    "skills": [
      {"name": str,
       "prompts": [{"prompt": str, "expect": "trigger" | "no-trigger"}, ...]}
    ],
    "regressions": [{"prompt": str, "expect_observable": str}, ...]   # optional
  }

Python stdlib only. No dependencies.

Robustness notes (this reads user-authored JSON, which can be malformed in any
way a human can type):
- `spec` itself may not be a dict (e.g. `null`, a bare list, a number/string) —
  checked before anything calls `.get()` on it.
- Any `skills[i]`, prompt entry, or `regressions[i]` may not be a dict either —
  each is type-checked before `.get()` is called on it.
- `prompts` / `regressions` may be missing or of the wrong type entirely.
- A `prompt` may be missing, non-string, empty, or whitespace-only.
- A prompt containing a literal `|` would otherwise corrupt the markdown table
  emitted by --emit-table; it is escaped.
- The spec file may not exist, may be a directory, may not be valid UTF-8, or
  may not be valid JSON — each produces one actionable stderr line, never a
  traceback.
"""
import argparse
import json
import sys

MIN_PER_CLASS = 5
VALID_EXPECT = ("trigger", "no-trigger")


def load(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except FileNotFoundError:
        print(f"ERROR: spec not found: {path}", file=sys.stderr)
        sys.exit(2)
    except IsADirectoryError:
        print(f"ERROR: spec path is a directory, not a file: {path}", file=sys.stderr)
        sys.exit(2)
    except json.JSONDecodeError as exc:
        print(f"ERROR: spec is not valid JSON: {path}\n  {exc}", file=sys.stderr)
        sys.exit(2)
    except (OSError, UnicodeDecodeError) as exc:
        print(f"ERROR: could not read spec: {path}\n  {exc}", file=sys.stderr)
        sys.exit(2)


def validate(spec, path):
    """Return a list of human-readable problems. Empty list means valid."""
    problems = []

    if not isinstance(spec, dict):
        return [
            f"{path}: spec must be a JSON object with a 'skills' key "
            f"(got {type(spec).__name__})"
        ]

    skills = spec.get("skills")
    if not isinstance(skills, list) or not skills:
        return [f"{path}: 'skills' must be a non-empty list"]

    for i, skill in enumerate(skills):
        if not isinstance(skill, dict):
            problems.append(
                f"skills[{i}]: each skill must be a JSON object (got {type(skill).__name__})"
            )
            continue

        name = skill.get("name") or f"<skills[{i}] has no name>"
        prompts = skill.get("prompts")
        if not isinstance(prompts, list):
            problems.append(f"{name}: 'prompts' must be a list")
            continue

        counts = {"trigger": 0, "no-trigger": 0}
        seen = set()
        for entry in prompts:
            if not isinstance(entry, dict):
                problems.append(
                    f"{name}: each prompt entry must be a JSON object "
                    f"(got {type(entry).__name__})"
                )
                continue
            text = entry.get("prompt")
            expect = entry.get("expect")
            if not isinstance(text, str) or not text.strip():
                problems.append(f"{name}: an entry has no non-empty 'prompt' string")
                continue
            if expect not in VALID_EXPECT:
                problems.append(
                    f"{name}: prompt {text!r} has expect={expect!r}; "
                    f"must be one of {VALID_EXPECT}"
                )
                continue
            if text in seen:
                problems.append(f"{name}: duplicate prompt {text!r}")
                continue
            seen.add(text)
            counts[expect] += 1

        for expect in VALID_EXPECT:
            if counts[expect] < MIN_PER_CLASS:
                problems.append(
                    f"{name}: only {counts[expect]} {expect!r} prompts; "
                    f"at least {MIN_PER_CLASS} are required. A description tested "
                    f"on fewer cases has not been tested."
                )

    regressions = spec.get("regressions", [])
    if not isinstance(regressions, list):
        problems.append("regressions: must be a list")
    else:
        for i, entry in enumerate(regressions):
            if (
                not isinstance(entry, dict)
                or not entry.get("prompt")
                or not entry.get("expect_observable")
            ):
                problems.append(
                    f"regressions[{i}]: each entry needs both 'prompt' and "
                    f"'expect_observable'"
                )

    return problems


def emit_table(spec):
    out = []
    for skill in spec["skills"]:
        out.append(f"## {skill['name']}")
        out.append("")
        out.append("| # | Prompt | Expected | Verdict | Judges |")
        out.append("|---|--------|----------|---------|--------|")
        for n, entry in enumerate(skill["prompts"], start=1):
            prompt = entry["prompt"].replace("|", "\\|")
            out.append(f"| {n} | \"{prompt}\" | {entry['expect']} | | |")
        out.append("")

    regressions = spec.get("regressions", [])
    if regressions:
        out.append("## Behavioral regressions")
        out.append("")
        out.append("| # | Prompt | Expected observable | Before | After |")
        out.append("|---|--------|---------------------|--------|-------|")
        for n, entry in enumerate(regressions, start=1):
            prompt = entry["prompt"].replace("|", "\\|")
            expected = entry["expect_observable"].replace("|", "\\|")
            out.append(f"| {n} | \"{prompt}\" | {expected} | | |")
        out.append("")

    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--validate", metavar="SPEC")
    group.add_argument("--emit-table", metavar="SPEC")
    args = parser.parse_args()

    path = args.validate or args.emit_table
    spec = load(path)

    try:
        problems = validate(spec, path)
    except Exception as exc:  # noqa: BLE001 - last-resort guard against a traceback
        print(f"ERROR: spec is malformed and could not be validated: {path}", file=sys.stderr)
        print(f"  {exc}", file=sys.stderr)
        sys.exit(2)

    if problems:
        print("Spec is not valid:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        sys.exit(2)

    if args.validate:
        print(f"OK: {path} is a valid eval spec")
        return

    try:
        print(emit_table(spec))
    except Exception as exc:  # noqa: BLE001 - validate() passed, this should not happen
        print(f"ERROR: could not render table for: {path}", file=sys.stderr)
        print(f"  {exc}", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
