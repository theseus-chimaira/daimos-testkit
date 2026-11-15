#!/bin/sh
# Real PDP-6 DSK270 selected root, independent direct-DEVICE DRM0
# AUXSTORE, two genuine PI6 wakes, one fatal physical swap READ PI2.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-device-two-owner-v1600.XXXXXX")
if [ "${V1600_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1600 physical evidence: $work"
fi

mkdir -p "$work/source/system"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
kernel="$work/source/system/kernel"
python3 "$self/daimos-p1c-snapshot-swap-pi-v1584.py" "$kernel"
python3 "$self/daimos-p1c-snapshot-timer-v1585.py" "$kernel"
python3 "$self/daimos-p1c-two-owner-timer-v1592.py" "$kernel"
python3 "$self/daimos-p1c-swap-read-pi2-fault-v1586.py" "$kernel"

export XIP_V1477_WORK="$work/persistent"
export XIP_V1477_SIZE=128 XIP_V1477_KEEP=1
export XIP_V1576_P1C_LOGSTORE=1 XIP_V1580_P1C_SWAP=1
export XIP_V1584_P1C_OVERLAP=1 XIP_V1585_P1C_TIMED_WAKE=1
export XIP_V1592_P1C_TWO_OWNER=1 XIP_V1586_P1C_SWAP_READ_FAULT=1
export XIP_V1478_TEST_CFLAGS='-DXIP_P1C_LOGSTORE_V1576=1 -DXIP_P1C_SWAP_V1580=1'
export XIP_V1478_KERNEL_DIR="$kernel"

echo 'v1600: DSK270 root plus independent direct DRM0, real two-owner PI6/PI2'
sh "$self/daimos-memfs-snapshot-reboot-v1477.sh" \
    > "$work/fullguest-v1600.log" 2>&1 || {
    tail -110 "$work/fullguest-v1600.log" >&2
    exit 1
}
boot="$work/persistent/guest/build/system/boot/pdp6"
for f in kcore.map v1584-linked-addresses.txt \
    v1585-linked-addresses.txt v1586-linked-addresses.txt \
    v1592-linked-addresses.txt; do
    test -s "$boot/$f"
done
test -s "$work/persistent/boot-1/simh.log"
test -s "$work/persistent/auxstore-v1477.inspect"
test -s "$boot/drum/dsk0.dsk"
python3 "$self/daimos-p1c-device-two-owner-fatal-verify-v1600.py" --self-test \
    "$boot/kcore.map" "$boot/v1584-linked-addresses.txt" \
    "$boot/v1585-linked-addresses.txt" "$boot/v1586-linked-addresses.txt" \
    "$boot/v1592-linked-addresses.txt" \
    "$work/persistent/boot-1/simh.log" "$boot/drum/dsk0.dsk" \
    "$work/persistent/auxstore-v1477.inspect" "$boot/disk" \
    "$work/v1600-physical-verification.txt" \
    > "$work/v1600-verifier-output.txt"
cat "$work/v1600-physical-verification.txt"
echo 'PASS v1600: separate DRM0 DEVICE fault and four valid physical DSK root descriptors'
