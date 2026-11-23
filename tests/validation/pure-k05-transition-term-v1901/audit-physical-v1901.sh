#!/bin/sh
# Read-only physical K05 v1901 native user TERM(3) refusal audit.
set -eu
: "${V1901_BUILD:?original source-built gate-equipped 48K PDP6 required}"
: "${V1901_WORK:?actual completed source-linked original physical trace required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
python3 - "$V1901_WORK" <<'PY'
from pathlib import Path
import sys
work=Path(sys.argv[1]);original=(work/'physical.log').read_bytes()
if original.replace(b'\r',b'')!=(work/'physical.clean').read_bytes():
    raise SystemExit('FAIL v1901 source original physical transcript tampered')
PY
python3 "$here/verify-physical-v1901.py" "$kit" "$V1901_BUILD" "$V1901_WORK"
python3 "$here/negative-physical-v1901.py" "$kit" "$V1901_BUILD" "$V1901_WORK"
python3 "$kit/tests/validation/pure-k05-persistent-source-pin-v1895/negative-v1895.py" \
    "$kit" "$V1901_BUILD" "$V1901_WORK" "$here/verify-physical-v1901.py"
sha256sum "$V1901_BUILD/kcore.dxr" "$V1901_BUILD/pure-mres-v1612.dxr" \
    "$V1901_WORK/physical.clean"
echo 'PASS v1901 native original user TERM(3) safety boundary, all independent physical negatives'
