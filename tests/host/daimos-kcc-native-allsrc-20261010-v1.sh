#!/bin/sh
# Check native KCC archive inputs against the last released archive graph.
set -eu
kcc=${KCC_REPO:-"$HOME/git/kcc"}
python3 - "$kcc" <<'PY'
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
old = subprocess.check_output(
    ["git", "-C", str(root), "show", "5a1fe6f:daimos.mk"], text=True
)
new = (root / "daimos.mk").read_text()

def archives(text):
    rules = {}
    current = None
    for line in text.splitlines():
        if line.startswith("B/") and ":" in line:
            name, rest = line.split(":", 1)
            current = name if name.endswith(".DARC") else None
            if current:
                rules[current] = [x for x in rest.split() if x != "\\"]
        elif current and line.startswith("    "):
            rules[current].extend(x for x in line.split() if x != "\\")
    return rules

expected = archives(old)
actual = archives(new)
assert expected == actual
count = 0
for name, inputs in actual.items():
    marker = name + ":"
    pos = new.find(marker)
    assert pos >= 0
    recipe = new[pos:].split("\n\t", 1)[1].split("\n", 1)[0]
    assert recipe.strip() == "@$(NATIVE_DARC) -O $@ $^", name
    assert len("/OPTION/BASE/EXEC/DARC -O " + name + " " + " ".join(inputs)) < 256
    count += 1
assert count == 19, count
print("PASS: 19 archive membership lists preserved in order")
PY
