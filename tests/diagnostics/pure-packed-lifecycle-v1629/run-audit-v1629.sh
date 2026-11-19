#!/bin/sh
# Require source-matched real PACKED ownership and all five WAIT results;
# reject altered physical owner and parent success evidence.
set -eu
: "${PURE_PACKED_BUILD_V1629:?v1629 original 48K build required}"
: "${PURE_PACKED_TRACE_V1629:?v1629 B/A/Z physical trace required}"
TMPDIR=${TMPDIR:-$HOME/tmp}
export TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/pure-packed-audit-v1629.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
map="$PURE_PACKED_BUILD_V1629/kcore.map"
source="$PURE_PACKED_BUILD_V1629/../user/init-v1614.c"
python3 "$here/audit-v1629.py" "$map" "$PURE_PACKED_TRACE_V1629" \
    "$source"
python3 - "$map" "$PURE_PACKED_TRACE_V1629" \
    "$work/foreign-owner" "$work/wait-mutant" <<'PY'
from pathlib import Path
import re
import sys
symbols = {}
for line in Path(sys.argv[1]).read_text(encoding="ascii").splitlines():
    p = line.split()
    if len(p) >= 2 and re.fullmatch(r"[0-7]+", p[1]):
        symbols[p[0]] = int(p[1], 8)
text = Path(sys.argv[2]).read_text(encoding="ascii")
start, end = "V1629_STAGE_B\n", "V1629_END_B\n"
assert text.count(start) == text.count(end) == 1
pre, rest = text.split(start, 1)
segment, post = rest.split(end, 1)
physical = {int(a, 8): int(w, 8) for a, w in re.findall(
    r"(?m)^\s*([0-7]{4,7}):\s*([0-7]{1,12})\s*$", segment)}
count = physical[symbols["mm_extent_count"]]
found = []
for index in range(count):
    address = symbols["mm_extents"] + 2 * index + 1
    meta = physical[address]
    if (meta >> 18) & 7 == 4:
        found.append((address, meta))
assert len(found) == 5
address, meta = found[0]
old = "%o:\t%012o" % (address, meta)
new = "%o:\t%012o" % (address, (meta & ~0o777777) | 7)
assert segment.count(old) == 1
Path(sys.argv[3]).write_text(pre + start + segment.replace(old, new, 1)
                              + end + post, encoding="ascii")
assert text.count("LwwwwwZV1629_STAGE_Z") == 1
Path(sys.argv[4]).write_text(text.replace(
    "LwwwwwZV1629_STAGE_Z", "LwwwwwYV1629_STAGE_Z", 1),
    encoding="ascii")
PY
for mutant in foreign-owner wait-mutant; do
    if python3 "$here/audit-v1629.py" "$map" "$work/$mutant" \
        "$source" >"$work/$mutant.log" 2>&1; then
        echo "FAIL v1629: corrupted $mutant physical evidence accepted" >&2
        exit 1
    fi
    grep -q '^FAIL v1629 physical PACKED audit:' "$work/$mutant.log"
done
echo 'PASS v1629: foreign PACKED owner and false final WAIT rejected'
