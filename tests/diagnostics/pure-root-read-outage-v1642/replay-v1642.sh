#!/bin/sh
# Physically detach the THREE actual TSFS boot-root Type-551 members
# only AFTER a v1391 FULL destination APR has been allocated/pinned.
# A ROOT read failure is intentionally terminal by v1538 design.
set -eu
: "${PURE_ROOT_OUTAGE_BUILD_V1642:?original v1638 mixed-PURE build required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-root-read-outage-v1642.XXXXXX")
trap 'echo "v1642 source-linked physical evidence: $work"' EXIT HUP INT TERM
mkdir -p "$work/media"
python3 - "$PURE_ROOT_OUTAGE_BUILD_V1642" "$work" \
    "$PDP10_PREFIX/bin/dxrcheck" <<'PY'
from pathlib import Path
import re
import subprocess
import sys

boot = Path(sys.argv[1])
out = Path(sys.argv[2])
input_ini = (boot / "boot.ini").read_text(encoding="ascii")
assert input_ini.count("set cpu 48k\n") == 1


def symbols(source):
    data = {}
    for line in source.splitlines():
        f = line.split()
        if len(f) >= 2 and re.fullmatch(r"[0-7]+", f[1]):
            data[f[0]] = int(f[1], 8)
    return data


kcore = symbols((boot / "kcore.map").read_text(encoding="ascii"))
mres = symbols((boot / "pure-mres-v1612.map").read_text(encoding="ascii"))
assert kcore["kcore_root_fs_io_failure_v1538"] == 0o3761
assert kcore["kcore_critical_device_lost_v1515"] == 0o3773
assert mres["exec_image_full_bounded_v1391"] == 0o3224
assert "vfs_namespace_root" in kcore
full = 0o32026 + mres["exec_image_full_bounded_v1391"]
image = subprocess.check_output([sys.argv[3], "-d",
                                str(boot / "pure-mres-v1612.dxr")],
                               encoding="ascii")
assert re.search(r"(?m)^IMAGE  003224 200000000004$", image)

for i in range(4):
    prefix = "attach -q dtc%d " % i
    original = [line[len(prefix):] for line in input_ini.splitlines()
                if line.startswith(prefix)]
    assert len(original) == 1
    dst = out / "media" / ("dtc%d.tap" % i)
    dst.write_bytes(Path(original[0]).read_bytes())
    input_ini = input_ini.replace(original[0], str(dst))

input_ini = "\n".join(line for line in input_ini.splitlines()
                      if not line.startswith(("attach -q dsk", "attach -q dr"))) + "\n"
(out / "boot.ini").write_text(input_ini, encoding="ascii")


def snapshot(phase):
    commands = "echo V1642_STAGE_%s\n" % phase
    for n in ("proc_current_slot", "proc_high_slot", "mm_extent_count",
              "mm_arena_count", "vfs_namespace_root"):
        commands += "examine %06o\n" % kcore[n]
    commands += "examine %06o-%06o\n" % (
        kcore["mm_arenas"], kcore["mm_arenas"] + 7)
    commands += "examine %06o-%06o\n" % (
        kcore["mm_extents"], kcore["mm_extents"] + 95)
    return commands + "echo V1642_END_%s\n" % phase


head = input_ini.replace("go 020\nexit\n", "")
assert head != input_ini
tail = 'expect "aaaaaax[B"\ngo 020\n' + snapshot("B")
tail += 'expect "[A"\ncont\n' + snapshot("A")
tail += "examine %06o\n" % full
tail += "break %06o\ncont\n" % full
tail += "echo V1642_BOUNDED_FULL_PRE_OFFLINE\n"
for i in (1, 2, 3, 4):
    tail += "examine %o\n" % i
tail += snapshot("FULL_PINNED")
tail += "nobreak\n"
for i in (0, 1, 2):
    tail += "detach dtc%d\n" % i
    tail += "echo V1642_DETACHED_DTC%d\n" % i
    tail += "show dtc%d\n" % i
    tail += "echo V1642_END_DETACH_DTC%d\n" % i
tail += "break %06o\ncont\n" % kcore["kcore_root_fs_io_failure_v1538"]
tail += "echo V1642_ROOT_FAILURE_CLASSIFIER\n"
tail += "examine 1\nexamine 2\n"
tail += snapshot("REAL_IO_FAILURE")
tail += "nobreak\ncont\n"
tail += "echo V1642_TERMINAL_ROOT_HALT\n"
tail += "examine %06o\n" % (kcore["kcore_critical_device_lost_v1515"] + 3)
tail += "exit\n"
(out / "physical.ini").write_text(head + tail, encoding="ascii")
PY
port=$((38000 + ($$ % 7700)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$work/physical.ini" "$work/headless.ini" "$port" "$((port+8000))"
set +e
(
    cd "$PURE_ROOT_OUTAGE_BUILD_V1642"
    TERM=dumb timeout -k 3s "${PURE_ROOT_OUTAGE_TIMEOUT_V1642:-480}" \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/headless.ini"
) >"$work/trace.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/trace.log" >"$work/trace.clean"
echo "v1642 simulator process status=$rc"
grep -E 'V1642_|Breakpoint, PC|HALT instruction|not attached|disabled' \
    "$work/trace.clean" | tail -36 || :
test "$rc" -eq 0
for name in B A FULL_PINNED REAL_IO_FAILURE; do
    grep -q "V1642_STAGE_$name$" "$work/trace.clean"
    grep -q "^V1642_END_$name$" "$work/trace.clean"
done
grep -q '^V1642_TERMINAL_ROOT_HALT$' "$work/trace.clean"
grep -q 'HALT instruction' "$work/trace.clean"
