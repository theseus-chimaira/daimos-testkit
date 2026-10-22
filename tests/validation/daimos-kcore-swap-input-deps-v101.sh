#!/bin/sh
# Prevent an outer KCORE build from silently retaining stale compiled swap
# objects after one of the kernel's combined proc_swap.s inputs changes.
# This is a source-graph test only; it never runs a simulator or 32K build.
set -eu
: "${DAIMOS_REPO:?DAIMOS_REPO must be set}"

python3 - "$DAIMOS_REPO" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
kernel_make = (root / "system/kernel/Makefile").read_text()
boot_make = (root / "system/boot/pdp6/Makefile").read_text()

# Both makefiles must describe the same sources. Extract the actual direct
# prerequisites from the kernel generator rule, rather than hardcoding names.
match = re.search(r"^\$\{BUILD\}/proc_swap\.s:\s*(.*)$",
                  kernel_make, re.MULTILINE)
assert match is not None, "missing kernel proc_swap.s generator rule"
required = [word for word in match.group(1).split()
            if word.startswith("proc/")]
assert required, "no composite proc_swap.s inputs discovered"

match = re.search(r"^KERNEL_INPUTS\s*=\s*((?:.*\\\n)*.*)$",
                  boot_make, re.MULTILINE)
assert match is not None, "missing outer KERNEL_INPUTS list"
outer = match.group(1)
missing = [name for name in required
           if "$(KERNEL_DIR)/" + name not in outer]
assert not missing, "stale KCORE risk, missing outer inputs: " + ", ".join(missing)
print("daimos-kcore-swap-input-deps-v101: PASS ({} composite sources)".
      format(len(required)))
PY
