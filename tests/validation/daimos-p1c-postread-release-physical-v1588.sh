#!/bin/sh
# Two actual 128K KCC PDP-6 physical cold boots on DR0..DR3.
# At one independently scheduled swap-in, complete real mapped
# BACKSTORE READ and original MM unpin, then test-refuse checked free.
# The original post-I/O MM rollback must restore exact DISK ownership.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-postread-rollback-v1588.XXXXXX")
if [ "${V1588_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1588 evidence: $work"
fi

mkdir -p "$work/source/system"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 "$self/daimos-p1c-snapshot-swap-pi-v1584.py" \
    "$work/source/system/kernel"
python3 "$self/daimos-p1c-snapshot-timer-v1585.py" \
    "$work/source/system/kernel"
python3 "$self/daimos-p1c-postread-release-v1588.py" \
    "$work/source/system/kernel"

export XIP_V1477_WORK="$work/persistent"
export XIP_V1477_SIZE=128
export XIP_V1477_KEEP=1
export XIP_V1576_P1C_LOGSTORE=1
export XIP_V1580_P1C_SWAP=1
export XIP_V1583_VOLUME_DRM=1
export XIP_V1584_P1C_OVERLAP=1
export XIP_V1585_P1C_TIMED_WAKE=1
export XIP_V1588_P1C_POSTREAD_FREE_FAIL=1
export XIP_V1478_TEST_CFLAGS='-DXIP_P1C_LOGSTORE_V1576=1 -DXIP_P1C_SWAP_V1580=1'
export XIP_V1478_KERNEL_DIR="$work/source/system/kernel"

echo 'v1588: two real PDP-6 cold boots after one post-DMA release refusal'
sh "$self/daimos-memfs-snapshot-reboot-v1477.sh" \
    > "$work/fullguest-v1588.log" 2>&1 || {
    tail -120 "$work/fullguest-v1588.log" >&2
    exit 1
}

boot="$work/persistent/guest/build/system/boot/pdp6"
for file in kcore.map v1584-linked-addresses.txt \
    v1585-linked-addresses.txt v1588-linked-addresses.txt; do
    test -s "$boot/$file"
done
for n in 1 2; do
    test -s "$work/persistent/boot-$n/simh.log"
done

python3 "$self/daimos-p1c-postread-release-verify-v1588.py" \
    --self-test "$boot/kcore.map" "$boot/v1584-linked-addresses.txt" \
    "$boot/v1585-linked-addresses.txt" "$boot/v1588-linked-addresses.txt" \
    "$work/persistent/boot-1/simh.log" \
    "$work/persistent/boot-2/simh.log" "$boot/drum" \
    "$work/v1588-physical-verification.txt"

echo 'PASS v1588: post-DMA MM rollback with exact backing and BCACHE state'
