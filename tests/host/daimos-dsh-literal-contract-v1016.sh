#!/bin/sh
# Guard the cold DSH helper whose callers provide uppercase fixed literals.
set -eu

: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"
python3 - "$DAIMOS_REPO/userland/dsh/dsh.c" <<'PY'
import pathlib
import re
import sys

source = pathlib.Path(sys.argv[1]).read_text(encoding="ascii")
calls = [line.strip() for line in source.splitlines()
         if "dsh_s6_literal(&" in line]
direct = re.compile(r'"[A-Z0-9/._-]+"\Z')
choice = re.compile(r'\w+\s*\?\s*"[A-Z0-9/._-]+"\s*:\s*"[A-Z0-9/._-]+"\Z')

if len(calls) != 5:
    raise SystemExit("FAIL: expected 5 fixed DSH literal call sites, found %d" % len(calls))

for line in calls:
    argument = line.split("dsh_s6_literal(&", 1)[1].split(")", 1)[0]
    argument = argument.split(",", 1)[1].strip()
    if not direct.fullmatch(argument) and not choice.fullmatch(argument):
        raise SystemExit("FAIL: dynamic or lowercase literal argument: " + line)

print("PASS: 5 DSH helper callers use fixed uppercase literals")
PY
