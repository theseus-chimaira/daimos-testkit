#!/bin/sh
# Original two distinct PI6 SLEEP/DISK owner wakeups, then one genuine
# mapped Type-236 swap READ PI2 error enters original BACKSTORE fail-stop.
# This is not a recoverable rollback: continuing would violate P0-A.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-two-owner-fatal-v1599.XXXXXX")
if [ "${V1599_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1599 physical evidence: $work"
fi

# A disposable exact-source instrumented kernel is the only mutation.
# All scheduler, DRAM, MM, BACKSTORE and MRES paths remain original.
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
export XIP_V1583_VOLUME_DRM=1 XIP_V1584_P1C_OVERLAP=1
export XIP_V1585_P1C_TIMED_WAKE=1
export XIP_V1592_P1C_TWO_OWNER=1
export XIP_V1586_P1C_SWAP_READ_FAULT=1
export XIP_V1478_TEST_CFLAGS='-DXIP_P1C_LOGSTORE_V1576=1 -DXIP_P1C_SWAP_V1580=1'
export XIP_V1478_KERNEL_DIR="$kernel"

echo 'v1599: genuine two-owner PI6 wake and first owned Type-236 PI2 fatal'
sh "$self/daimos-memfs-snapshot-reboot-v1477.sh" \
    > "$work/fullguest-v1599.log" 2>&1 || {
    tail -125 "$work/fullguest-v1599.log" >&2
    exit 1
}
boot="$work/persistent/guest/build/system/boot/pdp6"
for file in kcore.map v1584-linked-addresses.txt \
    v1585-linked-addresses.txt v1586-linked-addresses.txt \
    v1592-linked-addresses.txt; do
    test -s "$boot/$file"
done
test -s "$work/persistent/boot-1/simh.log"
test -s "$work/persistent/volume-descriptors-v1583.bin"
python3 "$self/daimos-p1c-two-owner-fatal-verify-v1599.py" --self-test \
    "$boot/kcore.map" "$boot/v1584-linked-addresses.txt" \
    "$boot/v1585-linked-addresses.txt" "$boot/v1586-linked-addresses.txt" \
    "$boot/v1592-linked-addresses.txt" \
    "$work/persistent/boot-1/simh.log" "$boot/drum" \
    "$work/persistent/volume-descriptors-v1583.bin" \
    "$work/v1599-physical-verification.txt" \
    > "$work/v1599-verifier-output.txt"
cat "$work/v1599-physical-verification.txt"
echo 'PASS v1599: distinct PI6 owners remain owned at real fatal BACKSTORE read'
