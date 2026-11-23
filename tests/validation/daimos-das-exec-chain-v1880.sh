#!/bin/sh
# Verify both halves of the native DAS EXEC chain with mock monitor calls.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
: "${DAS_ROOT:?DAS_ROOT must name the DAS checkout}"
: "${DAIMOS_REPO:?DAIMOS_REPO must name the DAIMOS checkout}"
: "${PDP10_PREFIX:?PDP10_PREFIX must name the tool prefix}"
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
binary=$(mktemp "$TMPDIR/das-exec-chain-v1880.XXXXXXXX")
trap 'rm -f "$binary"' EXIT HUP INT TERM
for component in driver phase1; do
    "${CC:-cc}" -std=c89 -O2 -ffunction-sections -fdata-sections \
        -Wl,--gc-sections -I"$DAS_ROOT" \
        -I"$DAIMOS_REPO/system/kernel/boot" \
        -I"$DAIMOS_REPO/system/kernel/core" \
        -I"$DAIMOS_REPO/system/kernel/drivers" \
        -I"$DAIMOS_REPO/system/kernel/fs" \
        -I"$DAIMOS_REPO/system/kernel/mm" \
        -I"$DAIMOS_REPO/system/kernel/modules" \
        -I"$DAIMOS_REPO/system/kernel/proc" \
        -I"$DAIMOS_REPO/system/kernel/storage" \
        -I"$DAIMOS_REPO/userland/libc" \
        -I"$PDP10_PREFIX/include" \
        "$here/daimos-das-exec-chain-$component-v1880.c" \
        -o "$binary"
    "$binary"
done
