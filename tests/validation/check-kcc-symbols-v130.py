#!/usr/bin/env python3
"""Audit exported PDP-6 assembly names for KCC's 31-character limit.

Source-only check: it does not replace native compiler/linker tests.
"""
import argparse
import pathlib
import re
import sys

GLOBAL = re.compile(r"^\s*\.globl\s+([A-Za-z_][A-Za-z_0-9]*)", re.M)


def scan(root):
    errors = []
    symbols = {}
    for path in sorted((root / "system" / "kernel").rglob("*.s")):
        source = path.read_text(encoding="ascii", errors="replace")
        for match in GLOBAL.finditer(source):
            name = match.group(1)
            if len(name) > 31:
                errors.append(f"{path.relative_to(root)}: {name}: {len(name)} > 31")
            key = name[:31]
            previous = symbols.get(key)
            if previous is not None and previous != name:
                errors.append(f"KCC collision: {previous} / {name}")
            symbols[key] = name
    return sorted(set(errors))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("repository", type=pathlib.Path)
    args = parser.parse_args()
    errors = scan(args.repository.resolve())
    for error in errors:
        print(error, file=sys.stderr)
    print(f"KCC exported assembly symbol check: {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
