#!/usr/bin/env python3
"""diff_sbom.py — component-level diff between two CycloneDX JSON SBOMs.

Usage: diff_sbom.py OLD.cdx.json NEW.cdx.json [--json]

Prints a Markdown diff (Added / Removed / Version changed) to stdout,
or a JSON object with --json. Components are keyed by "group/name"
(group omitted when absent). Exit codes: 0 ok, 1 unreadable/invalid input, 2 usage.
"""
import json
import sys


def load_components(path):
    try:
        with open(path, encoding="utf-8") as f:
            doc = json.load(f)
    except (OSError, json.JSONDecodeError, UnicodeDecodeError) as e:
        print(f"ERROR: cannot read SBOM {path}: {e}", file=sys.stderr)
        sys.exit(1)

    if not isinstance(doc, dict) or not isinstance(doc.get("components", []), list):
        print(f"ERROR: not a CycloneDX SBOM document: {path}", file=sys.stderr)
        sys.exit(1)

    comps = {}
    for c in doc.get("components", []):
        if not isinstance(c, dict):
            continue
        name = c.get("name", "")
        group = c.get("group") or ""
        key = f"{group}/{name}" if group else name
        comps[key] = c.get("version", "")
    return comps


def main():
    as_json = "--json" in sys.argv[1:]
    args = [a for a in sys.argv[1:] if a != "--json"]
    if len(args) != 2:
        print("Usage: diff_sbom.py OLD.cdx.json NEW.cdx.json [--json]", file=sys.stderr)
        sys.exit(2)

    old, new = load_components(args[0]), load_components(args[1])
    added = sorted(k for k in new if k not in old)
    removed = sorted(k for k in old if k not in new)
    changed = sorted(k for k in new if k in old and new[k] != old[k])

    if as_json:
        print(json.dumps({
            "added": [{"component": k, "version": new[k]} for k in added],
            "removed": [{"component": k, "version": old[k]} for k in removed],
            "changed": [{"component": k, "old": old[k], "new": new[k]} for k in changed],
        }, indent=2))
        return

    print(f"## SBOM diff\n\n`{args[0]}` → `{args[1]}`\n")
    if not (added or removed or changed):
        print("No component changes between the two SBOMs.")
        return
    print(f"### Added ({len(added)})\n")
    for k in added:
        print(f"- `{k}` {new[k]}")
    print(f"\n### Removed ({len(removed)})\n")
    for k in removed:
        print(f"- `{k}` {old[k]}")
    print(f"\n### Version changed ({len(changed)})\n")
    for k in changed:
        print(f"- `{k}` {old[k]} → {new[k]}")


if __name__ == "__main__":
    main()
