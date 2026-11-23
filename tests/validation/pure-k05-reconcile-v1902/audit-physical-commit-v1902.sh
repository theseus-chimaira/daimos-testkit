#!/bin/sh
# Original PDP6 48K native MM rollback; independent read-only audit.
set -eu
: "${V1902_BUILD:?source-built native 48K KCORE/PURE image required}"
: "${V1902_COMMIT_WORK:?actual native target free and C-store physical trace required}"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
kit=$(CDPATH= cd -- "$here/../../.." && pwd)
python3 - "$V1902_COMMIT_WORK" <<'PY'
from pathlib import Path
import sys
work = Path(sys.argv[1])
actual = (work / 'physical.log').read_bytes()
expected = (work / 'physical.clean').read_bytes()
if actual.replace(b'\r',b'') != expected:
    raise SystemExit('FAIL v1902: original PDP6 console is not authentic normalized log')
PY
python3 "$here/verify-physical-commit-v1902.py" "$kit" "$V1902_BUILD" \
    "$V1902_COMMIT_WORK"
python3 "$here/negative-physical-commit-v1902.py" "$kit" \
    "$V1902_BUILD" "$V1902_COMMIT_WORK"
sha256sum "$V1902_BUILD/kcore.dxr" \
    "$V1902_BUILD/pure-mres-v1612.dxr" \
    "$V1902_COMMIT_WORK/physical.clean"
echo 'PASS v1902: original 48K PDP6 actual MM rollback, saved private CPU context, autonomous parent user progress'
