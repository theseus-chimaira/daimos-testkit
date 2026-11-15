#!/bin/sh
# Full 128K PDP-6: first source-authentic MM allocation/pin refusal
# during independent PI6 snapshot overlap MUST roll back without HALT.
# The error is test-only; all original allocation/free/backing/BCACHE
# and scheduler actions execute in a full four-member DRM root guest.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-mm-pin-rollback-v1587.XXXXXX")
if [ "${V1587_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1587 evidence: $work"
fi

mkdir -p "$work/source/system"
cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
python3 "$self/daimos-p1c-snapshot-swap-pi-v1584.py" \
    "$work/source/system/kernel"
python3 "$self/daimos-p1c-snapshot-timer-v1585.py" \
    "$work/source/system/kernel"
python3 "$self/daimos-p1c-pin-rollback-v1587.py" \
    "$work/source/system/kernel"

export XIP_V1477_WORK="$work/persistent"
export XIP_V1477_SIZE=128
export XIP_V1477_KEEP=1
export XIP_V1576_P1C_LOGSTORE=1
export XIP_V1580_P1C_SWAP=1
export XIP_V1583_VOLUME_DRM=1
export XIP_V1584_P1C_OVERLAP=1
export XIP_V1585_P1C_TIMED_WAKE=1
export XIP_V1587_P1C_MM_PIN_FAIL=1
export XIP_V1478_TEST_CFLAGS='-DXIP_P1C_LOGSTORE_V1576=1 -DXIP_P1C_SWAP_V1580=1'
export XIP_V1478_KERNEL_DIR="$work/source/system/kernel"

echo 'v1587: real two-boot PDP-6 physical MM pin rollback during snapshot PI6 overlap'
sh "$self/daimos-memfs-snapshot-reboot-v1477.sh" \
    > "$work/fullguest-v1587.log" 2>&1 || {
    tail -120 "$work/fullguest-v1587.log" >&2
    exit 1
}

boot="$work/persistent/guest/build/system/boot/pdp6"
for fname in kcore.map v1584-linked-addresses.txt \
    v1585-linked-addresses.txt v1587-linked-addresses.txt; do
    test -s "$boot/$fname"
done
for n in 1 2; do
    test -s "$work/persistent/boot-$n/simh.log"
done

python3 "$self/daimos-p1c-pin-rollback-verify-v1587.py" \
    --self-test "$boot/kcore.map" "$boot/v1584-linked-addresses.txt" \
    "$boot/v1585-linked-addresses.txt" "$boot/v1587-linked-addresses.txt" \
    "$work/persistent/boot-1/simh.log" \
    "$work/persistent/boot-2/simh.log" "$boot/drum" \
    "$work/v1587-physical-verification.txt"

echo 'PASS v1587: original MM rollback, exact bitmap and BCACHE, two-boot recovery'
