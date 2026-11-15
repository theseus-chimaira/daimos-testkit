#!/bin/sh
# Physical four-member Type-236 DRM root without the DSK270 controller.
# Opposite real-controller service matrix of the accepted v1597 DSK root.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-fsinfo-drm-nodsk-v1601.XXXXXX")
if [ "${V1601_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1601 physical evidence: $work"
fi
export XIP_V1469_WORK="$work/guest" XIP_V1469_KEEP=1
export XIP_V1470_BOOT_CORE_WORDS=0400000
export XIP_V1470_SIMH_CPU_KWORDS=128
export XIP_V1583_VOLUME_DRM=1
export XIP_V1601_P1D_NO_DSK=1
export XIP_V1477_TEST_CFLAGS='-DXIP_P1D_DRM_NO_DSK_V1601=1'
# Listener ports must not collide with other real guests.
offset_v1601=$(( $$ % 10000 ))
export SIMH_DCS0_PORT=$(( 29000 + offset_v1601 ))
export SIMH_GE0_PORT=$(( 49000 + offset_v1601 ))
echo 'v1601: full DRM-root physical guest with absent DSK270 service'
sh "$self/daimos-xip-launch-v1469.sh" \
    > "$work/fullguest-v1601.log" 2>&1 || {
    tail -100 "$work/fullguest-v1601.log" >&2
    exit 1
}
boot="$work/guest/build/system/boot/pdp6"
test -s "$boot/v1601-no-dsk-boot.txt"
python3 "$self/daimos-fsinfo-drm-no-dsk-verify-v1601.py" --self-test \
    "$work/guest/run/simh.log" "$boot/boot.ini" "$boot/drum" \
    "$work/v1601-physical-verification.txt" \
    > "$work/v1601-raw-oracle.log"
cat "$work/v1601-physical-verification.txt"
echo 'PASS v1601: genuine DRM-root KINIT excludes unavailable DSK270 slots'
