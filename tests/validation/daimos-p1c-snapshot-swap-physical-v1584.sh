#!/bin/sh
# Physical PDP-6 mapped snapshot recovery while observing whether the
# independent slot-0 scheduler actually swaps in during Type-236 PI2.
# All source instrumentation is restricted to one disposable kernel.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-swap-overlap-v1584.XXXXXX")
if [ "${V1584_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1584 evidence: $work"
fi

mkdir -p "$work/source/system"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 "$self/daimos-p1c-snapshot-swap-pi-v1584.py" \
    "$work/source/system/kernel"

export XIP_V1477_WORK="$work/persistent"
export XIP_V1477_SIZE=128
export XIP_V1477_KEEP=1
export XIP_V1576_P1C_LOGSTORE=1
export XIP_V1580_P1C_SWAP=1
export XIP_V1583_VOLUME_DRM=1
export XIP_V1584_P1C_OVERLAP=1
export XIP_V1478_TEST_CFLAGS='-DXIP_P1C_LOGSTORE_V1576=1 -DXIP_P1C_SWAP_V1580=1 -DXIP_P1C_OVERLAP_V1584=1'
export XIP_V1478_KERNEL_DIR="$work/source/system/kernel"

echo 'v1584: two full 128K PDP-6 cold boots on real mapped DR0..DR3'
sh "$self/daimos-memfs-snapshot-reboot-v1477.sh" \
    > "$work/fullguest-v1584.log" 2>&1 || {
    tail -110 "$work/fullguest-v1584.log" >&2
    exit 1
}

boot="$work/persistent/guest/build/system/boot/pdp6"
test -s "$boot/v1584-linked-addresses.txt"
for n in 1 2; do
    test -s "$work/persistent/boot-$n/simh.log"
    grep -Fq 'P1C-SWAP-HALT-REQUEST-V1580' \
        "$work/persistent/boot-$n/simh.log"
done
python3 "$self/daimos-p1c-snapshot-swap-verify-v1584.py" \
    --self-test "$boot/kcore.map" "$boot/v1584-linked-addresses.txt" \
    "$work/persistent/boot-1/simh.log" \
    "$work/persistent/boot-2/simh.log" "$boot/drum" \
    "$work/v1584-physical-verification.txt"
echo 'PASS v1584: real mapped snapshot commit and cold-boot restore with swapped owners'
echo 'P1-C overlap requires positive independent scheduler and matching swap PI2 witnesses'
