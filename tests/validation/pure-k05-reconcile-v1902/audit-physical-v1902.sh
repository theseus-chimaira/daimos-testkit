#!/bin/sh
# Read-only independent original PDP6 native source-free -5 controls.
set -eu
: "${V1902_BUILD:?source-built original 48K KCORE/PURE required}"
: "${V1902_PHYSICAL_WORK:?completed original PDP6 trace required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
python3 - "$V1902_PHYSICAL_WORK" <<'PY'
from pathlib import Path
import sys
work=Path(sys.argv[1])
if (work/'physical.log').read_bytes().replace(b'\r',b'') != \
        (work/'physical.clean').read_bytes():
    raise SystemExit('FAIL v1902 original physical transcript normalization')
PY
python3 "$here/verify-physical-v1902.py" "$kit" "$V1902_BUILD" "$V1902_PHYSICAL_WORK"
python3 "$here/negative-physical-v1902.py" "$kit" "$V1902_BUILD" "$V1902_PHYSICAL_WORK"
sha256sum "$V1902_BUILD/kcore.dxr" "$V1902_BUILD/pure-mres-v1612.dxr" \
    "$V1902_PHYSICAL_WORK/physical.clean"
echo 'PASS v1902 original source-linked 48K native MM refusal physical audit'
