#!/bin/sh
# Physical PDP-6 PURE RUN versus a real v1562 DTFS quiescence bit.
# No production image or MM descriptor is modified by this read-only replay.
set -eu
: "${PURE_QUIESCE_RUN_BUILD_V1646:?source-built v1646 RW guest required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-quiesce-run-v1646.XXXXXX")
trap 'echo "v1646 physical source-linked evidence: $work"' EXIT HUP INT TERM
mkdir -p "$work/media"
python3 - "$PURE_QUIESCE_RUN_BUILD_V1646" "$work" <<'PY'
from pathlib import Path
import re
import sys

boot = Path(sys.argv[1])
out = Path(sys.argv[2])
ini = (boot / "boot.ini").read_text(encoding="ascii")
assert ini.count("set cpu 48k\n") == 1


def symbols(source):
    out = {}
    for line in source.splitlines():
        fields = line.split()
        if len(fields) >= 2 and re.fullmatch(r"[0-7]+", fields[1]):
            out[fields[0]] = int(fields[1], 8)
    return out


sym = symbols((boot / "kcore.map").read_text(encoding="ascii"))
assert sym["proc_swap_backing_busy"] == 0o3322
assert sym["proc_swap_mount_busy"] == 0o3431
for symbol in ("mm_arenas", "mm_extents", "mm_extent_count",
               "mm_arena_count", "proc_current_slot", "vfs_namespace_root",
               "vfs_mount_policy", "dtfs_media_base", "vfs_mount_root_base",
               "proc_timer_clock", "clk_tick_count",
               "proc_sched_deferred_ticks", "proc_swap_records"):
    assert symbol in sym

for i in range(4):
    pre = "attach -q dtc%d " % i
    original = [line[len(pre):] for line in ini.splitlines()
                if line.startswith(pre)]
    assert len(original) == 1
    copied = out / "media" / ("dtc%d.tap" % i)
    copied.write_bytes(Path(original[0]).read_bytes())
    ini = ini.replace(original[0], str(copied))

ini = "\n".join(line for line in ini.splitlines()
                if not line.startswith(("attach -q dsk", "attach -q dr"))) + "\n"
(out / "boot.ini").write_text(ini, encoding="ascii")


def snapshot(label):
    s = "echo V1646_STAGE_%s\n" % label
    for symbol in ("proc_current_slot", "proc_high_slot",
                   "mm_extent_count", "mm_arena_count",
                   "vfs_namespace_root", "vfs_mount_policy",
                   "dtfs_media_base", "vfs_mount_root_base",
                   "proc_timer_clock", "clk_tick_count",
                   "proc_sched_deferred_ticks", "proc_swap_records"):
        s += "examine %06o\n" % sym[symbol]
    s += "examine %06o-%06o\n" % (
        sym["proc_swap_records"], sym["proc_swap_records"] + 15)
    s += "examine %06o-%06o\n" % (
        sym["mm_arenas"], sym["mm_arenas"] + 7)
    s += "examine %06o-%06o\n" % (
        sym["mm_extents"], sym["mm_extents"] + 95)
    return s + "echo V1646_END_%s\n" % label


head = ini.replace("go 020\nexit\n", "")
assert head != ini
tail = 'expect "aaaaaax[B"\ngo 020\n' + snapshot("B")
tail += 'expect "[A"\ncont\n' + snapshot("A")
tail += 'expect "H"\ncont\n' + snapshot("WAKE")
tail += 'expect "T"\ncont\n' + snapshot("PI6_DONE")
tail += 'expect "S"\ncont\n' + snapshot("RACE_START")
tail += 'expect "Q"\ncont\n' + snapshot("BARRIER")
tail += 'expect "R"\ncont\n' + snapshot("RUN_REFUSED")
tail += 'expect "V"\ncont\n' + snapshot("UNMOUNT_DONE")
tail += 'expect "M"\ncont\n' + snapshot("REMOUNT")
tail += 'expect "A"\ncont\n' + snapshot("RUN_OK")
tail += 'expect "U"\ncont\n' + snapshot("RELEASED")
tail += 'expect "Z"\ncont\n' + snapshot("Z")
tail += 'cont\nexit\n'
(out / "physical.ini").write_text(head + tail, encoding="ascii")
PY
port=$((35000 + ($$ % 9800)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port + 14000))"
set +e
(
    cd "$PURE_QUIESCE_RUN_BUILD_V1646"
    TERM=dumb timeout -k 3s "${PURE_QUIESCE_RUN_TIMEOUT_V1646:-1080}" \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini"
) >"$work/trace.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/trace.log" >"$work/trace.clean"
echo "v1646 simulator process status=$rc"
grep -E 'V1646_|Breakpoint, PC|HALT instruction|!.' \
    "$work/trace.clean" | tail -36 || :
test "$rc" -eq 0
for stage in B A WAKE PI6_DONE RACE_START BARRIER RUN_REFUSED UNMOUNT_DONE REMOUNT RUN_OK RELEASED Z; do
    grep -q "V1646_STAGE_${stage}$" "$work/trace.clean"
    grep -q "^V1646_END_${stage}$" "$work/trace.clean"
done
grep -q 'HALT instruction' "$work/trace.clean"
