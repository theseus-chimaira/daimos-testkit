#!/bin/sh
# Independent read-only original physical 48K user peer / MM owner audit.
set -eu
: "${V1892_BUILD:?source-built original 48K v1892 user guest required}"
: "${V1892_WORK:?actual original physical parent heartbeat evidence required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
python3 - "$V1892_WORK" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]);raw=(root/'physical.log').read_bytes()
if raw.replace(b'\r',b'') != (root/'physical.clean').read_bytes():
    raise SystemExit('v1892: physical original SIMH log/normalized trace mismatch')
PY
python3 "$here/verify-v1892.py" "$kit" "$V1892_BUILD" "$V1892_WORK"
python3 "$here/negative-v1892.py" "$kit" "$V1892_BUILD" "$V1892_WORK"
sha256sum "$V1892_BUILD/kcore.dxr" "$V1892_BUILD/pure-mres-v1612.dxr" \
    "$V1892_BUILD/../user/init.dxr" "$V1892_WORK/physical.clean"
echo 'PASS v1892: original physical resident parent user progress after pinned FULL MM failure'
