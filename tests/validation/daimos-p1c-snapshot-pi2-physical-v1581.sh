#!/bin/sh
# Full PDP-6 physical failure: real Type-236 PI2 DONE on the first
# persistent MEMFS snapshot header WRITE, while real process swap is owned.
# Only disposable kernel source copies are instrumented; fail-stop is
# original v1541 KCORE. Not a claim of natural hardware/media failure.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-snapshot-pi2-v1581.XXXXXX")
if [ "${V1581_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1581 evidence: $work"
fi
mkdir -p "$work/source/system"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"

python3 - "$DAIMOS_REPO/system/kernel/fs/memfs_snapshot_pdp6.s" \
    "$work/source/system/kernel/fs/memfs_snapshot_pdp6.s" <<'PY'
from pathlib import Path
import sys

original, out = (Path(s) for s in sys.argv[1:])
source = original.read_text()
anchor = ('memfs_snapshot_shutdown:\n'
          '        add     17,[7,,7]\n'
          '        movei   0,-6(17)\n'
          '        hrli    0,010\n'
          '        blt     0,(17)\n')
assert source.count(anchor) == 1, 'v1581 source-linked snapshot entry moved'
source = source.replace(anchor, anchor +
                        '        skipn   proc_swap_blocks_used\n'
                        '        jrst    memfs_snapshot_shutdown_fail\n', 1)
anchor = '        .globl  backstore_blocks_used\n'
assert source.count(anchor) == 1
source = source.replace(anchor, anchor +
                        '        .globl  proc_swap_blocks_used\n', 1)
out.write_text(source)
print('v1581: original snapshot refuses unowned HALT')
PY

python3 "$self/daimos-p1c-snapshot-pi2-v1581.py" \
    "$work/source/system/kernel"

export XIP_V1477_WORK="$work/persistent"
export XIP_V1477_SIZE=128
export XIP_V1477_KEEP=1
export XIP_V1576_P1C_LOGSTORE=1
export XIP_V1580_P1C_SWAP=1
export XIP_V1581_P1C_SNAPFAULT=1
export XIP_V1478_TEST_CFLAGS='-DXIP_P1C_LOGSTORE_V1576=1 -DXIP_P1C_SWAP_V1580=1'
export XIP_V1478_KERNEL_DIR="$work/source/system/kernel"

echo 'v1581: full 128K PDP-6 physical guest with selected snapshot PI2 error'
sh "$self/daimos-memfs-snapshot-reboot-v1477.sh" \
    > "$work/fullguest-v1581.log" 2>&1 || {
    tail -110 "$work/fullguest-v1581.log" >&2
    exit 1
}

boot="$work/persistent/guest/build/system/boot/pdp6"
test -s "$boot/v1581-linked-addresses.txt"
test -s "$work/persistent/boot-1/simh.log"
grep -Fq 'P1C-SWAP-CHILDREN-SLEEP-V1580' \
    "$work/persistent/boot-1/simh.log"
grep -Fq 'P1C-SWAP-HALT-REQUEST-V1580' \
    "$work/persistent/boot-1/simh.log"
grep -Fq 'P1C-LOGSTORE-APPEND-READBACK' \
    "$work/persistent/boot-1/simh.log"

python3 "$self/daimos-p1c-snapshot-pi2-verify-v1581.py" \
    --self-test "$boot/kcore.map" "$boot/v1581-linked-addresses.txt" \
    "$work/persistent/boot-1/simh.log" "$boot/drum/dsk0.dsk" \
    "$work/persistent/auxstore-after-boot-1.inspect" \
    "$work/v1581-physical-verification.txt"

"$PDP10_PREFIX/bin/mkauxstore" --inspect "$boot/drum/dsk0.dsk" \
    > "$work/auxstore-after-fatal.inspect"
cmp "$work/persistent/auxstore-v1477.inspect" \
    "$work/auxstore-after-fatal.inspect"
echo 'PASS v1581: actual Type-236 PI2 physical snapshot failure hit BACKSTORE fatal'
echo 'PASS v1581: outstanding swap owner and invalid physical commit header'
echo 'P1-C OPEN: independent swap-in PI overlap, mapped VOLUME and natural device fault'
