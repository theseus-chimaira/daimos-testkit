#!/bin/sh
# Full physical PDP-6 on DR0..DR3: original timer PI6 schedules an
# independent swapped process during real MEMFS snapshot DMA. Fault one
# genuine Type-236 PI2 DR_DONE belonging to its swap READ descriptor.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-swap-read-fault-v1586.XXXXXX")
if [ "${V1586_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1586 evidence: $work"
fi

mkdir -p "$work/source/system"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 "$self/daimos-p1c-snapshot-swap-pi-v1584.py" \
    "$work/source/system/kernel"
python3 "$self/daimos-p1c-snapshot-timer-v1585.py" \
    "$work/source/system/kernel"
python3 "$self/daimos-p1c-swap-read-pi2-fault-v1586.py" \
    "$work/source/system/kernel"

export XIP_V1477_WORK="$work/persistent"
export XIP_V1477_SIZE=128
export XIP_V1477_KEEP=1
export XIP_V1576_P1C_LOGSTORE=1
export XIP_V1580_P1C_SWAP=1
export XIP_V1583_VOLUME_DRM=1
export XIP_V1584_P1C_OVERLAP=1
export XIP_V1585_P1C_TIMED_WAKE=1
export XIP_V1586_P1C_SWAP_READ_FAULT=1
export XIP_V1478_TEST_CFLAGS='-DXIP_P1C_LOGSTORE_V1576=1 -DXIP_P1C_SWAP_V1580=1'
export XIP_V1478_KERNEL_DIR="$work/source/system/kernel"

echo 'v1586: full 128K PDP-6 mapped BACKSTORE physical swap READ PI2 failure'
sh "$self/daimos-memfs-snapshot-reboot-v1477.sh" \
    > "$work/fullguest-v1586.log" 2>&1 || {
    tail -120 "$work/fullguest-v1586.log" >&2
    exit 1
}

boot="$work/persistent/guest/build/system/boot/pdp6"
test -s "$boot/kcore.map"
test -s "$boot/v1584-linked-addresses.txt"
test -s "$boot/v1585-linked-addresses.txt"
test -s "$boot/v1586-linked-addresses.txt"
test -s "$work/persistent/boot-1/simh.log"
test -s "$work/persistent/volume-descriptors-v1583.bin"

python3 "$self/daimos-p1c-swap-read-fault-verify-v1586.py" \
    --self-test "$boot/kcore.map" "$boot/v1584-linked-addresses.txt" \
    "$boot/v1585-linked-addresses.txt" "$boot/v1586-linked-addresses.txt" \
    "$work/persistent/boot-1/simh.log" "$boot/drum" \
    "$work/persistent/volume-descriptors-v1583.bin" \
    "$work/v1586-physical-verification.txt"

echo 'PASS v1586: real swap-READ PI2 failure during independent PI6 snapshot overlap'
