#!/bin/sh
# Read-only original physical source-unpin -4 and child recovery acceptance.
set -eu
: "${V1899_BUILD:?original v1855 five-child source-built guest required}"
: "${V1899_WORK:?original actual PDP6 source-unpin failure evidence required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
python3 - "$V1899_WORK" <<'PY'
from pathlib import Path
import sys
w = Path(sys.argv[1]); original = (w / 'physical.log').read_bytes()
if original.replace(b'\r', b'') != (w / 'physical.clean').read_bytes():
    raise SystemExit('FAIL v1899: original physical transcript differs from log')
PY
python3 "$here/verify-v1899.py" "$kit" "$V1899_BUILD" "$V1899_WORK"
python3 "$here/negative-v1899.py" "$kit" "$V1899_BUILD" "$V1899_WORK"
sha256sum "$V1899_BUILD/kcore.dxr" "$V1899_BUILD/pure-mres-v1612.dxr" \
  "$V1899_WORK/physical.clean"
echo 'PASS v1899: original source native -4, full target deleted, source retained; five child WAIT/HALT'
