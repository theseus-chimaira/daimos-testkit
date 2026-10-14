#!/bin/sh
# Verify the single regular KINIT/KCORE configuration and permanent registry.
set -eu
: "${DAIMOS_REPO:?}"
PDP10_PREFIX=${PDP10_PREFIX:-/usr/local}
TMPDIR=${TMPDIR:-$HOME/tmp}
export PDP10_PREFIX TMPDIR
out="$TMPDIR/d6codec-unified-boot-v086"
mkdir -p "$out"
make -s -C "$DAIMOS_REPO/system/boot/pdp6" \
    COMPILER=gcc PDP10_PREFIX="$PDP10_PREFIX" BUILD="$out" \
    "$out/kinit.dxr"
test -s "$out/kinit.dxr"
test -s "$out/kcore.dxr"
grep -q '^proc_packed_runtime_v38 ' "$out/kcore.map"
grep -q '^proc_packed_boot_prepare_v38 ' "$out/kinit.map"
if grep -q 'DAIMOS_PACKED_DEV_V086\|PACKED_V086_MODE_STAMP' \
    "$DAIMOS_REPO/system/boot/pdp6/Makefile" \
    "$DAIMOS_REPO/system/kernel/Makefile" \
    "$DAIMOS_REPO/system/kernel/boot/kinit.c"; then
    echo 'obsolete opt-in packed configuration still exists' >&2
    exit 1
fi
printf '%s\n' 'PASS v086 unified KINIT/KCORE link and persistent registry ownership'
