#!/bin/sh
# Compile actual native DAS scratch paths with a mock UUO filesystem.
set -eu
export TMPDIR=${TMPDIR:-$HOME/tmp}
mkdir -p "$TMPDIR"
: "${DAS_ROOT:?DAS_ROOT must name the DAS source checkout}"
: "${DAIMOS_REPO:?DAIMOS_REPO must name the DAIMOS checkout}"
: "${PDP10_PREFIX:?PDP10_PREFIX must name the source-built tool prefix}"
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
binary=$(mktemp "$TMPDIR/das-native-scratch-v1875.XXXXXXXX")
trap 'rm -f "$binary"' EXIT HUP INT TERM
for phase in 1 2; do
    flags=''
    if [ "$phase" = 2 ]; then
        flags=-DTEST_DAS_PHASE2_V1875=1
    fi
    "${CC:-cc}" -std=c89 -O2 -ffunction-sections -fdata-sections \
        -Wl,--gc-sections $flags -I"$DAS_ROOT" \
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
        "$here/daimos-das-native-scratch-paths-v1875.c" \
        -o "$binary"
    "$binary"
done
