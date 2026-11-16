#!/bin/sh
# Read-only full 48K MM snapshot after sixth RUN unexpectedly succeeds
# WITHOUT the optional PURE MRES. Same exact source/KCORE as v1629.
set -eu
: "${PURE_OFF_BUILD_V1631:?preserved PURE-disabled v1631 build required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-capacity-snapshot-v1631.XXXXXX")
trap 'echo "v1631 baseline physical MM snapshot: $work"' EXIT HUP INT TERM
mkdir -p "$work/media"
python3 - "$PURE_OFF_BUILD_V1631" "$work" <<'PY'
from pathlib import Path
import re
import sys

boot, work = map(Path, sys.argv[1:])
assert "proc_pure_mres_package_v1612" not in (
    boot / "kinit.map").read_text(encoding="ascii")
source = (boot / "boot.ini").read_text(encoding="ascii")
symbols = {}
for line in (boot / "kcore.map").read_text(encoding="ascii").splitlines():
    parts = line.split()
    if len(parts) >= 2 and re.fullmatch(r"[0-7]+", parts[1]):
        symbols[parts[0]] = int(parts[1], 8)
required = ("mm_arenas", "mm_arena_count", "mm_extents",
            "mm_extent_count", "proc_current_slot", "proc_high_slot",
            "proc_slots")
assert all(name in symbols for name in required)
for unit in range(4):
    key = "attach -q dtc%d " % unit
    matches = [line[len(key):] for line in source.splitlines()
               if line.startswith(key)]
    assert len(matches) == 1
    dest = work / "media" / ("dtc%d.tap" % unit)
    dest.write_bytes(Path(matches[0]).read_bytes())
    source = source.replace(matches[0], str(dest))
source = "\n".join(line for line in source.splitlines()
                    if not line.startswith(("attach -q dsk", "attach -q dr")))
(work / "noaux.ini").write_text(source + "\n", encoding="ascii")
PY
port=$((33000 + ($$ % 10500)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$work/noaux.ini" "$work/trace.ini" "$port" "$((port+13000))"
python3 - "$PURE_OFF_BUILD_V1631/kcore.map" "$work/trace.ini" <<'PY'
from pathlib import Path
import re
import sys

symbols = {}
for line in Path(sys.argv[1]).read_text(encoding="ascii").splitlines():
    parts = line.split()
    if len(parts) >= 2 and re.fullmatch(r"[0-7]+", parts[1]):
        symbols[parts[0]] = int(parts[1], 8)
path = Path(sys.argv[2])
ini = path.read_text(encoding="ascii")
assert "go 020\nexit\n" in ini
tail = 'expect "aaaaa!u"\ngo 020\n'
tail += 'echo V1631_SIX_RUN_ACCEPTED\n'
for name in ("proc_current_slot", "proc_high_slot", "proc_slots",
             "mm_arena_count", "mm_extent_count"):
    tail += "examine %06o\n" % symbols[name]
tail += "examine %06o-%06o\n" % (
    symbols["mm_arenas"], symbols["mm_arenas"] + 7)
tail += "examine %06o-%06o\n" % (
    symbols["mm_extents"], symbols["mm_extents"] + 95)
tail += 'echo V1631_END_SIX_RUN\ncont\nexit\n'
path.write_text(ini.replace("go 020\nexit\n", tail, 1),
                encoding="ascii")
PY
set +e
(
    cd "$PURE_OFF_BUILD_V1631"
    TERM=dumb timeout -k 3s "${PURE_OFF_TIMEOUT_V1631:-490}" \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/trace.ini"
) >"$work/trace.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/trace.log" >"$work/trace.clean"
echo "v1631 physical baseline simulator status=$rc"
grep -E 'V1631_|aaaaa!u|HALT instruction|LOADED' \
    "$work/trace.clean" | tail -20 || :
test "$rc" -eq 0
grep -q 'V1631_SIX_RUN_ACCEPTED$' "$work/trace.clean"
grep -q '^V1631_END_SIX_RUN$' "$work/trace.clean"
grep -q 'HALT instruction' "$work/trace.clean"
