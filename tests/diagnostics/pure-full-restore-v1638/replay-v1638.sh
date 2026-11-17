#!/bin/sh
# Read-only PDP-6 simulator: stop at the real bounded FULL loader after
# a plain child has returned its complete APR, then inspect MM ownership.
set -eu
: "${PURE_FULL_BUILD_V1638:?source-matched mixed-PURE 48K build required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
mkdir -p "$TMPDIR"
here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
testkit=$(CDPATH= cd -- "$here/../../.." && pwd)
work=$(mktemp -d "$TMPDIR/pure-full-restore-v1638.XXXXXX")
trap 'echo "v1638 original full-path MM evidence: $work"' EXIT HUP INT TERM
mkdir -p "$work/media"
python3 - "$PURE_FULL_BUILD_V1638" "$work" \
    "$PDP10_PREFIX/bin/dxrcheck" <<'PY'
from pathlib import Path
import re
import subprocess
import sys

boot = Path(sys.argv[1])
work = Path(sys.argv[2])
dxrcheck = sys.argv[3]
source = (boot / "boot.ini").read_text(encoding="ascii")


def symbols(p):
    out = {}
    for line in p.read_text(encoding="ascii").splitlines():
        f = line.split()
        if len(f) >= 2 and re.fullmatch(r"[0-7]+", f[1]):
            out[f[0]] = int(f[1], 8)
    return out


sym = symbols(boot / "pure-mres-v1612.map")
assert sym["exec_image_full_bounded_v1391"] == 0o3224
assert sym["proc_pure_ram_restore_v1391"] == 0o2207
assert sym["mm_pure_commit_prefix_v1384"] == 0o2565
data = subprocess.check_output([dxrcheck, "-d",
                                str(boot / "pure-mres-v1612.dxr")],
                               encoding="ascii", text=True)
assert "IMAGE  003224 " in data
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
port=$((34000 + ($$ % 9500)))
sh "$testkit/tests/lib/daimos-simh-headless.sh" \
    "$work/noaux.ini" "$work/trace.ini" "$port" "$((port+12000))"
python3 - "$PURE_FULL_BUILD_V1638/kcore.map" \
    "$work/trace.ini" "$PURE_FULL_BUILD_V1638/pure-mres-v1612.dxr" \
    "$PDP10_PREFIX/bin/dxrcheck" "${PURE_FULL_PROFILE_V1640:-}" <<'PY'
from pathlib import Path
import re
import subprocess
import sys

sym = {}
for line in Path(sys.argv[1]).read_text(encoding="ascii").splitlines():
    f = line.split()
    if len(f) >= 2 and re.fullmatch(r"[0-7]+", f[1]):
        sym[f[0]] = int(f[1], 8)
for name in ("mm_arenas", "mm_arena_count", "mm_extents",
             "mm_extent_count", "proc_current_slot", "proc_high_slot"):
    assert name in sym
path = Path(sys.argv[2])
ini = path.read_text(encoding="ascii")
assert "go 020\nexit\n" in ini
loaded_base = 0o32026   # original v1636/v1637 compiled PURE MRES placement
bounded_full = loaded_base + 0o3224
image = subprocess.check_output([sys.argv[4], "-d", sys.argv[3]],
                                encoding="ascii", text=True)
opcode = re.search(r"(?m)^IMAGE  003224 ([0-7]{12})$", image)
assert opcode, "original PURE DXR full loader entry absent"
profile = sys.argv[5]
assert profile in ("", "refusal")
version = "V1640" if profile else "V1638"
(path.parent / "profile.txt").write_text(version + "\n", encoding="ascii")
(path.parent / "full-entry.txt").write_text(
    "%06o %s\n" % (bounded_full, opcode.group(1)), encoding="ascii")


def snapshot(stage):
    out = "echo %s_STAGE_%s\n" % (version, stage)
    for name in ("proc_current_slot", "proc_high_slot", "mm_arena_count",
                 "mm_extent_count"):
        out += "examine %06o\n" % sym[name]
    out += "examine %06o-%06o\n" % (
        sym["mm_arenas"], sym["mm_arenas"] + 7)
    out += "examine %06o-%06o\n" % (
        sym["mm_extents"], sym["mm_extents"] + 95)
    return out + "echo %s_END_%s\n" % (version, stage)


tail = 'expect "aaaaaax[B"\ngo 020\n' + snapshot("B")
tail += 'expect "[A"\ncont\n' + snapshot("A")
if profile:
    # These two addresses are extracted from the unchanged original
    # compiled PURE MRES: the first instruction after the v1391 MM
    # allocation call, and the return to the v1612 service after v1391
    # has released its source pin on the failed-allocation path.
    assert re.search(r"(?m)^IMAGE  002307 260740001461$", image)
    assert re.search(r"(?m)^IMAGE  000432 260740002207$", image)
    alloc_return = loaded_base + 0o2310
    service_return = loaded_base + 0o433
    tail += "echo V1640_EXPECT_REAL_NOMEM\n"
    tail += "examine %06o\n" % alloc_return
    tail += "break %06o\ncont\n" % alloc_return
    tail += "echo V1640_ALLOC_RETURN\n"
    for i in (1, 2, 3, 4):
        tail += "examine %o\n" % i
    tail += snapshot("PINNED_FAILURE")
    tail += "nobreak\nbreak %06o\ncont\n" % service_return
    tail += "echo V1640_ROLLBACK_RETURN\n"
    for i in (1, 2, 3, 4):
        tail += "examine %o\n" % i
    tail += snapshot("ROLLED_BACK")
    tail += "nobreak\n"
tail += "echo %s_EXPECT_FULL\n" % version
tail += "examine %06o\n" % bounded_full
tail += "break %06o\ncont\n" % bounded_full
tail += "echo %s_BOUNDED_FULL\n" % version
for i in (1, 2, 3, 4):
    tail += "examine %o\n" % i
tail += snapshot("FULL")
tail += "nobreak\n"
# The first plain child can already have printed its `w` before
# the FULL callback. Trigger only on the final parent Z marker.
tail += 'expect "Z"\ncont\n' + snapshot("Z")
tail += "cont\nexit\n"
path.write_text(ini.replace("go 020\nexit\n", tail, 1), encoding="ascii")
PY
set +e
(
    cd "$PURE_FULL_BUILD_V1638"
    TERM=dumb timeout -k 3s "${PURE_FULL_TIMEOUT_V1638:-750}" \
        stdbuf -o0 -e0 "$PDP10_PREFIX/bin/pdp6" "$work/trace.ini"
) >"$work/trace.log" 2>&1
rc=$?
set -e
tr -d '\r' <"$work/trace.log" >"$work/trace.clean"
echo "v1638 simulator status=$rc"
grep -E 'V1638_|V1640_|Breakpoint, PC|wwwwwwZ|HALT instruction' \
    "$work/trace.clean" | tail -25 || :
test "$rc" -eq 0
version=$(cat "$work/profile.txt")
for stage in B A FULL Z; do
    grep -q "${version}_STAGE_$stage$" "$work/trace.clean"
    grep -q "^${version}_END_$stage$" "$work/trace.clean"
done
grep -q "${version}_BOUNDED_FULL" "$work/trace.clean"
if [ "$version" = V1640 ]; then
    for stage in PINNED_FAILURE ROLLED_BACK; do
        grep -q "V1640_STAGE_$stage$" "$work/trace.clean"
        grep -q "^V1640_END_$stage$" "$work/trace.clean"
    done
fi
grep -q 'HALT instruction' "$work/trace.clean"
