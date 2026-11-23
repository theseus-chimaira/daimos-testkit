#!/bin/sh
# Independent read-only original hardware trace/owner oracle + negatives.
set -eu
: "${V1900_BUILD:?source-built v1900 PURE MRES image required}"
: "${V1900_PHYSICAL_WORK:?original physical v1900 trace required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
python3 - "$V1900_PHYSICAL_WORK" <<'PY'
from pathlib import Path
import sys
work=Path(sys.argv[1]); original=(work/'physical.log').read_bytes()
if original.replace(b'\r',b'')!=(work/'physical.clean').read_bytes():
    raise SystemExit('FAIL v1900: original physical transcript normalization mismatch')
PY
python3 "$here/verify-physical-v1900.py" "$kit" "$V1900_BUILD" "$V1900_PHYSICAL_WORK"
python3 "$kit/tests/validation/pure-k05-persistent-source-pin-v1895/negative-v1895.py" \
    "$kit" "$V1900_BUILD" "$V1900_PHYSICAL_WORK" \
    "$here/verify-physical-v1900.py"
sha256sum "$V1900_BUILD/kcore.dxr" "$V1900_BUILD/pure-mres-v1612.dxr" \
    "$V1900_PHYSICAL_WORK/physical.clean"
echo 'PASS v1900 actual 48K updated PURE, native original source-free -5, all 10 executed physical negative controls'
