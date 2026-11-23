#!/bin/sh
# Read-only audit of real source free and target rollback native MM -5.
set -eu
: "${V1896_BUILD:?source-built original 48K resident-parent image required}"
: "${V1896_WORK:?actual v1896 physical native target cleanup refusal required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
python3 - "$V1896_WORK" <<'PY'
from pathlib import Path
import sys
w = Path(sys.argv[1]); a = (w / 'physical.log').read_bytes()
if a.replace(b'\r', b'') != (w / 'physical.clean').read_bytes():
    raise SystemExit('FAIL v1896: original physical trace differs from untouched log')
PY
python3 "$here/verify-v1896.py" "$kit" "$V1896_BUILD" "$V1896_WORK"
python3 "$here/negative-v1896.py" "$kit" "$V1896_BUILD" "$V1896_WORK"
sha256sum "$V1896_BUILD/kcore.dxr" "$V1896_BUILD/pure-mres-v1612.dxr" \
  "$V1896_WORK/physical.clean"
echo 'PASS v1896: original native target cleanup MM free -5 conserves both owners and parent progresses'
