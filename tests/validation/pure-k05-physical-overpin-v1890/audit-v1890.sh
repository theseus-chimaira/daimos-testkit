#!/bin/sh
# Read-only audit of an already-executed original v1890 physical trace.
set -eu
: "${V1890_BUILD:?actual v1855 48K build required}"
: "${V1890_WORK:?saved physical run required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
cmp "$V1890_WORK/physical.clean" "$V1890_WORK/physical.log" >/dev/null 2>&1 || {
    # Normalization strips monitor CR; check exact normalization.
    python3 - "$V1890_WORK" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); a=(p/'physical.log').read_bytes()
if a.replace(b'\r',b'') != (p/'physical.clean').read_bytes():
    raise SystemExit('v1890: normalized transcript diverges from raw PDP-6')
PY
}
python3 "$here/verify-v1890.py" "$kit" "$V1890_BUILD" "$V1890_WORK"
python3 "$here/negative-v1890.py" "$kit" "$V1890_BUILD" "$V1890_WORK"
sha256sum "$V1890_BUILD/kcore.dxr" \
    "$V1890_BUILD/pure-mres-v1612.dxr" "$V1890_WORK/physical.clean"
echo 'PASS v1890: source-linked physical pin2, -5, quarantine and real PCLK'
