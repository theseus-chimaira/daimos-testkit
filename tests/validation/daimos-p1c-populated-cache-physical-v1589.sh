#!/bin/sh
# Two genuine 128K PDP-6 DR0..DR3 cold boots: real D6FS physical read
# populates private BCACHE tag+128 words, original MM reclaims it while
# concurrent BACKSTORE swap/snapshot work is active. Stale cache identity
# must not survive separate post-DMA checked-release rollback.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-populated-cache-v1589.XXXXXX")
if [ "${V1589_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1589 evidence: $work"
fi

mkdir -p "$work/source/system"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 "$self/daimos-p1c-snapshot-swap-pi-v1584.py" \
    "$work/source/system/kernel"
python3 "$self/daimos-p1c-snapshot-timer-v1585.py" \
    "$work/source/system/kernel"
python3 "$self/daimos-p1c-populated-cache-v1589.py" \
    "$work/source/system/kernel"

export XIP_V1477_WORK="$work/persistent"
export XIP_V1477_SIZE=128 XIP_V1477_KEEP=1
export XIP_V1576_P1C_LOGSTORE=1 XIP_V1580_P1C_SWAP=1
export XIP_V1583_VOLUME_DRM=1 XIP_V1584_P1C_OVERLAP=1
export XIP_V1585_P1C_TIMED_WAKE=1
export XIP_V1588_P1C_POSTREAD_FREE_FAIL=1
export XIP_V1589_P1C_POPULATED_CACHE=1
export XIP_V1478_TEST_CFLAGS='-DXIP_P1C_LOGSTORE_V1576=1 -DXIP_P1C_SWAP_V1580=1 -DXIP_P1C_CACHE_V1589=1'
export XIP_V1478_KERNEL_DIR="$work/source/system/kernel"

echo 'v1589: real physical D6FS cache/PI2 and independent BACKSTORE rollback'
sh "$self/daimos-memfs-snapshot-reboot-v1477.sh" \
    > "$work/fullguest-v1589.log" 2>&1 || {
    tail -120 "$work/fullguest-v1589.log" >&2
    exit 1
}
boot="$work/persistent/guest/build/system/boot/pdp6"
for filename in kcore.map v1584-linked-addresses.txt \
    v1585-linked-addresses.txt v1588-linked-addresses.txt \
    v1589-linked-addresses.txt; do
    test -s "$boot/$filename"
done
for n in 1 2; do test -s "$work/persistent/boot-$n/simh.log"; done

python3 "$self/daimos-p1c-populated-cache-verify-v1589.py" \
    --self-test "$boot/kcore.map" "$boot/v1584-linked-addresses.txt" \
    "$boot/v1585-linked-addresses.txt" "$boot/v1588-linked-addresses.txt" \
    "$boot/v1589-linked-addresses.txt" \
    "$work/persistent/boot-1/simh.log" \
    "$work/persistent/boot-2/simh.log" "$boot/drum" \
    "$work/v1589-physical-verification.txt"

echo 'PASS v1589: original physical D6FS cache safely reclaimed during postread rollback'
