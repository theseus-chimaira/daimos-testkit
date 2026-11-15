#!/bin/sh
# Original clean D6FS BCACHE must survive actual recoverable LOGSTORE
# torn physical Type-236 commit and same-slot retry. Then independently
# prove normal v1588 PI6 swap/MM rollback and durable two-boot recovery.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-live-cache-logfault-v1590.XXXXXX")
if [ "${V1590_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1590 evidence: $work"
fi
mkdir -p "$work/source/system"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
root="$work/source/system/kernel"
python3 "$self/daimos-p1c-snapshot-swap-pi-v1584.py" "$root"
python3 "$self/daimos-p1c-snapshot-timer-v1585.py" "$root"
python3 "$self/daimos-p1c-postread-release-v1588.py" "$root"
python3 "$self/daimos-p1c-logstore-torn-v1577.py" \
    "$root/storage/logstore_runtime.s" \
    "$root/storage/logstore_runtime-v1590.s"
mv "$root/storage/logstore_runtime-v1590.s" \
    "$root/storage/logstore_runtime.s"
python3 "$self/daimos-p1c-live-cache-logfault-v1590.py" "$root"

export XIP_V1477_WORK="$work/persistent"
export XIP_V1477_SIZE=128 XIP_V1477_KEEP=1
export XIP_V1576_P1C_LOGSTORE=1 XIP_V1580_P1C_SWAP=1
export XIP_V1583_VOLUME_DRM=1 XIP_V1584_P1C_OVERLAP=1
export XIP_V1585_P1C_TIMED_WAKE=1
export XIP_V1588_P1C_POSTREAD_FREE_FAIL=1
export XIP_V1590_P1C_LIVE_CACHE_LOGFAULT=1
export XIP_V1478_TEST_CFLAGS='-DXIP_P1C_LOGSTORE_V1576=1 -DXIP_P1C_LOGFAULT_V1577=1 -DXIP_P1C_SWAP_V1580=1 -DXIP_P1C_CACHE_V1590=1'
export XIP_V1478_KERNEL_DIR="$root"

echo 'v1590: physical torn LOGSTORE with live D6FS cache, then PI6 swap'
sh "$self/daimos-memfs-snapshot-reboot-v1477.sh" \
    > "$work/fullguest-v1590.log" 2>&1 || {
    tail -120 "$work/fullguest-v1590.log" >&2
    exit 1
}
boot="$work/persistent/guest/build/system/boot/pdp6"
for file in kcore.map v1584-linked-addresses.txt \
    v1585-linked-addresses.txt v1588-linked-addresses.txt \
    v1590-linked-addresses.txt logstore-mres.map; do
    test -s "$boot/$file"
done
for n in 1 2; do test -s "$work/persistent/boot-$n/simh.log"; done
python3 "$self/daimos-p1c-live-cache-logfault-verify-v1590.py" \
    --self-test "$boot/kcore.map" "$boot/v1584-linked-addresses.txt" \
    "$boot/v1585-linked-addresses.txt" "$boot/v1588-linked-addresses.txt" \
    "$boot/v1590-linked-addresses.txt" \
    "$work/persistent/boot-1/simh.log" \
    "$work/persistent/boot-2/simh.log" "$boot/drum" \
    "$work/v1590-physical-verification.txt"
echo 'PASS v1590: genuine D6FS cache retained through torn LOGSTORE retry'
