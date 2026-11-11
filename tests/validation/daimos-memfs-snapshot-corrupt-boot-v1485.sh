#!/bin/sh
# Two physical cold boots: committed snapshot then one-bit metadata damage.
# The corrupt persistent mount must fail cleanly and allow a fresh volatile
# MEMFS mount with the same singleton, without rebooting again.
set -eu
export TMPDIR="${TMPDIR:-$HOME/tmp}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
size="${XIP_V1485_SIZE:-128}"
work="${XIP_V1485_WORK:-$TMPDIR/daimos-memfs-corrupt-v1485-$size}"
XIP_V1477_SIZE="$size" XIP_V1477_WORK="$work" \
XIP_V1477_KEEP="${XIP_V1485_KEEP:-0}" \
XIP_V1485_CORRUPT_MODE=1 \
XIP_V1478_TEST_CFLAGS=-DXIP_SNAPSHOT_CORRUPT_V1485=1 \
    sh "$self/daimos-memfs-snapshot-reboot-v1477.sh"
echo 'PASS v1485: corrupt committed snapshot refused; volatile MEMFS mounts'
