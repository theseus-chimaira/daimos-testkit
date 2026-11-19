#!/bin/sh
# Physically lose a READ-ONLY secondary DTFS executable backing during
# an original v1391 FULL restore; selected TSFS ROOT stays attached.
set -eu
: "${PURE_SECONDARY_BUILD_V1643:?original physical secondary guest/build required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-secondary-read-v1643.XXXXXX")
trap 'echo "v1643 original source-linked physical evidence: $work"' EXIT HUP INT TERM
mkdir -p "$work/media"
python3 - "$PURE_SECONDARY_BUILD_V1643" "$work" \
    "$PDP10_PREFIX/bin/dxrcheck" <<'PY'
from pathlib import Path
import re
import subprocess
import sys

boot = Path(sys.argv[1])
out = Path(sys.argv[2])
ini = (boot / "boot.ini").read_text(encoding="ascii")
assert ini.count("set cpu 48k\n") == 1


def symbols(path):
    sym = {}
    for line in path.read_text(encoding="ascii").splitlines():
        fields = line.split()
        if len(fields) >= 2 and re.fullmatch(r"[0-7]+", fields[1]):
            sym[fields[0]] = int(fields[1], 8)
    return sym


core = symbols(boot / "kcore.map")
mres = symbols(boot / "pure-mres-v1612.map")
assert core["kcore_root_fs_io_failure_v1538"] == 0o3761
assert mres["exec_image_full_bounded_v1391"] == 0o3224
assert mres["proc_pure_ram_restore_v1391"] == 0o2207
full = 0o32026 + mres["exec_image_full_bounded_v1391"]
service = 0o32026 + 0o433
loader_return = 0o32026 + 0o2333
image = subprocess.check_output([sys.argv[3], "-d",
                                str(boot / "pure-mres-v1612.dxr")],
                               encoding="ascii")
for offset, word in ((0o3224, "200000000004"),
                     (0o0432, "260740002207"),
                     (0o0433, "326040000451"),
                     (0o2333, "561400777774")):
    assert ("IMAGE  %06o %s" % (offset, word)) in image
for unit in range(4):
    pre = "attach -q dtc%d " % unit
    path = [line[len(pre):] for line in ini.splitlines()
            if line.startswith(pre)]
    assert len(path) == 1
    private = out / "media" / ("dtc%d.tap" % unit)
    private.write_bytes(Path(path[0]).read_bytes())
    ini = ini.replace(path[0], str(private))
ini = "\n".join(line for line in ini.splitlines()
                if not line.startswith(("attach -q dsk", "attach -q dr"))) + "\n"
(out / "boot.ini").write_text(ini, encoding="ascii")


def snapshot(name):
    s = "echo V1643_STAGE_%s\n" % name
    for key in ("proc_current_slot", "proc_high_slot", "mm_extent_count",
                "mm_arena_count", "vfs_namespace_root", "dtfs_media_base",
                "vfs_mount_root_base"):
        s += "examine %06o\n" % core[key]
    s += "examine %06o-%06o\n" % (
        core["mm_arenas"], core["mm_arenas"] + 7)
    s += "examine %06o-%06o\n" % (
        core["mm_extents"], core["mm_extents"] + 95)
    return s + "echo V1643_END_%s\n" % name


head = ini.replace("go 020\nexit\n", "")
assert head != ini
tail = 'expect "aaaaaax[B"\ngo 020\n' + snapshot("B")
tail += 'expect "[A"\ncont\n' + snapshot("A")
tail += "examine %06o\n" % full
tail += "break %06o\ncont\n" % full
tail += "echo V1643_BOUNDED_FULL_SECONDARY\n"
for ac in range(1, 5):
    tail += "examine %o\n" % ac
tail += snapshot("FULL_PINNED")
tail += "nobreak\ndetach dtc3\n"
tail += "echo V1643_DTC3_DETACHED\nshow dtc3\n"
tail += "echo V1643_END_DTC3_DETACHED\n"
tail += "break %06o\ncont\n" % service
tail += "echo V1643_FAILED_FULL_RETURN\n"
for ac in range(1, 5):
    tail += "examine %o\n" % ac
tail += snapshot("ROLLED_BACK")
tail += "nobreak\n"
tail += "attach -q dtc3 %s\n" % (out / "media/dtc3.tap")
tail += "echo V1643_SAME_DTC3_REATTACHED\nshow dtc3\n"
tail += "echo V1643_END_DTC3_REATTACHED\n"
tail += "break %06o\ncont\n" % loader_return
tail += "echo V1643_LATER_FULL_CALLBACK\nexamine 1\n"
tail += snapshot("LATER_FULL")
tail += "nobreak\n"
tail += 'expect "Z"\ncont\n' + snapshot("Z")
tail += "cont\nexit\n"
(out / "physical.ini").write_text(head + tail, encoding="ascii")
PY
port=$((37000 + ($$ % 7900)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port + 12000))"
set +e
(
    cd "$PURE_SECONDARY_BUILD_V1643"
    TERM=dumb timeout -k 3s "${PURE_SECONDARY_TIMEOUT_V1643:-950}" \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini"
) >"$work/trace.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/trace.log" >"$work/trace.clean"
echo "v1643 simulator process status=$rc"
grep -E 'V1643_|Breakpoint, PC|wwwwwwZ|HALT instruction|not attached' \
    "$work/trace.clean" | tail -38 || :
test "$rc" -eq 0
for name in B A FULL_PINNED ROLLED_BACK LATER_FULL Z; do
    grep -q "V1643_STAGE_$name$" "$work/trace.clean"
    grep -q "^V1643_END_$name$" "$work/trace.clean"
done
for mark in BOUNDED_FULL_SECONDARY DTC3_DETACHED \
            FAILED_FULL_RETURN SAME_DTC3_REATTACHED \
            LATER_FULL_CALLBACK; do
    grep -q "^V1643_$mark$" "$work/trace.clean"
done
grep -q 'HALT instruction' "$work/trace.clean"
