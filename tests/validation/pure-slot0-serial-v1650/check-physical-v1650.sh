#!/bin/sh
# Correlate the original v1643 source-matched physical 48K witness.
# Mutate only disposable trace copies; unchanged kernel and original trace.
set -eu
: "${DAIMOS_REPO:?source DAIMOS repository required}"
: "${PURE_PHYS_BUILD_V1650:?original 48K KCORE build directory required}"
: "${PURE_PHYS_TRACE_V1650:?original 48K v1643 trace required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-pure-slot0-physical-v1650.XXXXXX")
trap 'echo "v1650 correlated evidence: $work"' EXIT HUP INT TERM
python3 "$here/audit-physical-v1650.py" \
    "$DAIMOS_REPO" "$testkit" "$PURE_PHYS_BUILD_V1650" \
    "$PURE_PHYS_TRACE_V1650" > "$work/physical-original-v1650.log"
cat "$work/physical-original-v1650.log"

python3 - "$here" "$testkit" "$PURE_PHYS_BUILD_V1650" \
    "$PURE_PHYS_TRACE_V1650" "$work" <<'PY'
from pathlib import Path
import runpy
import re
import sys

here, testkit, build, trace, work = (Path(p) for p in sys.argv[1:])
source = trace.read_text(encoding="ascii")
helper = runpy.run_path(str(testkit /
    "tests/diagnostics/pure-full-restore-v1638/audit-v1638.py"))
names = helper["symbols"]((build / "kcore.map").read_text(encoding="ascii"))
first, last = "V1643_STAGE_FULL_PINNED\n", "V1643_END_FULL_PINNED\n"
assert source.count(first) == source.count(last) == 1
prefix, remaining = source.split(first, 1)
block, suffix = remaining.split(last, 1)
words = dict((int(a, 8), int(b, 8)) for a, b in re.findall(
    r"(?m)^\s*([0-7]{1,7}):\s*([0-7]{1,12})\s*$", block))
slot_address = names["proc_current_slot"]
assert words[slot_address] == 0
bad_current = block.replace(
    "%o:\t%012o" % (slot_address, 0),
    "%o:\t%012o" % (slot_address, 1), 1)
assert bad_current != block
(work / "bad-current-slot-v1650.trace").write_text(
    prefix + first + bad_current + last + suffix, encoding="ascii")
count = words[names["mm_extent_count"]]
candidate = []
for index in range(count):
    address = names["mm_extents"] + index * 2 + 1
    metadata = words[address]
    if (metadata >> 18) & 7 == 4 and ((metadata >> 21) & 255) == 1:
        candidate.append((address, metadata))
assert len(candidate) == 1
address, metadata = candidate[0]
bad_pin = block.replace(
    "%o:\t%012o" % (address, metadata),
    "%o:\t%012o" % (address, metadata - (1 << 21)), 1)
assert bad_pin != block
(work / "bad-raw-pin-v1650.trace").write_text(
    prefix + first + bad_pin + last + suffix, encoding="ascii")
PY

for mutation in current-slot raw-pin; do
    if python3 "$here/audit-physical-v1650.py" \
        "$DAIMOS_REPO" "$testkit" "$PURE_PHYS_BUILD_V1650" \
        "$work/bad-$mutation-v1650.trace" \
        > "$work/rejected-$mutation-v1650.log" 2>&1; then
        echo "FAIL v1650: invalid physical $mutation accepted" >&2
        exit 1
    fi
    if ! grep -q '^FAIL v1650 physical/PI6 correlation:' \
        "$work/rejected-$mutation-v1650.log"; then
        echo "FAIL v1650: incorrect $mutation witness refusal" >&2
        cat "$work/rejected-$mutation-v1650.log" >&2
        exit 1
    fi
    echo "PASS v1650: invalid physical $mutation witness rejected"
done
