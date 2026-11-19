#!/bin/sh
# Source-authentic Type-551 search timeout regression: compile both the
# accepted v1617 tape driver and current v1618 against ONE fixed KCORE map.
# Require exactly two immediate changes, no word/BSS/relocation growth.
set -eu
: "${DAIMOS_REPO:?DAIMOS source checkout required}"
PDP10_PREFIX=${PDP10_PREFIX:-$HOME/cross}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
PATH="$PDP10_PREFIX/bin:$PATH"
export PATH
mkdir -p "$TMPDIR"
work=$(mktemp -d "$TMPDIR/dtc-timeout-v1618.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

source_v1618="$DAIMOS_REPO/system/kernel/drivers/tape_io.s"
git -C "$DAIMOS_REPO" show \
    d686c59b:system/kernel/drivers/tape_io.s >"$work/tape-v1617.s"

# Use an installed map when explicitly supplied, or build a matching
# low-memory 48K KCORE map with the current source tree.
map=${DTC_KCORE_MAP_V1618:-}
if [ -z "$map" ]; then
    build="$work/kcore"
    mkdir -p "$build"
    make -s -C "$DAIMOS_REPO/system/boot/pdp6" \
        BUILD="$build" ROOT=tape BOOT=dtc \
        BOOT_PROFILE=lowmem COMPILER=gcc \
        BOOT_CORE_WORDS=0140000 SIMH_CPU_KWORDS=48 \
        TSFS_ROOT_MEMBERS=3 TSFS_INPLACE_BOOT=1 \
        PROC_BOOT_USERS=1 DAIMOS_PURE_MRES_ENABLED=1 \
        "$build/kcore.map" >"$work/build.log" 2>&1 || {
        tail -60 "$work/build.log" >&2
        exit 1
    }
    map="$build/kcore.map"
fi
test -s "$map"

compile_tape()
{
    tag=$1
    source=$2
    das -C -F -O "$work/$tag.dobj" "$source"
    dlink -b 0 -A "$map" -o "$work/$tag.dxr" \
        -M "$work/$tag.map" -R "$work/$tag-mres.dobj" \
        -N tape_mres_package -X tape_pi_handler \
        -X dtc_read_block -X mtc_service -X dtc_write_block \
        -X tape_dct_handler -X tape_watchdog_tick_v1089 \
        "$work/$tag.dobj"
}
compile_tape old "$work/tape-v1617.s"
compile_tape new "$source_v1618"

python3 - "$work/old.dxr" "$work/new.dxr" \
    "$work/tape-v1617.s" "$source_v1618" <<'PY'
import re
import subprocess
import sys
from pathlib import Path


def load(path):
    s = subprocess.check_output(["dxrcheck", "-d", path], text=True)
    m = re.search(r"\bimage=([0-7]+) bss=([0-7]+) "
                  r"reloc=([0-7]+)\b", s)
    assert m, "missing linked DXR geometry"
    words = {int(a, 8): int(w, 8) for a, w in re.findall(
        r"(?m)^IMAGE\s+([0-7]{6})\s+([0-7]{12})$", s)}
    return tuple(int(x, 8) for x in m.groups()), words


geometry_old, old = load(sys.argv[1])
geometry_new, new = load(sys.argv[2])
assert geometry_old == geometry_new == (0o607, 0o17, 0o13)
assert old.keys() == new.keys()
diff = [address for address in sorted(old)
        if old[address] != new[address]]
assert diff == [0o343, 0o405], "unexpected tape executable code changes"
assert old[0o343] == 0o561200772564
assert old[0o405] == 0o561100772564
assert new[0o343] == 0o561200761740
assert new[0o405] == 0o561100761740
old_source = Path(sys.argv[3]).read_text()
new_source = Path(sys.argv[4]).read_text()
assert ".set DTC_SEARCH_TIMEOUT_TICKS,05214" in old_source
assert ".set DTC_SEARCH_TIMEOUT_TICKS,016040" in new_source
assert ".set MTC_CONTROL_TIMEOUT_TICKS,0151440" in new_source
assert ".set TAPE_DTC_DATA_TIMEOUT_TICKS,0454" in new_source
assert ".set TAPE_MTC_DATA_TIMEOUT_TICKS,012430" in new_source
print("PASS v1618: 120s at 60 Hz = 016040 PDP-10 ticks")
print("PASS v1618: both search and PI3 rearm use -016040")
print("PASS v1618: MTC control, data watchdogs unchanged")
print("PASS v1618: only two immediate words changed, no module growth")
PY

# A source-authentic historical 45-second regression must be rejected
# by the new 120-second executable oracle.
if python3 - "$work/old.dxr" >"$work/negative.log" 2>&1 <<'PY'
import re
import subprocess
import sys
s = subprocess.check_output(["dxrcheck", "-d", sys.argv[1]],
                            text=True)
words = {int(a, 8): int(w, 8) for a, w in re.findall(
    r"(?m)^IMAGE\s+([0-7]{6})\s+([0-7]{12})$", s)}
if (words[0o343] != 0o561200761740 or
        words[0o405] != 0o561100761740):
    print("REJECT v1618: historical 45s image is not 120s")
    raise SystemExit(1)
PY
then
    echo 'FAIL v1618: historical 45s module passed 120s oracle' >&2
    exit 1
fi
grep -q '^REJECT v1618:' "$work/negative.log"
echo 'PASS v1618: unsafe old 45s linked module rejected'
