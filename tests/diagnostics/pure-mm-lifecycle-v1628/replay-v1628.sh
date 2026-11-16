#!/bin/sh
# Observe original PDP-6 MM owners at B, A and final Z in the exact
# successful v1627 six-child guest. No new kernel code or user image.
set -eu
: "${PURE_MM_BUILD_V1628:?preserved v1627 physical 64K build required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-mm-lifecycle-v1628.XXXXXX")
trap 'echo "v1628 complete original MM trace: $work"' EXIT HUP INT TERM
mkdir -p "$work/media"
python3 - "$PURE_MM_BUILD_V1628" "$work" <<'PY'
from pathlib import Path
import re
import sys

boot, work = map(Path, sys.argv[1:])
source = (boot / "boot.ini").read_text(encoding="ascii")
symbols = {}
for line in (boot / "kcore.map").read_text(encoding="ascii").splitlines():
    p = line.split()
    if len(p) >= 2 and re.fullmatch(r"[0-7]+", p[1]):
        symbols[p[0]] = int(p[1], 8)
required = ("mm_arenas", "mm_arena_count", "mm_extents",
            "mm_extent_count", "proc_current_slot", "proc_high_slot")
assert all(name in symbols for name in required)
assert symbols["mm_extents"] == 0o24254
assert symbols["mm_arenas"] == 0o23637
for unit in range(4):
    key = "attach -q dtc%d " % unit
    paths = [line[len(key):] for line in source.splitlines()
             if line.startswith(key)]
    assert len(paths) == 1
    dest = work / "media" / ("dtc%d.tap" % unit)
    dest.write_bytes(Path(paths[0]).read_bytes())
    source = source.replace(paths[0], str(dest))
source = "\n".join(line for line in source.splitlines()
                    if not line.startswith(("attach -q dsk", "attach -q dr")))
(work / "noaux.ini").write_text(source + "\n", encoding="ascii")
PY
port=$((33000 + ($$ % 10000)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$work/noaux.ini" "$work/trace.ini" "$port" "$((port+12000))"
python3 - "$PURE_MM_BUILD_V1628/kcore.map" "$work/trace.ini" <<'PY'
from pathlib import Path
import re
import sys
symbols = {}
for line in Path(sys.argv[1]).read_text(encoding="ascii").splitlines():
    p = line.split()
    if len(p) >= 2 and re.fullmatch(r"[0-7]+", p[1]):
        symbols[p[0]] = int(p[1], 8)
path = Path(sys.argv[2])
ini = path.read_text(encoding="ascii")
assert "go 020\nexit\n" in ini

def examine(stage):
    commands = "echo V1628_STAGE_%s\n" % stage
    for label in ("proc_current_slot", "proc_high_slot", "mm_arena_count",
                  "mm_extent_count"):
        commands += "examine %06o\n" % symbols[label]
    commands += "examine %06o-%06o\n" % (
        symbols["mm_arenas"], symbols["mm_arenas"] + 7)
    commands += "examine %06o-%06o\n" % (
        symbols["mm_extents"], symbols["mm_extents"] + 95)
    commands += "echo V1628_END_%s\n" % stage
    return commands

tail = 'expect "aaaaaa[B"\ngo 020\n' + examine("B")
tail += 'expect "[A"\ncont\n' + examine("A")
tail += 'expect "LwwwwwwZ"\ncont\n' + examine("Z")
tail += 'cont\nexit\n'
path.write_text(ini.replace("go 020\nexit\n", tail, 1), encoding="ascii")
PY
set +e
(
    cd "$PURE_MM_BUILD_V1628"
    TERM=dumb timeout -k 3s "${PURE_MM_TIMEOUT_V1628:-540}" \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/trace.ini"
) >"$work/trace.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/trace.log" >"$work/trace.clean"
echo "v1628: simulator status=$rc"
grep -E 'V1628_STAGE_|V1628_END_|aaaaaa|LwwwwwwZ|HALT instruction' \
    "$work/trace.clean" | tail -24 || :
if [ "$rc" -ne 0 ]; then
    echo 'v1628: INCONCLUSIVE; simulator failed or timed out' >&2
    exit 1
fi
for stage in B A Z; do
    # SIMH's console EXPECT can stop mid-line, so the ECHO marker
    # follows the user's unfinished `[B`, `[A` or `Z` marker.
    grep -q "V1628_STAGE_$stage$" "$work/trace.clean" || exit 1
    grep -q "^V1628_END_$stage$" "$work/trace.clean" || exit 1
done
grep -q 'HALT instruction' "$work/trace.clean" || exit 1
echo 'v1628: all three original physical owner snapshots captured'
