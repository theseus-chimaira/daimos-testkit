#!/bin/sh
# Real VFS MEMFS singleton unmount and remount after certified XIP cleanup.
# Three namespace/MM/reuse cycles per 128K, 192K and 256K physical guest.
set -eu
export TMPDIR="${TMPDIR:-$HOME/tmp}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
for size in ${XIP_V1474_SIZES:-128 192 256}; do
    case "$size" in
        128) words=0400000 ;;
        192) words=0600000 ;;
        256) words=01000000 ;;
        *) echo "v1474: unsupported RAM profile $size" >&2; exit 2 ;;
    esac
    printf '\n=== v1474: MEMFS remount/XIP lifetime at %sK ===\n' "$size"
    XIP_V1474_TEST_CFLAGS=-DXIP_REMOUNT_V1474=1 \
    XIP_V1474_REMOUNT_MODE=1 \
    XIP_V1470_BOOT_CORE_WORDS="$words" \
    XIP_V1470_SIMH_CPU_KWORDS="$size" \
    XIP_V1469_WORK="${XIP_V1474_WORK_PREFIX:-$TMPDIR/daimos-xip-remount-v1474}-$size" \
    XIP_V1469_KEEP="${XIP_V1474_KEEP:-0}" \
    sh "$self/daimos-xip-launch-v1469.sh"
done
echo 'PASS v1474: actual MEMFS XIP unmount/remount and exact owner recovery'
