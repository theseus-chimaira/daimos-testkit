#!/bin/sh
# Verify PATH-based command names preserve all recipe arguments and destinations.
set -eu
kcc=${KCC_REPO:-"$HOME/git/kcc"}
python3 - "$kcc" <<'PY'
from pathlib import Path
import re
import subprocess
import sys

root = Path(sys.argv[1])
old = subprocess.check_output(
    ["git", "-C", str(root), "show", "7b1edd1:daimos.mk"], text=True
)
new = (root / "daimos.mk").read_text()

def commands(source):
    variables = {}
    recipes = []
    for line in source.splitlines():
        match = re.fullmatch(r"([A-Z_]+) = (.*)", line)
        if match:
            variables[match.group(1)] = match.group(2)
        if line.startswith("\t"):
            recipes.append(line)
    def expand(recipe):
        for _ in range(8):
            updated = re.sub(
                r"\$\(([A-Z_]+)\)",
                lambda match: variables.get(match.group(1), match.group(0)),
                recipe,
            )
            if updated == recipe:
                return recipe
            recipe = updated
        raise AssertionError("recursive expansion exceeds eight levels")
    return [expand(recipe) for recipe in recipes]

before, after = commands(old), commands(new)
assert len(after) == len(before) == 86
for oldpath, name in (
    ("/OPTION/BASE/EXEC/KCC", "KCC"),
    ("/OPTION/BASE/EXEC/DAS", "DAS"),
    ("/OPTION/BASE/EXEC/DARC", "DARC"),
    ("/OPTION/BASE/EXEC/DLINK", "DLINK"),
    ("/SYSTEM/EXEC/INSTALL", "INSTALL"),
    ("/SYSTEM/EXEC/RM", "RM"),
):
    before = [line.replace("\t@" + oldpath + " ", "\t@" + name + " ")
              for line in before]
assert after == before
assert max(map(len, after)) < 256
for name in ("NATIVE_KCC", "NATIVE_DAS", "NATIVE_INSTALL", "NATIVE_KCC_DEST", "NATIVE_KCC_LIBEXEC"):
    assert name + " = " in new
print("PASS: 86 commands retain arguments and destinations after PATH conversion")
PY
