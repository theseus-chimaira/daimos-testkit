#!/bin/sh
# Read-only original PDP6 source-free-commit, forged-reply oracle and mutants.
set -eu
: "${V1893_BUILD:?original source-built 48K five-child v1855 required}"
: "${V1893_WORK:?actual original physical v1893 trace required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
python3 - "$V1893_WORK" <<'PY'
from pathlib import Path
import sys
e=Path(sys.argv[1]);orig=(e/'physical.log').read_bytes()
if orig.replace(b'\r',b'')!=(e/'physical.clean').read_bytes():
    raise SystemExit('FAIL v1893: original PDP6 physical console normalized incorrectly')
PY
python3 "$here/verify-v1893.py" "$kit" "$V1893_BUILD" "$V1893_WORK"
python3 "$here/negative-v1893.py" "$kit" "$V1893_BUILD" "$V1893_WORK"
sha256sum "$V1893_BUILD/kcore.dxr" "$V1893_BUILD/pure-mres-v1612.dxr" \
    "$V1893_WORK/physical.clean"
echo 'PASS v1893: real PACKED source freed despite fake -5; exact RESIDENT, all-child WAIT/HALT'
