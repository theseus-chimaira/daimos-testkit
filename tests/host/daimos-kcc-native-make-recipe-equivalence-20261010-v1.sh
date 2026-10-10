#!/bin/sh
# Verify native KCC compilation recipes against the pre-compaction baseline.
set -eu
kcc=${KCC_REPO:-"$HOME/git/kcc"}
python3 - "$kcc" <<'PY'
from pathlib import Path
import re
import subprocess
import sys

root = Path(sys.argv[1])
original = subprocess.check_output(
    ["git", "-C", str(root), "show", "0b4ae44:daimos.mk"], text=True
)
current = (root / "daimos.mk").read_text()
flags = (
    "-Pgnu99 -x=pdp6 -m=gas -DHOST_DAIMOS=1 -DHOST_UNIX=0 "
    "-I/OPTION/SOURCE/KCC/SELF/INCLUDE -I/OPTION/SOURCE/KCC/ABI"
)
assert "KCC_NATIVE_FLAGS = " + flags in current

def compilations(source):
    result = {}
    lines = source.splitlines()
    for i, line in enumerate(lines):
        if not re.match(r"^(?:B|BUILD)/[A-Z0-9-]+\.S:", line):
            continue
        target = line.split(":", 1)[0]
        j = i + 1
        while j < len(lines) and (lines[j].startswith("    ") or not lines[j].strip()):
            j += 1
        if j == len(lines) or "/EXEC/KCC -S " not in lines[j]:
            continue
        command = lines[j].replace("$@", target).replace(
            "$(KCC_NATIVE_FLAGS)", flags
        )
        result[target.replace("B/", "BUILD/")] = command.replace(
            "-O B/", "-O BUILD/"
        )
    return result

before = compilations(original)
after = compilations(current)
assert len(before) == 53, len(before)
assert before == after
assert ".S.DOBJ:" in current
assert not re.search(r"(?m)^BUILD/[^\n]+\.DOBJ:", current)
print("PASS: 53 native KCC compiler recipes preserved; assembler suffix rule shared")
PY
