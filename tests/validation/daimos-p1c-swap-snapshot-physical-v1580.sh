#!/bin/sh
# Full current-source KCC/PDP-6 two-boot MEMFS/LOGSTORE snapshot with
# genuine outstanding physical BACKSTORE process swap at the HALT entry.
# Only an isolated MRES source copy asserts positive swap ownership.
# This does not claim concurrent PI swap-in during synchronous HALT.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-swap-snapshot-v1580.XXXXXX")
if [ "${V1580_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1580 evidence: $work"
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
assert source.count(anchor) == 1, 'v1580 HALT snapshot entry source moved'
addition = ('        ; Test-only v1580: require a genuinely owned process swap\n'
            '        ; run on the physical backing at snapshot commit.\n'
            '        skipn   proc_swap_blocks_used\n'
            '        jrst    memfs_snapshot_shutdown_fail\n')
source = source.replace(anchor, anchor + addition, 1)
assert source.count('        .globl  backstore_blocks_used\n') == 1
source = source.replace('        .globl  backstore_blocks_used\n',
                        '        .globl  backstore_blocks_used\n'
                        '        .globl  proc_swap_blocks_used\n', 1)
out.write_text(source)
print('v1580: guarded original snapshot physical commit with real swap owner')
PY

export XIP_V1477_WORK="$work/persistent"
export XIP_V1477_SIZE=128
export XIP_V1477_KEEP=1
export XIP_V1576_P1C_LOGSTORE=1
export XIP_V1580_P1C_SWAP=1
export XIP_V1478_TEST_CFLAGS='-DXIP_P1C_LOGSTORE_V1576=1 -DXIP_P1C_SWAP_V1580=1'
export XIP_V1478_KERNEL_DIR="$work/source/system/kernel"

echo 'v1580: build actual 128K PDP-6 KCC guest, two fresh CPU cold boots'
sh "$self/daimos-memfs-snapshot-reboot-v1477.sh" \
    > "$work/fullguest-v1580.log" 2>&1 || {
    tail -110 "$work/fullguest-v1580.log" >&2
    exit 1
}

boot="$work/persistent/guest/build/system/boot/pdp6"
test -s "$work/persistent/swapped-physical-v1580.txt"
for n in 1 2; do
    log="$work/persistent/boot-$n/simh.log"
    test -s "$log"
    grep -Fq 'P1C-SWAP-CHILDREN-SLEEP-V1580' "$log"
    grep -Fq 'P1C-SWAP-HALT-REQUEST-V1580' "$log"
    grep -Fq 'P1C-LOGSTORE-APPEND-READBACK' "$log"
    if [ "$n" = 2 ]; then
        grep -Fq 'P1C-LOGSTORE-PREVIOUS-BOOT' "$log"
        grep -Fq 'XIP-SNAPSHOT-RESTORED' "$log"
    else
        grep -Fq 'XIP-SNAPSHOT-WRITTEN' "$log"
    fi
done
"$PDP10_PREFIX/bin/mkauxstore" --inspect "$boot/drum/dsk0.dsk" \
    > "$work/final-auxstore.inspect"
cmp "$work/persistent/auxstore-v1477.inspect" \
    "$work/final-auxstore.inspect"
echo 'PASS v1580: real swapped process ownership at physical MEMFS HALT'
echo 'PASS v1580: physical v2 snapshot and LOGSTORE cold-boot recovery'
echo 'P1-C remains open: live simultaneous PI/swap-in during HALT unproven'
