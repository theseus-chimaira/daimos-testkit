#!/bin/sh
# Authenticate an exact physical sixth-RUN MM snapshot and reject false fits.
set -eu
: "${PURE_GEOMETRY_BUILD_V1626:?original 48K build required}"
: "${PURE_GEOMETRY_TRACE_V1626:?original v1625 machine-memory trace required}"
: "${PURE_GEOMETRY_IMAGE_V1626:?original DXR2 PURE executable required}"
: "${DAIMOS_REPO:?matching DAIMOS source required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-geometry-audit-v1626.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
set -- "$PURE_GEOMETRY_BUILD_V1626/kcore.map" \
    "$PURE_GEOMETRY_TRACE_V1626" "$PURE_GEOMETRY_IMAGE_V1626" \
    "$DAIMOS_REPO/system/kernel/proc/exec_load.s"
python3 "$here/audit-v1626.py" "$@" \
    --dxrcheck="$PDP10_PREFIX/bin/dxrcheck"
python3 - "$PURE_GEOMETRY_TRACE_V1626" "$work/owner-mutant" \
    "$work/gap-mutant" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="ascii")
owner = "24305:\t000004000006"
gap = "24304:\t007000057000"
assert source.count(owner) == 1 and source.count(gap) == 1
Path(sys.argv[2]).write_text(source.replace(
    owner, "24305:\t000004000007", 1), encoding="ascii")
Path(sys.argv[3]).write_text(source.replace(
    gap, "24304:\t007001057000", 1), encoding="ascii")
PY
for mutant in owner-mutant gap-mutant; do
    if python3 "$here/audit-v1626.py" "$1" "$work/$mutant" \
        "$3" "$4" --dxrcheck="$PDP10_PREFIX/bin/dxrcheck" \
        >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1626: altered physical MM $mutant was accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1626 physical MM proof:' "$work/$mutant.log"
done
echo 'PASS v1626: foreign owner and overlap mutants both rejected'
