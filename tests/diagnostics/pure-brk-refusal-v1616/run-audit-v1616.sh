#!/bin/sh
# Audit two preserved, separately replayed physical PDP-6 MM snapshots.
# A private mutation of the captured pin count must be rejected.
set -eu
: "${PURE_BRK_BUILD_V1615:?matching physical KCORE build required}"
: "${PURE_BEFORE_TRACE_V1616:?pre-BRK physical trace required}"
: "${PURE_AFTER_TRACE_V1616:?interrupted physical trace required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-audit-v1616.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
map="$PURE_BRK_BUILD_V1615/kcore.map"

python3 "$here/audit-v1616.py" "$map" \
    "$PURE_BEFORE_TRACE_V1616" "$PURE_AFTER_TRACE_V1616"

python3 - "$PURE_AFTER_TRACE_V1616" "$work/mutant.clean" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
# Observed owner 4 metadata: PACKED type, pin=1, owner=4.
old = '000014000004'
assert s.count(old) == 1, 'physical MM pin evidence drifted'
Path(sys.argv[2]).write_text(s.replace(old, '000004000004', 1))
PY
if python3 "$here/audit-v1616.py" "$map" \
    "$PURE_BEFORE_TRACE_V1616" "$work/mutant.clean" \
    >"$work/mutant.log" 2>&1; then
    echo 'FAIL v1616: mutated MM pin was accepted' >&2
    exit 1
fi
grep -q '^FAIL v1616 audit:' "$work/mutant.log" || {
    cat "$work/mutant.log" >&2
    exit 1
}
echo 'PASS v1616: physical MM audit rejects an unsafe pin mutation'
