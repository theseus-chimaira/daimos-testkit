#!/bin/sh
# Validate the native BUILD directory and recursive-clean contract.
set -eu
kcc=${KCC_REPO:-"$HOME/git/kcc"}
python3 - "$kcc" <<'PY'
from pathlib import Path
import re
import sys

native = (Path(sys.argv[1]) / "daimos.mk").read_text()
assert "NATIVE_BUILD_DIR = BUILD" in native
assert "NATIVE: BUILD BUILD/KCPP.DXR" in native
assert "BUILD:\n\t@$(NATIVE_INSTALL) -D -M 0777 BUILD" in native
assert not re.search(r"(?m)^B[/:]", native)
assert len(re.findall(r"(?m)^BUILD/[^\n]+\.DARC:", native)) == 19
assert len(re.findall(r"(?m)^BUILD/[^\n]+\.DXR:", native)) == 5
assert native.split("CLEAN:\n", 1)[1].strip() == (
    "@$(NATIVE_RM) -R -F BUILD"
)
print("PASS: BUILD paths, archive/link graph, recursive CLEAN contract")
PY
