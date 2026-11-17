#!/bin/sh
# Read-only MM replay of the original v1652 64K executable and DTC media.
# No kernel scheduling hooks, altered MM code, or fabricated owner records.
set -eu
: "${PURE_64K_BUILD_V1652:?physical 64K source-built image directory required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/daimos-pure-64k-replay-v1652.XXXXXX")
trap 'echo "v1652 64K physical MM replay evidence: $work"' EXIT HUP INT TERM
mkdir -p "$work/media"
python3 - "$PURE_64K_BUILD_V1652" "$work" <<'PY'
from pathlib import Path
import re
import sys

build, work = (Path(p) for p in sys.argv[1:])
ini = (build / "boot.ini").read_text(encoding="ascii")
assert ini.count("set cpu 64k\n") == 1
names = {}
for line in (build / "kcore.map").read_text(encoding="ascii").splitlines():
    fields = line.split()
    if len(fields) > 1 and re.fullmatch(r"[0-7]+", fields[1]):
        names[fields[0]] = int(fields[1], 8)
required = ("proc_current_slot", "proc_high_slot", "mm_extent_count",
            "mm_arena_count", "mm_arenas", "mm_extents", "vfs_namespace_root")
assert all(key in names for key in required)
for unit in range(4):
    prefix = "attach -q dtc%d " % unit
    original = [line[len(prefix):] for line in ini.splitlines()
                if line.startswith(prefix)]
    assert len(original) == 1
    copied = work / "media" / ("dtc%d.tap" % unit)
    copied.write_bytes(Path(original[0]).read_bytes())
    ini = ini.replace(original[0], str(copied))
ini = "\n".join(line for line in ini.splitlines()
                if not line.startswith(("attach -q dsk", "attach -q dr"))) + "\n"
head = ini.replace("go 020\nexit\n", "")
assert head != ini


def stage(name):
    part = "echo V1652_STAGE_%s\n" % name
    for key in required:
        if key not in ("mm_arenas", "mm_extents"):
            part += "examine %06o\n" % names[key]
    part += "examine %06o-%06o\n" % (
        names["mm_arenas"], names["mm_arenas"] + 7)
    part += "examine %06o-%06o\n" % (
        names["mm_extents"], names["mm_extents"] + 95)
    return part + "echo V1652_END_%s\n" % name


tail = 'expect "aaaaaaaaax[B"\ngo 020\n' + stage("B")
tail += 'expect "[A"\ncont\n' + stage("A")
tail += 'expect "Z"\ncont\n' + stage("Z")
tail += "cont\nexit\n"
(work / "physical.ini").write_text(head + tail, encoding="ascii")
print("v1652: read-only original 64K MM checkpoints staged")
PY
port=$((37000 + ($$ % 7200)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port+12000))"
set +e
(
    cd "$PURE_64K_BUILD_V1652"
    TERM=dumb timeout -k 3s "${PURE_64K_TIMEOUT_V1652:-860}" \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini"
) >"$work/trace.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/trace.log" >"$work/trace.clean"
if [ "$rc" -ne 0 ]; then
    tail -55 "$work/trace.clean" >&2
    echo "FAIL v1652: physical MM replay simulator status=$rc" >&2
    exit 1
fi
for phase in B A Z; do
    # SIMH expect leaves guest output on the same console line as our
    # stage marker.  The stage parser separately validates uniqueness.
    grep -q "V1652_STAGE_$phase$" "$work/trace.clean"
    grep -q "^V1652_END_$phase$" "$work/trace.clean"
done
grep -q 'HALT instruction, PC: 000000' "$work/trace.clean"
echo 'PASS v1652: genuine independent 64K MM B/A/Z source-linked snapshots'
