#!/bin/sh
# Physical 48K fixed-parent APR corridor audit and negative witnesses.
set -eu
: "${PURE_ON_CASE_V1633:?original PURE-enabled v1629 case required}"
: "${PURE_OFF_CASE_V1633:?original PURE-disabled v1631 case required}"
: "${PURE_ON_TRACE_V1633:?original v1629 physical owner trace required}"
: "${PURE_OFF_TRACE_V1633:?original v1632 five-owner trace required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-apr-corridor-v1633.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 "$here/audit-v1633.py" \
    "$PURE_ON_CASE_V1633" "$PURE_OFF_CASE_V1633" \
    "$PURE_ON_TRACE_V1633" "$PURE_OFF_TRACE_V1633"
python3 - "$PURE_ON_CASE_V1633/build/kcore.map" \
    "$PURE_ON_TRACE_V1633" "$PURE_OFF_TRACE_V1633" \
    "$work/dynamic-mutant" "$work/parent-mutant" <<'PY'
from pathlib import Path
import re
import sys

sym = {f[0]: int(f[1], 8) for line in Path(sys.argv[1]).read_text(
    encoding="ascii").splitlines() if len(f := line.split()) >= 2
    and re.fullmatch(r"[0-7]+", f[1])}

def modify_one(trace, head, tail, address, old, new):
    start, end = head + "\n", tail + "\n"
    assert trace.count(start) == trace.count(end) == 1
    before, rest = trace.split(start, 1)
    body, after = rest.split(end, 1)
    oldline = "%o:\t%012o" % (address, old)
    newline = "%o:\t%012o" % (address, new)
    assert body.count(oldline) == 1
    return before + start + body.replace(oldline, newline, 1) + end + after

on = Path(sys.argv[2]).read_text(encoding="ascii")
off = Path(sys.argv[3]).read_text(encoding="ascii")
dynamic_address = sym["mm_extents"] + 2 * 11
parent_address = sym["mm_extents"] + 2 * 17
Path(sys.argv[4]).write_text(modify_one(
    on, "V1629_STAGE_B", "V1629_END_B", dynamic_address,
    (0o410 << 18) | 0o46175, (0o411 << 18) | 0o46175),
    encoding="ascii")
Path(sys.argv[5]).write_text(modify_one(
    off, "V1632_FIVE_READY", "V1632_END_FIVE", parent_address,
    (0o10000 << 18) | 0o126000, (0o7000 << 18) | 0o126000),
    encoding="ascii")
PY
for mutant in dynamic-mutant parent-mutant; do
    on="$PURE_ON_TRACE_V1633"
    off="$PURE_OFF_TRACE_V1633"
    case "$mutant" in
    dynamic-mutant) on="$work/$mutant" ;;
    parent-mutant) off="$work/$mutant" ;;
    esac
    if python3 "$here/audit-v1633.py" \
        "$PURE_ON_CASE_V1633" "$PURE_OFF_CASE_V1633" "$on" "$off" \
        >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1633: forged $mutant owner geometry accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1633 APR corridor proof:' "$work/$mutant.log"
done
echo 'PASS v1633: corrupted dynamic boundary and parent span rejected'
