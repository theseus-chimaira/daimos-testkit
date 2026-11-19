#!/bin/sh
# Physical 48K PDP-6 backing/mount guards while six children are PACKED.
# No production image or MM descriptor is modified by this read-only replay.
set -eu
: "${PURE_BACKING_GUARDS_BUILD_V1644:?source-built v1644 RW guest required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-backing-guards-v1644.XXXXXX")
trap 'echo "v1644 physical source-linked evidence: $work"' EXIT HUP INT TERM
mkdir -p "$work/media"
python3 - "$PURE_BACKING_GUARDS_BUILD_V1644" "$work" <<'PY'
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
               "vfs_mount_policy", "dtfs_media_base", "vfs_mount_root_base"):
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
    s = "echo V1644_STAGE_%s\n" % label
    for symbol in ("proc_current_slot", "proc_high_slot",
                   "mm_extent_count", "mm_arena_count",
                   "vfs_namespace_root", "vfs_mount_policy",
                   "dtfs_media_base", "vfs_mount_root_base"):
        s += "examine %06o\n" % sym[symbol]
    s += "examine %06o-%06o\n" % (
        sym["mm_arenas"], sym["mm_arenas"] + 7)
    s += "examine %06o-%06o\n" % (
        sym["mm_extents"], sym["mm_extents"] + 95)
    return s + "echo V1644_END_%s\n" % label


head = ini.replace("go 020\nexit\n", "")
assert head != ini
tail = 'expect "aaaaaax[B"\ngo 020\n' + snapshot("B")
tail += 'expect "[A"\ncont\n' + snapshot("A")

# Parent's first real operation after A is FSINFO followed by
# UNMOUNT.  Break only after A: actual proc_swap_mount_busy
# invocation must receive the secondary public mount ID 2.
tail += "break %06o\ncont\n" % sym["proc_swap_mount_busy"]
tail += "echo V1644_MOUNT_GUARD_ENTRY\nexamine 1\n"
tail += snapshot("MOUNT_BUSY")
tail += "nobreak\n"
# The next vnode guard invocation belongs to the source UNLINK;
# the exact original vnode must be provider 5/public mount 2.
tail += "break %06o\ncont\n" % sym["proc_swap_backing_busy"]
tail += "echo V1644_VNODE_GUARD_ENTRY\nexamine 1\n"
tail += snapshot("VNODE_BUSY")
tail += "nobreak\n"
tail += 'expect "P"\ncont\n' + snapshot("PROTECTED")
tail += 'expect "U"\ncont\n' + snapshot("RELEASED")
tail += 'expect "Z"\ncont\n' + snapshot("Z")
tail += "cont\nexit\n"
(out / "physical.ini").write_text(head + tail, encoding="ascii")
PY
port=$((35000 + ($$ % 9800)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port + 14000))"
set +e
(
    cd "$PURE_BACKING_GUARDS_BUILD_V1644"
    TERM=dumb timeout -k 3s "${PURE_BACKING_GUARDS_TIMEOUT_V1644:-1080}" \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini"
) >"$work/trace.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/trace.log" >"$work/trace.clean"
echo "v1644 simulator process status=$rc"
grep -E 'V1644_|Breakpoint, PC|HALT instruction|!.' \
    "$work/trace.clean" | tail -36 || :
test "$rc" -eq 0
for stage in B A MOUNT_BUSY VNODE_BUSY PROTECTED RELEASED Z; do
    grep -q "V1644_STAGE_${stage}$" "$work/trace.clean"
    grep -q "^V1644_END_${stage}$" "$work/trace.clean"
done
for tag in MOUNT_GUARD_ENTRY VNODE_GUARD_ENTRY; do
    grep -q "^V1644_${tag}$" "$work/trace.clean"
done
grep -q 'HALT instruction' "$work/trace.clean"
