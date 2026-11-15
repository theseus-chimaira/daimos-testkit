#!/bin/sh
# Full 128K PDP-6: two independent real PI6 DISK wakeups, actual physical
# recoverable torn LOGSTORE WRITE/commit retry, unrelated live clean D6FS
# cache, post-DMA swap release refusal, exact MM/BCACHE owner rollback.
# The v1590/v1592 test-only observers are composed, not reimplemented.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-composite-v1603.XXXXXX")
if [ "${V1603_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1603 physical composite evidence: $work"
fi
mkdir -p "$work/source/system"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
kernel="$work/source/system/kernel"
python3 "$self/daimos-p1c-snapshot-swap-pi-v1584.py" "$kernel"
python3 "$self/daimos-p1c-snapshot-timer-v1585.py" "$kernel"
python3 "$self/daimos-p1c-postread-release-v1588.py" "$kernel"
python3 "$self/daimos-p1c-two-owner-timer-v1592.py" "$kernel"
python3 "$self/daimos-p1c-logstore-torn-v1577.py" \
    "$kernel/storage/logstore_runtime.s" \
    "$kernel/storage/logstore_runtime-v1603.s"
mv "$kernel/storage/logstore_runtime-v1603.s" \
    "$kernel/storage/logstore_runtime.s"
python3 "$self/daimos-p1c-live-cache-logfault-v1590.py" "$kernel"

export XIP_V1477_WORK="$work/persistent"
export XIP_V1477_SIZE=128 XIP_V1477_KEEP=1
export XIP_V1576_P1C_LOGSTORE=1 XIP_V1580_P1C_SWAP=1
export XIP_V1583_VOLUME_DRM=1 XIP_V1584_P1C_OVERLAP=1
export XIP_V1585_P1C_TIMED_WAKE=1
export XIP_V1588_P1C_POSTREAD_FREE_FAIL=1
export XIP_V1592_P1C_TWO_OWNER=1
export XIP_V1590_P1C_LIVE_CACHE_LOGFAULT=1
export XIP_V1478_TEST_CFLAGS='-DXIP_P1C_LOGSTORE_V1576=1 -DXIP_P1C_LOGFAULT_V1577=1 -DXIP_P1C_SWAP_V1580=1 -DXIP_P1C_CACHE_V1590=1'
export XIP_V1478_KERNEL_DIR="$kernel"

# Simultaneous native/physical workloads must not compete for listeners.
offset_v1603=$(( $$ % 7000 ))
export SIMH_DCS0_PORT=$(( 28000 + offset_v1603 ))
export SIMH_GE0_PORT=$(( 48000 + offset_v1603 ))
echo 'v1603: full physical DRM mapped VOLUME, LOGSTORE torn+retry, two PI6 owners'
sh "$self/daimos-memfs-snapshot-reboot-v1477.sh" \
    > "$work/fullguest-v1603.log" 2>&1 || {
    tail -125 "$work/fullguest-v1603.log" >&2
    exit 1
}
boot="$work/persistent/guest/build/system/boot/pdp6"
for f in kcore.map v1584-linked-addresses.txt \
    v1585-linked-addresses.txt v1588-linked-addresses.txt \
    v1592-linked-addresses.txt v1590-linked-addresses.txt; do
    test -s "$boot/$f"
done
for n in 1 2; do test -s "$work/persistent/boot-$n/simh.log"; done
python3 "$self/daimos-p1c-two-owner-cache-logfault-verify-v1603.py" \
    --self-test "$boot/kcore.map" \
    "$boot/v1584-linked-addresses.txt" \
    "$boot/v1585-linked-addresses.txt" \
    "$boot/v1588-linked-addresses.txt" \
    "$boot/v1592-linked-addresses.txt" \
    "$boot/v1590-linked-addresses.txt" \
    "$work/persistent/boot-1/simh.log" \
    "$work/persistent/boot-2/simh.log" \
    "$boot/drum" "$work/v1603-physical-verification.txt" \
    > "$work/v1603-verifier-output.txt"
cat "$work/v1603-physical-verification.txt"
echo 'PASS v1603: same physical guest two timer owners + live D6FS clean cache + torn LOGSTORE retry'
