#!/bin/sh
# Read-only independent original physical target deletion + lost reply.
set -eu
: "${V1897_BUILD:?original source-built v1855 five-child guest required}"
: "${V1897_WORK:?original v1897 PDP6 physical evidence required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
python3 - "$V1897_WORK" <<'PY'
from pathlib import Path
import sys
w = Path(sys.argv[1]); a = (w / 'physical.log').read_bytes()
if a.replace(b'\r', b'') != (w / 'physical.clean').read_bytes():
    raise SystemExit('FAIL v1897: original simulator trace differs from its saved log')
PY
python3 "$here/verify-v1897.py" "$kit" "$V1897_BUILD" "$V1897_WORK"
python3 "$here/negative-v1897.py" "$kit" "$V1897_BUILD" "$V1897_WORK"
sha256sum "$V1897_BUILD/kcore.dxr" "$V1897_BUILD/pure-mres-v1612.dxr" \
  "$V1897_WORK/physical.clean"
echo 'PASS v1897: original target was truly deleted despite lost error reply; children retry, WAIT/HALT'
