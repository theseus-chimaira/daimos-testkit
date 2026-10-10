#!/bin/sh
# Check that the compact native MAKE recipes preserve their command strings.
set -eu

kcc=${KCC_REPO:-"$HOME/git/kcc"}
python3 - "$kcc" <<'PY'
import pathlib
import subprocess
import sys

root = pathlib.Path(sys.argv[1])
baseline = subprocess.check_output(
    ["git", "-C", str(root), "show", "0b4ae44:daimos.mk"],
    text=True,
).splitlines()
current = (root / "daimos.mk").read_text().splitlines()
flags = (
    "-Pgnu99 -x=pdp6 -m=gas -DHOST_DAIMOS=1 -DHOST_UNIX=0 "
    "-I/OPTION/SOURCE/KCC/SELF/INCLUDE -I/OPTION/SOURCE/KCC/ABI"
)
definition = "KCC_NATIVE_FLAGS = " + flags
assert current.pop(5) == definition
assert len(current) == len(baseline)
target = None
changed = 0
for original, compact in zip(baseline, current):
    if original.startswith("B/") and ":" in original:
        target = original.split(":", 1)[0]
    if original != compact:
        assert target is not None
        expanded = compact.replace("$@", target).replace(
            "$(KCC_NATIVE_FLAGS)", flags
        )
        assert expanded == original, (target, original, expanded)
        changed += 1
assert changed == 77, changed
assert len(definition) < 256
print("native KCC MAKE recipe-equivalence: 77 recipes preserved")
PY
