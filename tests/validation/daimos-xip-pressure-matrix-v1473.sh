#!/bin/sh
# Real full-profile XIP contention: up to 56 simultaneous pinned-image
# children per round, 3 rounds per installed PDP-6 core size.
set -eu
export TMPDIR="${TMPDIR:-$HOME/tmp}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
for size in ${XIP_V1473_SIZES:-128 192 256}; do
    case "$size" in
        128) words=0400000 ;;
        192) words=0600000 ;;
        256) words=01000000 ;;
        *) echo "v1473: unsupported size $size" >&2; exit 2 ;;
    esac
    printf '\n=== v1473: XIP process/MM pressure %sK ===\n' "$size"
    XIP_V1473_TEST_CFLAGS=-DXIP_PRESSURE_V1473=1 \
    XIP_V1473_PRESSURE_MODE=1 \
    XIP_V1470_BOOT_CORE_WORDS="$words" \
    XIP_V1470_SIMH_CPU_KWORDS="$size" \
    XIP_V1469_WORK="${XIP_V1473_WORK_PREFIX:-$TMPDIR/daimos-xip-pressure-v1473}-$size" \
    XIP_V1469_KEEP="${XIP_V1473_KEEP:-0}" \
    sh "$self/daimos-xip-launch-v1469.sh"
done
echo 'PASS v1473: XIP concurrent RUN/WAIT, process-slot and MM accounting'
