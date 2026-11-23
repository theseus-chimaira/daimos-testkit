#!/bin/sh
# Original physically executed double target-unpin failure, read-only audit.
set -eu
: "${V1898_BUILD:?original 48K resident-parent guest required}"
: "${V1898_WORK:?original real v1898 physical evidence required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
python3 - "$V1898_WORK" <<'PY'
from pathlib import Path
import sys
w = Path(sys.argv[1]); data = (w / 'physical.log').read_bytes()
if data.replace(b'\r', b'') != (w / 'physical.clean').read_bytes():
    raise SystemExit('FAIL v1898: physical transcript does not match original log')
PY
python3 "$here/verify-v1898.py" "$kit" "$V1898_BUILD" "$V1898_WORK"
python3 "$here/negative-v1898.py" "$kit" "$V1898_BUILD" "$V1898_WORK"
sha256sum "$V1898_BUILD/kcore.dxr" "$V1898_BUILD/pure-mres-v1612.dxr" \
  "$V1898_WORK/physical.clean"
echo 'PASS v1898: original double target MM unpin refusal leaves RAW and target safely quarantined'
