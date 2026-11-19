#!/bin/sh
# Audit the actual two MM descriptor writes, then mutate the unpin sample.
# Optional scheduler mode additionally requires READY_ONCE and slot 2 RUN.
set -eu
: "${PURE_FOLLOW_TRACE_V1620:?physical MM write-watch trace required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
mode=${PURE_FOLLOW_MODE_V1620:-mm}
work=$(mktemp -d "$TMPDIR/pure-follow-v1620.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
python3 "$here/audit-follow-v1620.py" "$PURE_FOLLOW_TRACE_V1620" "$mode"
python3 - "$PURE_FOLLOW_TRACE_V1620" "$work/false-unpin.clean" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
needle = "Breakpoint, PC: 002467 "
start = s.index(needle)
end = s.index("24307:\t000001000002", start)
Path(sys.argv[2]).write_text(
    s[:end] + "24307:\t000011000002" + s[end + 19:])
PY
if python3 "$here/audit-follow-v1620.py" \
    "$work/false-unpin.clean" "$mode" >"$work/mutant.log" 2>&1; then
    echo 'FAIL v1620: false pin-release trace passed' >&2
    exit 1
fi
grep -q '^FAIL v1620 physical follow audit:' "$work/mutant.log"
echo 'PASS v1620: unsafe retained-pin mutation rejected'

if [ "$mode" = scheduler ]; then
    python3 - "$PURE_FOLLOW_TRACE_V1620" \
        "$work/ready-mutant.clean" "$work/current-mutant.clean" <<'PY'
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()


def replace_stage(pc, before, after):
    begin = s.index("Breakpoint, PC: " + pc + " ")
    offset = s.index(before, begin)
    next_stage = s.find("Breakpoint, PC:", begin + 16)
    assert next_stage < 0 or offset < next_stage, "wrong physical stage"
    return s[:offset] + after + s[offset + len(before):]


Path(sys.argv[2]).write_text(replace_stage(
    "032477", "24235:\t000000001002", "24235:\t000000000002"))
Path(sys.argv[3]).write_text(replace_stage(
    "016770", "24233:\t000000000002", "24233:\t000000000000"))
PY
    for name in ready current; do
        if python3 "$here/audit-follow-v1620.py" \
            "$work/$name-mutant.clean" scheduler \
            >"$work/$name.log" 2>&1; then
            echo "FAIL v1620: unsafe scheduler $name accepted" >&2
            exit 1
        fi
        grep -q '^FAIL v1620 physical follow audit:' "$work/$name.log" || {
            cat "$work/$name.log" >&2
            exit 1
        }
        echo "PASS v1620: unsafe scheduler $name mutation rejected"
    done
fi
