#!/bin/sh
# Fault-injected MEMFS unmount preflight retry in a disposable KCORE copy.
# The real VFS/slot retirement and MEMFS release path remain unmodified.
set -eu
export TMPDIR="${TMPDIR:-$HOME/tmp}"
: "${DAIMOS_REPO:?set DAIMOS_REPO}"
: "${PDP10_PREFIX:?set PDP10_PREFIX}"
self=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work="${XIP_V1475_WORK:-$TMPDIR/daimos-xip-unmount-v1475-128}"
mkdir -p "$work/source/system" "$work/guest"
trap 'if [ "${XIP_V1475_KEEP:-0}" != 1 ]; then rm -rf "$work"; else echo "v1475 evidence: $work"; fi' EXIT HUP INT TERM
if [ ! -d "$work/source/system/kernel" ]; then
    cp -a "$DAIMOS_REPO/system/kernel" "$work/source/system/kernel"
fi
if [ ! -f "$work/source/VERSION" ]; then
    cp "$DAIMOS_REPO/VERSION" "$work/source/VERSION"
fi
if [ ! -d "$work/source/system/stand" ]; then
    cp -a "$DAIMOS_REPO/system/stand" "$work/source/system/stand"
fi
python3 "$self/daimos-xip-unmount-preflight-v1475.py" \
    "$DAIMOS_REPO/system/kernel/fs/memfs_runtime.s" \
    "$work/source/system/kernel/fs/memfs_runtime.s"

export XIP_V1469_WORK="$work/guest"
export XIP_V1469_KEEP=1
export XIP_V1474_REMOUNT_MODE=1
export XIP_V1474_TEST_CFLAGS='-DXIP_REMOUNT_V1474=1 -DXIP_UNMOUNT_FAULT_V1475=1'
export XIP_V1475_KERNEL_DIR="$work/source/system/kernel"
export XIP_V1475_FAULT_MODE=1
export XIP_V1470_BOOT_CORE_WORDS="${XIP_V1475_BOOT_CORE_WORDS:-0400000}"
export XIP_V1470_SIMH_CPU_KWORDS="${XIP_V1475_SIMH_CPU_KWORDS:-128}"
sh "$self/daimos-xip-launch-v1469.sh"

echo 'v1475: MRES preflight hook linked; guest refusal/retry witnessed'
echo 'PASS v1475: failed unmount preserves mount/XIP; retry and remount pass'
