#!/bin/sh
# Physical PDP-6 persistence after an injected partial snapshot failure.
# The one-shot RAM fault counter resets on each cold boot. Verify an
# explicit refused HALT and a successful retry on both boots.
# Builds an isolated MEMFS MRES source copy, leaving production untouched.
set -eu
export TMPDIR="${TMPDIR:-$HOME/tmp}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
size=${XIP_V1478_SIZE:-128}
work="${XIP_V1478_WORK:-$TMPDIR/daimos-memfs-snapshot-v1478-$size}"
mkdir -p "$work/source/system" "$work/snapshot"
trap 'if [ "${XIP_V1478_KEEP:-0}" != 1 ]; then rm -rf "$work"; else echo "v1478 evidence: $work"; fi' EXIT HUP INT TERM

if [ ! -d "$work/source/system/kernel" ]; then
    cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
fi
if [ ! -f "$work/source/VERSION" ]; then
    cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
fi
if [ ! -d "$work/source/system/stand" ]; then
    cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
fi
python3 "$self/daimos-memfs-snapshot-fault-v1478.py" \
    "$DAIMOS_REPO/system/kernel/fs/memfs_snapshot_pdp6.s" \
    "$work/source/system/kernel/fs/memfs_snapshot_pdp6.s"

XIP_V1477_WORK="$work/snapshot" XIP_V1477_KEEP=1 \
XIP_V1477_SIZE="$size" XIP_V1478_FAULT_MODE=1 \
XIP_V1478_TEST_CFLAGS=-DXIP_SNAPSHOT_FAULT_V1478=1 \
XIP_V1478_KERNEL_DIR="$work/source/system/kernel" \
    sh "$self/daimos-memfs-snapshot-reboot-v1477.sh"

map="$work/snapshot/guest/build/system/boot/pdp6/memfs-mres.map"
grep -Eq '^daimos_test_snapshot_writes_v1478[[:space:]]+[0-7]+' "$map"
log="$work/snapshot/boot-1/simh.log"
grep -Fq XIP-SNAPSHOT-HALT-REFUSED "$log"
grep -Fq XIP-SNAPSHOT-WRITTEN "$log"
grep -Fq XIP-SNAPSHOT-HALT-REFUSED "$work/snapshot/boot-2/simh.log"
grep -Fq XIP-SNAPSHOT-RESTORED "$work/snapshot/boot-2/simh.log"
echo 'PASS v1478: refused snapshot HALT and retry on two boots, restored XIP'
