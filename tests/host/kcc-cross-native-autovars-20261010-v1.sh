#!/bin/sh
# Assert automatic-variable replacements retain their original arguments.
set -eu
kcc=${KCC_REPO:-"$HOME/git/kcc"}
python3 - "$kcc" <<'PY'
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
revision = "cd37762"
changed = 0
for name in ("cross.mk", "native.mk"):
    old = subprocess.check_output(
        ["git", "-C", str(root), "show", revision + ":" + name],
        text=True,
    ).splitlines()
    new = (root / name).read_text().splitlines()
    assert len(old) == len(new), name
    first = ""
    for before, after in zip(old, new):
        if not before.startswith(("\t", " ")) and ":" in before:
            target, deps = before.split(":", 1)
            if target.startswith("$(KCC)"):
                first = "$(OBJS)"
            else:
                first = deps.split()[0] if deps.split() else ""
        if before != after:
            assert before.startswith("\t"), (name, before, after)
            expanded = after.replace("$<", first).replace("$^", "$(OBJS)")
            assert expanded == before, (name, before, expanded)
            changed += 1
assert changed == 12, changed
print("PASS: 12 cross/native automatic-variable recipes equivalent")
PY
