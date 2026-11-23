#!/bin/sh
# Full source/map/physical process table audit and four mutant controls.
set -eu
: "${V1891_BUILD:?original 48K source-built v1855 image required}"
: "${V1891_WORK:?real v1891 physical SIMH evidence required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
python3 - "$V1891_WORK" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);raw=(p/'physical.log').read_bytes()
if raw.replace(b'\r',b'')!=(p/'physical.clean').read_bytes():
 raise SystemExit('v1891: original physical monitor transcript not normalized exactly')
PY
python3 "$here/verify-process-v1891.py" "$kit" "$V1891_BUILD" "$V1891_WORK"
python3 "$here/negative-process-v1891.py" "$kit" "$V1891_BUILD" "$V1891_WORK"
sha256sum "$V1891_BUILD/kcore.dxr" "$V1891_BUILD/pure-mres-v1612.dxr" \
    "$V1891_WORK/physical.clean"
echo 'PASS v1891: original PDP6 quarantined process table and healthy peer descriptors'
