#!/bin/sh
# Source-linked physical observation of the FIRST parent VM allocation.
# Inspect high-core cache ownership before vm_space_create commits its
# APR; do not modify memory, alloc policy, guest source or media.
set -eu
: "${PURE_PARENT_BUILD_V1635:?original v1629 PURE-on build required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-parent-placement-v1635.XXXXXX")
trap 'echo "v1635 parent-placement machine evidence: $work"' EXIT HUP INT TERM
mkdir -p "$work/media"
python3 - "$PURE_PARENT_BUILD_V1635" "$work" <<'PY'
from pathlib import Path
import re
import sys

boot, work = map(Path, sys.argv[1:])
source = (boot / "boot.ini").read_text(encoding="ascii")
symbols = {}
for line in (boot / "kcore.map").read_text(encoding="ascii").splitlines():
    fields = line.split()
    if len(fields) >= 2 and re.fullmatch(r"[0-7]+", fields[1]):
        symbols[fields[0]] = int(fields[1], 8)
required = ("vm_space_create", "mm_extents", "mm_extent_count",
            "mm_arena_count", "mm_arenas", "proc_current_slot",
            "proc_high_slot")
assert all(key in symbols for key in required)
assert symbols["vm_space_create"] == 0o22472
for unit in range(4):
    key = "attach -q dtc%d " % unit
    candidates = [line[len(key):] for line in source.splitlines()
                  if line.startswith(key)]
    assert len(candidates) == 1
    dest = work / "media" / ("dtc%d.tap" % unit)
    dest.write_bytes(Path(candidates[0]).read_bytes())
    source = source.replace(candidates[0], str(dest))
source = "\n".join(line for line in source.splitlines()
                   if not line.startswith(("attach -q dsk", "attach -q dr")))
(work / "noaux.ini").write_text(source + "\n", encoding="ascii")
PY
port=$((33000 + ($$ % 11500)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$work/noaux.ini" "$work/trace.ini" "$port" "$((port+12000))"
python3 - "$PURE_PARENT_BUILD_V1635/kcore.map" "$work/trace.ini" <<'PY'
from pathlib import Path
import re
import sys
symbols = {}
for line in Path(sys.argv[1]).read_text(encoding="ascii").splitlines():
    fields = line.split()
    if len(fields) >= 2 and re.fullmatch(r"[0-7]+", fields[1]):
        symbols[fields[0]] = int(fields[1], 8)
path = Path(sys.argv[2])
ini = path.read_text(encoding="ascii")
assert "go 020\nexit\n" in ini
tail = "break %06o\ngo 020\n" % symbols["vm_space_create"]
tail += "echo V1635_BEFORE_FIRST_VM\n"
for ac in (1, 2, 3, 4):
    tail += "examine %o\n" % ac
for label in ("proc_current_slot", "proc_high_slot", "mm_arena_count",
              "mm_extent_count"):
    tail += "examine %06o\n" % symbols[label]
tail += "examine %06o-%06o\n" % (
    symbols["mm_arenas"], symbols["mm_arenas"] + 7)
tail += "examine %06o-%06o\n" % (
    symbols["mm_extents"], symbols["mm_extents"] + 95)
tail += "echo V1635_END_FIRST_VM\nexit\n"
path.write_text(ini.replace("go 020\nexit\n", tail, 1), encoding="ascii")
PY
set +e
(
    cd "$PURE_PARENT_BUILD_V1635"
    TERM=dumb timeout -k 3s "${PURE_PARENT_TIMEOUT_V1635:-290}" \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/trace.ini"
) >"$work/trace.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/trace.log" >"$work/trace.clean"
echo "v1635 simulator status=$rc"
grep -E 'V1635_|Breakpoint, PC|PURE[[:space:]]+LOADED' \
    "$work/trace.clean" | tail -15 || :
test "$rc" -eq 0
grep -q 'Breakpoint, PC: 022472 ' "$work/trace.clean"
grep -q '^V1635_BEFORE_FIRST_VM$' "$work/trace.clean"
grep -q '^V1635_END_FIRST_VM$' "$work/trace.clean"
