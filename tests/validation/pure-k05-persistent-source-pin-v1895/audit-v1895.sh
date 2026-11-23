#!/bin/sh
# Original 48K PDP6 real permanent source-free -5 with autonomous parent.
set -eu
: "${V1895_BUILD:?source-built v1892 parent-HB original 48K image required}"
: "${V1895_WORK:?real v1895 original physical evidence required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
python3 - "$V1895_WORK" <<'PY'
from pathlib import Path
import sys
w=Path(sys.argv[1]); original=(w/'physical.log').read_bytes()
if original.replace(b'\r',b'')!=(w/'physical.clean').read_bytes():
    raise SystemExit('FAIL v1895 original physical data normalization changed')
PY
python3 "$here/verify-v1895.py" "$kit" "$V1895_BUILD" "$V1895_WORK"
python3 "$here/negative-v1895.py" "$kit" "$V1895_BUILD" "$V1895_WORK"
sha256sum "$V1895_BUILD/kcore.dxr" "$V1895_BUILD/pure-mres-v1612.dxr" \
  "$V1895_WORK/physical.clean"
echo 'PASS v1895: native real MM free -5, persistent pin, no unsafe rollback or APR publication, live parent'
