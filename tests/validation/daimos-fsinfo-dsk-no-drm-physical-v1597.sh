#!/bin/sh
# Four-member real DSK270 root, genuine missing Type-167/236 controller.
# Verify no phantom per-unit VFS slab growth, original XIP unchanged.
set -eu
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
self=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
work=$(mktemp -d "$TMPDIR/daimos-fsinfo-dsk-nodrm-v1597.XXXXXX")
if [ "${V1597_KEEP_WORK:-0}" != 1 ]; then
    trap 'rm -rf "$work"' EXIT HUP INT TERM
else
    echo "v1597 evidence: $work"
fi
export XIP_V1469_WORK="$work/guest" XIP_V1469_KEEP=1
export XIP_V1470_BOOT_CORE_WORDS=0400000
export XIP_V1470_SIMH_CPU_KWORDS=128
export XIP_V1477_TEST_CFLAGS='-DXIP_P1D_DSK_NO_DRM_V1597=1'
export XIP_V1597_P1D_NO_DRM=1
# Simultaneous physical test simulations must not share DCS/GE ports.
offset_v1597=$(( $$ % 10000 ))
export SIMH_DCS0_PORT=$(( 31000 + offset_v1597 ))
export SIMH_GE0_PORT=$(( 51000 + offset_v1597 ))
sh "$self/daimos-xip-launch-v1469.sh" > "$work/fullguest-v1597.log" 2>&1 || {
    tail -100 "$work/fullguest-v1597.log" >&2
    exit 1
}
python3 "$self/daimos-fsinfo-dsk-root-verify-v1594.py" \
    --no-drum --self-test "$work/guest/run/simh.log" \
    "$work/guest/build/system/boot/pdp6/disk" \
    "$work/v1597-physical-verification.txt"
echo 'PASS v1597: real DSK270 root, missing DRM236, FSINFO capacity 2'
