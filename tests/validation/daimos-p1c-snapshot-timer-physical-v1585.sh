#!/bin/sh
# Two real PDP-6 cold boots: a previously sleeping disk process's own
# timer expires during synchronous mapped MEMFS snapshot. Only the
# original PI6/run queue/slot-0 service is allowed to restore it.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-snapshot-timer-v1585.XXXXXX")
if [ "${V1585_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1585 evidence: $work"
fi

mkdir -p "$work/source/system"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 "$self/daimos-p1c-snapshot-swap-pi-v1584.py" \
    "$work/source/system/kernel"
python3 "$self/daimos-p1c-snapshot-timer-v1585.py" \
    "$work/source/system/kernel"

export XIP_V1477_WORK="$work/persistent"
export XIP_V1477_SIZE=128
export XIP_V1477_KEEP=1
export XIP_V1576_P1C_LOGSTORE=1
export XIP_V1580_P1C_SWAP=1
export XIP_V1583_VOLUME_DRM=1
export XIP_V1584_P1C_OVERLAP=1
export XIP_V1585_P1C_TIMED_WAKE=1
# All four children keep the original long timed sleep until the
# diagnostic merely retimes one real DISK/SLEEP descriptor. No child
# probes, explicit swap-in, shortcut PI completion or fake scheduling.
export XIP_V1478_TEST_CFLAGS='-DXIP_P1C_LOGSTORE_V1576=1 -DXIP_P1C_SWAP_V1580=1'
export XIP_V1478_KERNEL_DIR="$work/source/system/kernel"

echo 'v1585: full 128K PDP-6 four-member physical timed PI6 wakeup test'
sh "$self/daimos-memfs-snapshot-reboot-v1477.sh" \
    > "$work/fullguest-v1585.log" 2>&1 || {
    tail -120 "$work/fullguest-v1585.log" >&2
    exit 1
}

boot="$work/persistent/guest/build/system/boot/pdp6"
test -s "$boot/v1584-linked-addresses.txt"
test -s "$boot/v1585-linked-addresses.txt"
for n in 1 2; do
    test -s "$work/persistent/boot-$n/simh.log"
done
python3 "$self/daimos-p1c-snapshot-timer-verify-v1585.py" \
    --self-test "$boot/kcore.map" "$boot/v1584-linked-addresses.txt" \
    "$boot/v1585-linked-addresses.txt" \
    "$work/persistent/boot-1/simh.log" \
    "$work/persistent/boot-2/simh.log" "$boot/drum" \
    "$work/v1585-physical-verification.txt"

echo 'PASS v1585: independent timer wakeup and real mapped snapshot recovery'
