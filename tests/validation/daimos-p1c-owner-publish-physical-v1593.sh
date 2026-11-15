#!/bin/sh
# Exact successful process ID and VM after original storage publication;
# also verify actual D6FS DRM-root six-slot FSINFO through guest syscall.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-p1c-owner-publish-v1593.XXXXXX")
if [ "${V1593_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1593 evidence: $work"
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
python3 "$self/daimos-p1c-owner-publish-v1593.py" "$kernel"

export XIP_V1477_WORK="$work/persistent"
export XIP_V1477_SIZE=128 XIP_V1477_KEEP=1
export XIP_V1576_P1C_LOGSTORE=1 XIP_V1580_P1C_SWAP=1
export XIP_V1583_VOLUME_DRM=1 XIP_V1584_P1C_OVERLAP=1
export XIP_V1585_P1C_TIMED_WAKE=1
export XIP_V1588_P1C_POSTREAD_FREE_FAIL=1
export XIP_V1592_P1C_TWO_OWNER=1
export XIP_V1593_P1C_PUBLISH=1
export XIP_V1478_TEST_CFLAGS='-DXIP_P1C_LOGSTORE_V1576=1 -DXIP_P1C_SWAP_V1580=1 -DXIP_P1D_DRM_FSINFO_V1593=1'
export XIP_V1478_KERNEL_DIR="$kernel"

echo 'v1593: real 128K PDP-6 two-owner publish and physical DRM FSINFO'
sh "$self/daimos-memfs-snapshot-reboot-v1477.sh" \
    > "$work/fullguest-v1593.log" 2>&1 || {
    tail -125 "$work/fullguest-v1593.log" >&2
    exit 1
}
boot="$work/persistent/guest/build/system/boot/pdp6"
for file in kcore.map v1584-linked-addresses.txt \
    v1585-linked-addresses.txt v1588-linked-addresses.txt \
    v1592-linked-addresses.txt v1593-linked-addresses.txt; do
    test -s "$boot/$file"
done
for n in 1 2; do test -s "$work/persistent/boot-$n/simh.log"; done
python3 "$self/daimos-p1c-owner-publish-verify-v1593.py" --self-test \
    "$boot/kcore.map" "$boot/v1584-linked-addresses.txt" \
    "$boot/v1585-linked-addresses.txt" "$boot/v1588-linked-addresses.txt" \
    "$boot/v1592-linked-addresses.txt" "$boot/v1593-linked-addresses.txt" \
    "$work/persistent/boot-1/simh.log" \
    "$work/persistent/boot-2/simh.log" "$boot/drum" \
    "$work/v1593-physical-verification.txt" \
    > "$work/v1593-verifier-output.txt"
cat "$work/v1593-physical-verification.txt"
echo 'PASS v1593: specific RESIDENT slot and six-slot D6FS-root FSINFO'
