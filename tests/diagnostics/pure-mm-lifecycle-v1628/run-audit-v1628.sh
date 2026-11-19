#!/bin/sh
# Recheck the genuine physical source-mapped three-stage owner trace.
set -eu
: "${PURE_MM_BUILD_V1628:?original 64K build required}"
: "${PURE_MM_TRACE_V1628:?original three-stage physical trace required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-mm-audit-v1628.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
map="$PURE_MM_BUILD_V1628/kcore.map"
python3 "$here/audit-v1628.py" "$map" "$PURE_MM_TRACE_V1628"
python3 - "$PURE_MM_TRACE_V1628" "$work/overlap" \
    "$work/missing-wait" <<'PY'
from pathlib import Path
import sys
trace = Path(sys.argv[1]).read_text(encoding="ascii")
head = "V1628_STAGE_B\n"
tail = "V1628_END_B\n"
assert trace.count(head) == trace.count(tail) == 1
prefix, rest = trace.split(head, 1)
span, suffix = rest.split(tail, 1)
base = "24254:\t000200042602"
assert span.count(base) == 1
Path(sys.argv[2]).write_text(
    prefix + head + span.replace(base, "24254:\t000600042602", 1)
    + tail + suffix, encoding="ascii")
assert trace.count("V1628_END_Z\n") == 1
Path(sys.argv[3]).write_text(trace.replace(
    "V1628_END_Z\n", "V1628_END_X\n", 1), encoding="ascii")
PY
for mutant in overlap missing-wait; do
    if python3 "$here/audit-v1628.py" "$map" "$work/$mutant" \
        >"$work/$mutant.out" 2>&1; then
        echo "FAIL v1628: forged $mutant snapshot accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1628 MM lifecycle audit:' "$work/$mutant.out"
done
echo 'PASS v1628: overlapping extent and missing WAIT-stage proof rejected'
