#!/bin/sh
# Check PATH-based executable defaults while retaining installation locations.
set -eu
: "${DAIMOS_REPO:?}"
python3 - "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import re
import subprocess
import sys
root = Path(sys.argv[1])
files = ["userland/Makefile", "userland/libc/Makefile",
         "userland/optional/kcc/Makefile", "system/boot/pdp6/Makefile",
         "system/kernel/Makefile"] + [
    "system/stand/pdp6/" + x + "/Makefile"
    for x in ("drm", "dsk", "dtc", "mtc", "ptr")
]
count = 0
for name in files:
    old = subprocess.check_output(["git", "-C", str(root),
                                   "show", "cb620db:" + name], text=True)
    new = (root / name).read_text()
    before = dict(re.findall(r"(?m)^([A-Z][A-Z0-9_]*)\s*(?:\?=|=)\s*(\S+)$", old))
    after = dict(re.findall(r"(?m)^([A-Z][A-Z0-9_]*)\s*(?:\?=|=)\s*(\S+)$", new))
    for key, value in before.items():
        if key not in after:
            continue
        if after[key] == value:
            continue
        if value.startswith(("$(PDP10_PREFIX)/bin/", "${PDP10_PREFIX}/bin/",
                             "$(HOST_TOOLS)/", "${HOST_TOOLS}/",
                             "/OPTION/BASE/EXEC/")):
            assert after[key] == value.rsplit("/", 1)[-1], (name, key, after[key])
            count += 1
        else:
            raise AssertionError((name, key, value, after[key]))
    assert "-f \"/SYSTEM/EXEC/" in new if name == "system/boot/pdp6/Makefile" else True
assert count >= 30, count
libc = (root / "userland/libc/Makefile").read_text()
for var in ("CC", "DAS", "DARC"):
    assert 'command -v "$(' + var + ')"' in libc
assert 'echo "kcc"' in (root / "system/kernel/Makefile").read_text()
print("PASS:", count, "PATH defaults; absolute image paths retained")
PY
