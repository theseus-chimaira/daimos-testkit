#!/bin/sh
# Full 128K PDP-6: persistent MEMFS snapshot selected PI2 error on a
# genuine four-member Type-236 D6FS root's mapped BACKSTORE tail.
# Reuse v1581's accepted real DR_DONE selection in disposable source.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-mapped-snapshot-v1583.XXXXXX")
if [ "${V1583_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1583 evidence: $work"
fi

mkdir -p "$work/source/system"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"

python3 - "$work/source/system/kernel/fs/memfs_snapshot_pdp6.s" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
source = path.read_text()
anchor = ('memfs_snapshot_shutdown:\n'
          '        add     17,[7,,7]\n'
          '        movei   0,-6(17)\n'
          '        hrli    0,010\n'
          '        blt     0,(17)\n')
assert source.count(anchor) == 1
source = source.replace(anchor, anchor +
                        '        skipn   proc_swap_blocks_used\n'
                        '        jrst    memfs_snapshot_shutdown_fail\n', 1)
needle = '        .globl  backstore_blocks_used\n'
assert source.count(needle) == 1
source = source.replace(needle, needle +
                        '        .globl  proc_swap_blocks_used\n', 1)
path.write_text(source)
print('v1583: original snapshot requires real positive process ownership')
PY

python3 "$self/daimos-p1c-snapshot-pi2-v1581.py" \
    "$work/source/system/kernel"

export XIP_V1477_WORK="$work/persistent"
export XIP_V1477_SIZE=128
export XIP_V1477_KEEP=1
export XIP_V1576_P1C_LOGSTORE=1
export XIP_V1580_P1C_SWAP=1
export XIP_V1581_P1C_SNAPFAULT=1
export XIP_V1583_VOLUME_DRM=1
export XIP_V1478_TEST_CFLAGS='-DXIP_P1C_LOGSTORE_V1576=1 -DXIP_P1C_SWAP_V1580=1'
export XIP_V1478_KERNEL_DIR="$work/source/system/kernel"

echo 'v1583: full 128K KCC PDP-6, real DR0..DR3 D6FS VOLUME, MEMFS snapshot PI2 fault'
sh "$self/daimos-memfs-snapshot-reboot-v1477.sh" \
    > "$work/fullguest-v1583.log" 2>&1 || {
    tail -100 "$work/fullguest-v1583.log" >&2
    exit 1
}

boot="$work/persistent/guest/build/system/boot/pdp6"
test -s "$boot/kcore.map"
test -s "$boot/v1581-linked-addresses.txt"
test -s "$work/persistent/boot-1/simh.log"
grep -Fq 'P1C-SWAP-HALT-REQUEST-V1580' \
    "$work/persistent/boot-1/simh.log"
grep -Fq 'P1C-LOGSTORE-APPEND-READBACK' \
    "$work/persistent/boot-1/simh.log"

python3 "$self/daimos-p1c-mapped-snapshot-verify-v1583.py" \
    --self-test "$boot/kcore.map" "$boot/v1581-linked-addresses.txt" \
    "$work/persistent/boot-1/simh.log" "$boot/drum" \
    "$work/v1583-physical-verification.txt"

echo 'PASS v1583: actual full PDP-6 mapped VOLUME snapshot PI2 fail-stop'
echo 'P1-C remains OPEN for independently scheduled concurrent swap-in and rollback'
