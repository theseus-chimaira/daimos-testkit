#!/bin/sh
# Read-only original physical MM busy refusal + exact rollback + negatives.
set -eu
: "${V1894_BUILD:?original v1855 48K source-built guest required}"
: "${V1894_WORK:?actual v1894 physical evidence required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
python3 - "$V1894_WORK" <<'PY'
from pathlib import Path
import sys
w=Path(sys.argv[1]);a=(w/'physical.log').read_bytes()
if a.replace(b'\r',b'')!=(w/'physical.clean').read_bytes():
    raise SystemExit('FAIL v1894: original physical trace bytes do not match log')
PY
python3 "$here/verify-v1894.py" "$kit" "$V1894_BUILD" "$V1894_WORK"
python3 "$here/negative-v1894.py" "$kit" "$V1894_BUILD" "$V1894_WORK"
sha256sum "$V1894_BUILD/kcore.dxr" "$V1894_BUILD/pure-mres-v1612.dxr" \
  "$V1894_WORK/physical.clean"
echo 'PASS v1894 real original MM refuses source free; exact two unpinned owners safely roll back'
