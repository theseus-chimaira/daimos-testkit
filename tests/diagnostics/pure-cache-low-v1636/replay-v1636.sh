#!/bin/sh
# Record three original MM snapshots on the unmodified compiled v1636
# six-child 48K guest. Replaying source and media is read-only.
set -eu
: "${PURE_CACHE_LOW_BUILD_V1636:?preserved source-built guest required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
case "${PURE_CACHE_PROFILE_V1637:-six-resident}" in
six-resident)
    first_mark='aaaaaa[B'
    final_mark='LwwwwwwZ'
    stage_version=V1636
    ;;
six-packed)
    first_mark='aaaaaax[B'
    final_mark='LwwwwwwZ'
    stage_version=V1637
    ;;
*) echo 'FAIL: unknown versioned physical cache test profile' >&2
   exit 1 ;;
esac
work=$(mktemp -d "$TMPDIR/pure-cache-low-replay-v1636.XXXXXX")
trap 'echo "v1636 original physical MM replay: $work"' EXIT HUP INT TERM
mkdir -p "$work/media"
python3 - "$PURE_CACHE_LOW_BUILD_V1636" "$work" <<'PY'
from pathlib import Path
import re
import sys

boot, work = map(Path, sys.argv[1:])
source = (boot / "boot.ini").read_text(encoding="ascii")
sym = {}
for line in (boot / "kcore.map").read_text(encoding="ascii").splitlines():
    f = line.split()
    if len(f) >= 2 and re.fullmatch(r"[0-7]+", f[1]):
        sym[f[0]] = int(f[1], 8)
required = ("mm_arenas", "mm_arena_count", "mm_extents",
            "mm_extent_count", "proc_current_slot", "proc_high_slot")
assert all(label in sym for label in required)
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
port=$((34000 + ($$ % 10500)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$work/noaux.ini" "$work/replay.ini" "$port" "$((port+12000))"
python3 - "$PURE_CACHE_LOW_BUILD_V1636/kcore.map" \
    "$work/replay.ini" "$first_mark" "$final_mark" \
    "$stage_version" <<'PY'
from pathlib import Path
import re
import sys

sym = {}
for line in Path(sys.argv[1]).read_text(encoding="ascii").splitlines():
    f = line.split()
    if len(f) >= 2 and re.fullmatch(r"[0-7]+", f[1]):
        sym[f[0]] = int(f[1], 8)
path = Path(sys.argv[2])
first_mark, final_mark, version = sys.argv[3:6]
ini = path.read_text(encoding="ascii")
assert "go 020\nexit\n" in ini


def sample(stage):
    text = "echo %s_STAGE_%s\n" % (version, stage)
    for name in ("proc_current_slot", "proc_high_slot", "mm_arena_count",
                 "mm_extent_count"):
        text += "examine %06o\n" % sym[name]
    text += "examine %06o-%06o\n" % (
        sym["mm_arenas"], sym["mm_arenas"] + 7)
    text += "examine %06o-%06o\n" % (
        sym["mm_extents"], sym["mm_extents"] + 95)
    return text + "echo %s_END_%s\n" % (version, stage)


tail = 'expect "%s"\ngo 020\n' % first_mark + sample("B")
tail += 'expect "[A"\ncont\n' + sample("A")
tail += 'expect "%s"\ncont\n' % final_mark + sample("Z")
tail += 'cont\nexit\n'
path.write_text(ini.replace("go 020\nexit\n", tail, 1),
                encoding="ascii")
PY
set +e
(
    cd "$PURE_CACHE_LOW_BUILD_V1636"
    TERM=dumb timeout -k 3s "${PURE_CACHE_LOW_TIMEOUT_V1636:-540}" \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/replay.ini"
) >"$work/trace.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/trace.log" >"$work/trace.clean"
echo "v1636 source-matched physical replay status=$rc"
grep -E "${stage_version}_STAGE_|${stage_version}_END_|aaaaaa|LwwwwwwZ|HALT instruction" \
    "$work/trace.clean" | tail -22 || :
test "$rc" -eq 0
for stage in B A Z; do
    grep -q "${stage_version}_STAGE_$stage$" "$work/trace.clean"
    grep -q "^${stage_version}_END_$stage$" "$work/trace.clean"
done
grep -q 'HALT instruction' "$work/trace.clean"
