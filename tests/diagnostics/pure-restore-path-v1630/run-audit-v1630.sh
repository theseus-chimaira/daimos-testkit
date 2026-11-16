#!/bin/sh
# Original installed PURE opcode/AC check plus deliberately false branches.
set -eu
: "${PURE_RESTORE_BUILD_V1630:?matching saved v1629 48K build required}"
: "${PURE_RESTORE_TRACE_V1630:?full original physical replay trace required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
export TMPDIR PDP10_PREFIX
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-v1630-audit.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
map="$PURE_RESTORE_BUILD_V1630/pure-mres-v1612.map"
dxr="$PURE_RESTORE_BUILD_V1630/pure-mres-v1612.dxr"
source="$PURE_RESTORE_BUILD_V1630/../user/init-v1614.c"
python3 "$here/audit-v1630.py" "$map" "$dxr" \
    "$PURE_RESTORE_TRACE_V1630" "$source" \
    --dxrcheck="$PDP10_PREFIX/bin/dxrcheck"
python3 - "$PURE_RESTORE_TRACE_V1630" "$work/claim-mutant" \
    "$work/commit-mutant" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text(encoding="ascii")
claim = "1:\t000000117000\n2:\t000000000002"
commit = "Breakpoint, PC: 034614 (MOVEI 0,2)"
assert s.count(claim) == 1 and s.count(commit) == 1
Path(sys.argv[2]).write_text(s.replace(
    claim, "1:\t000000127000\n2:\t000000000002", 1),
    encoding="ascii")
Path(sys.argv[3]).write_text(s.replace(
    commit, "Breakpoint, PC: 034236 (MOVEI 0,2)", 1),
    encoding="ascii")
PY
for mutant in claim-mutant commit-mutant; do
    if python3 "$here/audit-v1630.py" "$map" "$dxr" \
        "$work/$mutant" "$source" \
        --dxrcheck="$PDP10_PREFIX/bin/dxrcheck" \
        >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1630: falsified $mutant accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1630 original restore path:' "$work/$mutant.log"
done
echo 'PASS v1630: wrong prefix base and forged FULL-path PC rejected'
